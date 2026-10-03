"""Session de lecon, correction des reponses, progression, revision.

Tout ce qui decide (correction, XP, deverrouillage, planification des revisions)
est calcule ici. Le client n'envoie que des faits : "j'ai repondu ceci".
"""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.db import get_session
from app.core.deps import get_current_user
from app.modules.exercises.checker import check_answer
from app.modules.iam.models import User
from app.modules.review.srs import ReviewState, apply_answer
from app.shared.enums import ExerciseType, MasteryState

router = APIRouter(tags=["progression"])


class StartOut(BaseModel):
    session_id: uuid.UUID
    lesson_id: uuid.UUID


class AttemptIn(BaseModel):
    session_id: uuid.UUID | None = None
    #: UUID genere par le client : rejouer la meme tentative ne la compte qu'une fois.
    client_attempt_id: uuid.UUID
    answer: dict = Field(default_factory=dict)
    response_ms: int | None = None
    origin: str = Field(default="ONLINE", pattern="^(ONLINE|OFFLINE_SYNC)$")


class AttemptOut(BaseModel):
    is_correct: bool
    correct_answer: object | None
    explanation_fr: str | None
    detail: str | None
    xp_delta: int
    already_recorded: bool


class CompleteIn(BaseModel):
    session_id: uuid.UUID


@router.post("/lessons/{lesson_id}/start", response_model=StartOut)
async def start_lesson(
    lesson_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> StartOut:
    exists = (
        await db.execute(
            text("SELECT 1 FROM learn.lessons WHERE id = :id AND status = 'PUBLISHED'"),
            {"id": lesson_id},
        )
    ).scalar_one_or_none()
    if exists is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lecon introuvable.")

    session_id = uuid.uuid4()
    await db.execute(
        text(
            """
            INSERT INTO progress.lesson_sessions (id, user_id, lesson_id, started_at)
            VALUES (:id, :uid, :lid, now())
            """
        ),
        {"id": session_id, "uid": user.id, "lid": lesson_id},
    )
    await db.execute(
        text(
            """
            INSERT INTO progress.lesson_progress (id, user_id, lesson_id, status, attempts)
            VALUES (:id, :uid, :lid, 'IN_PROGRESS', 1)
            ON CONFLICT (user_id, lesson_id) DO UPDATE
                SET status = CASE WHEN progress.lesson_progress.status = 'COMPLETED'
                                  THEN 'COMPLETED'::shared.progress_status
                                  ELSE 'IN_PROGRESS'::shared.progress_status END,
                    attempts = progress.lesson_progress.attempts + 1
            """
        ),
        {"id": uuid.uuid4(), "uid": user.id, "lid": lesson_id},
    )
    return StartOut(session_id=session_id, lesson_id=lesson_id)


async def _update_review_items(
    db: AsyncSession, user_id: uuid.UUID, generated_from: list, is_correct: bool
) -> None:
    """Met a jour la file de revision pour chaque element travaille."""
    now = datetime.now(UTC)
    for origin in generated_from or []:
        if origin.get("type") != "VOCAB":
            continue
        target_id = origin["id"]

        row = (
            await db.execute(
                text(
                    """
                    SELECT state::text, times_seen, correct_count, wrong_count,
                           interval_days, mastery_score, lapses, next_review_at
                    FROM progress.review_items
                    WHERE user_id = :uid AND target_type = 'VOCAB' AND target_id = :tid
                    """
                ),
                {"uid": user_id, "tid": target_id},
            )
        ).one_or_none()

        previous = (
            ReviewState(
                state=MasteryState(row[0]),
                times_seen=row[1],
                correct_count=row[2],
                wrong_count=row[3],
                interval_days=row[4],
                mastery_score=row[5],
                lapses=row[6],
                next_review_at=row[7] or now,
            )
            if row
            else None
        )

        updated = apply_answer(previous, is_correct=is_correct, now=now)
        await db.execute(
            text(
                """
                INSERT INTO progress.review_items
                    (id, user_id, target_type, target_id, state, times_seen, correct_count,
                     wrong_count, last_seen_at, next_review_at, interval_days, mastery_score, lapses)
                VALUES (:id, :uid, 'VOCAB', :tid, CAST(:state AS shared.mastery_state),
                        :seen, :ok, :ko, :now, :next, :interval, :mastery, :lapses)
                ON CONFLICT (user_id, target_type, target_id) DO UPDATE SET
                    state = EXCLUDED.state,
                    times_seen = EXCLUDED.times_seen,
                    correct_count = EXCLUDED.correct_count,
                    wrong_count = EXCLUDED.wrong_count,
                    last_seen_at = EXCLUDED.last_seen_at,
                    next_review_at = EXCLUDED.next_review_at,
                    interval_days = EXCLUDED.interval_days,
                    mastery_score = EXCLUDED.mastery_score,
                    lapses = EXCLUDED.lapses
                """
            ),
            {
                "id": uuid.uuid4(),
                "uid": user_id,
                "tid": target_id,
                "state": updated.state.value,
                "seen": updated.times_seen,
                "ok": updated.correct_count,
                "ko": updated.wrong_count,
                "now": now,
                "next": updated.next_review_at,
                "interval": updated.interval_days,
                "mastery": updated.mastery_score,
                "lapses": updated.lapses,
            },
        )


@router.post("/exercises/{exercise_id}/attempt", response_model=AttemptOut)
async def attempt(
    exercise_id: uuid.UUID,
    payload: AttemptIn,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> AttemptOut:
    """Corrige une reponse. Idempotent : rejouer `client_attempt_id` ne recompte rien."""
    existing = (
        await db.execute(
            text(
                """
                SELECT is_correct FROM progress.exercise_attempts
                WHERE client_attempt_id = :cid
                """
            ),
            {"cid": payload.client_attempt_id},
        )
    ).one_or_none()
    if existing is not None:
        return AttemptOut(
            is_correct=existing[0],
            correct_answer=None,
            explanation_fr=None,
            detail="Tentative deja enregistree.",
            xp_delta=0,
            already_recorded=True,
        )

    exercise = (
        await db.execute(
            text(
                """
                SELECT type::text, answer_spec, generated_from, explanation_fr
                FROM learn.exercises
                WHERE id = :id AND status = 'PUBLISHED'
                """
            ),
            {"id": exercise_id},
        )
    ).one_or_none()
    if exercise is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exercice introuvable.")

    result = check_answer(ExerciseType(exercise[0]), payload.answer, exercise[1])

    await db.execute(
        text(
            """
            INSERT INTO progress.exercise_attempts
                (id, user_id, exercise_id, session_id, client_attempt_id, answer,
                 is_correct, response_ms, attempted_at, origin)
            VALUES (:id, :uid, :ex, :sid, :cid, CAST(:answer AS jsonb), :ok, :ms, now(), :origin)
            """
        ),
        {
            "id": uuid.uuid4(),
            "uid": user.id,
            "ex": exercise_id,
            "sid": payload.session_id,
            "cid": payload.client_attempt_id,
            "answer": __import__("json").dumps(payload.answer, ensure_ascii=False),
            "ok": result.is_correct,
            "ms": payload.response_ms,
            "origin": payload.origin,
        },
    )

    xp_delta = settings.xp_per_correct_answer if result.is_correct else 0
    if xp_delta:
        await db.execute(
            text(
                """
                INSERT INTO game.xp_ledger (id, user_id, amount, reason, ref_type, ref_id)
                VALUES (:id, :uid, :amount, 'EXERCISE_CORRECT', 'EXERCISE', :ref)
                """
            ),
            {"id": uuid.uuid4(), "uid": user.id, "amount": xp_delta, "ref": exercise_id},
        )

    await _update_review_items(db, user.id, exercise[2], result.is_correct)

    return AttemptOut(
        is_correct=result.is_correct,
        correct_answer=result.correct_answer,
        explanation_fr=exercise[3],
        detail=result.detail,
        xp_delta=xp_delta,
        already_recorded=False,
    )


async def _update_streak(db: AsyncSession, user: User) -> dict:
    """Met a jour la serie, en date locale de l'utilisateur."""
    today = datetime.now(UTC).date()
    row = (
        await db.execute(
            text(
                "SELECT id, current_days, longest_days, last_activity_date "
                "FROM game.streaks WHERE user_id = :uid"
            ),
            {"uid": user.id},
        )
    ).one_or_none()

    if row is None:
        await db.execute(
            text(
                """
                INSERT INTO game.streaks (id, user_id, current_days, longest_days, last_activity_date)
                VALUES (:id, :uid, 1, 1, :today)
                """
            ),
            {"id": uuid.uuid4(), "uid": user.id, "today": today},
        )
        return {"current_days": 1, "longest_days": 1}

    _, current, longest, last = row
    if last == today:
        pass  # deja compte aujourd'hui
    elif last is not None and last == today - timedelta(days=1):
        current += 1
    else:
        current = 1
    longest = max(longest, current)

    await db.execute(
        text(
            """
            UPDATE game.streaks
            SET current_days = :c, longest_days = :l, last_activity_date = :today
            WHERE user_id = :uid
            """
        ),
        {"c": current, "l": longest, "today": today, "uid": user.id},
    )
    return {"current_days": current, "longest_days": longest}


@router.post("/lessons/{lesson_id}/complete")
async def complete_lesson(
    lesson_id: uuid.UUID,
    payload: CompleteIn,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> dict:
    stats = (
        await db.execute(
            text(
                """
                SELECT count(*) AS total,
                       count(*) FILTER (WHERE is_correct) AS correct
                FROM progress.exercise_attempts
                WHERE session_id = :sid AND user_id = :uid
                """
            ),
            {"sid": payload.session_id, "uid": user.id},
        )
    ).one()

    total, correct = stats[0], stats[1]
    if total == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Aucune reponse enregistree pour cette session.",
        )

    score = round(correct / total, 3)
    reward = (
        await db.execute(text("SELECT xp_reward FROM learn.lessons WHERE id = :id"), {"id": lesson_id})
    ).scalar_one()

    await db.execute(
        text(
            """
            UPDATE progress.lesson_sessions
            SET completed_at = now(), score = :score, xp_awarded = :xp
            WHERE id = :sid AND user_id = :uid
            """
        ),
        {"score": score, "xp": reward, "sid": payload.session_id, "uid": user.id},
    )
    await db.execute(
        text(
            """
            INSERT INTO progress.lesson_progress
                (id, user_id, lesson_id, status, best_score, attempts,
                 first_completed_at, last_completed_at)
            VALUES (:id, :uid, :lid, 'COMPLETED', :score, 1, now(), now())
            ON CONFLICT (user_id, lesson_id) DO UPDATE SET
                status = 'COMPLETED',
                best_score = GREATEST(progress.lesson_progress.best_score, EXCLUDED.best_score),
                first_completed_at = COALESCE(progress.lesson_progress.first_completed_at, now()),
                last_completed_at = now()
            """
        ),
        {"id": uuid.uuid4(), "uid": user.id, "lid": lesson_id, "score": score},
    )
    await db.execute(
        text(
            """
            INSERT INTO game.xp_ledger (id, user_id, amount, reason, ref_type, ref_id)
            VALUES (:id, :uid, :amount, 'LESSON_COMPLETE', 'LESSON', :ref)
            """
        ),
        {"id": uuid.uuid4(), "uid": user.id, "amount": reward, "ref": lesson_id},
    )

    streak = await _update_streak(db, user)
    total_xp = (
        await db.execute(
            text("SELECT COALESCE(sum(amount), 0) FROM game.xp_ledger WHERE user_id = :uid"),
            {"uid": user.id},
        )
    ).scalar_one()
    weak = (
        await db.execute(
            text(
                """
                SELECT count(*) FROM progress.review_items
                WHERE user_id = :uid AND state = 'WEAK'
                """
            ),
            {"uid": user.id},
        )
    ).scalar_one()

    return {
        "score": score,
        "correct": correct,
        "total": total,
        "xp_awarded": reward,
        "total_xp": total_xp,
        "streak": streak,
        "items_to_review": weak,
    }


@router.get("/progress")
async def get_progress(
    db: AsyncSession = Depends(get_session), user: User = Depends(get_current_user)
) -> dict:
    total_xp = (
        await db.execute(
            text("SELECT COALESCE(sum(amount), 0) FROM game.xp_ledger WHERE user_id = :uid"),
            {"uid": user.id},
        )
    ).scalar_one()
    today_xp = (
        await db.execute(
            text(
                """
                SELECT COALESCE(sum(amount), 0) FROM game.xp_ledger
                WHERE user_id = :uid AND created_at::date = CURRENT_DATE
                """
            ),
            {"uid": user.id},
        )
    ).scalar_one()
    lessons_done = (
        await db.execute(
            text(
                "SELECT count(*) FROM progress.lesson_progress "
                "WHERE user_id = :uid AND status = 'COMPLETED'"
            ),
            {"uid": user.id},
        )
    ).scalar_one()
    streak = (
        await db.execute(
            text("SELECT current_days, longest_days FROM game.streaks WHERE user_id = :uid"),
            {"uid": user.id},
        )
    ).one_or_none()
    by_state = await db.execute(
        text(
            """
            SELECT state::text, count(*) FROM progress.review_items
            WHERE user_id = :uid GROUP BY 1
            """
        ),
        {"uid": user.id},
    )
    due = (
        await db.execute(
            text(
                """
                SELECT count(*) FROM progress.review_items
                WHERE user_id = :uid AND next_review_at <= now()
                """
            ),
            {"uid": user.id},
        )
    ).scalar_one()

    return {
        "total_xp": total_xp,
        "today_xp": today_xp,
        "daily_goal_xp": user.daily_goal_xp,
        "goal_reached": today_xp >= user.daily_goal_xp,
        "lessons_completed": lessons_done,
        "streak": {
            "current_days": streak[0] if streak else 0,
            "longest_days": streak[1] if streak else 0,
        },
        "mastery": {row[0]: row[1] for row in by_state},
        "items_due": due,
    }


@router.get("/review")
async def get_review_queue(
    db: AsyncSession = Depends(get_session), user: User = Depends(get_current_user)
) -> dict:
    """File de revision du jour : les elements faibles d'abord (SS14)."""
    rows = await db.execute(
        text(
            """
            SELECT r.target_id, r.state::text AS state, r.mastery_score, r.next_review_at,
                   v.lemma, v.meaning_fr, a.file_key AS audio_url, a.attribution
            FROM progress.review_items r
            JOIN corpus.vocabulary_items v ON v.id = r.target_id
            LEFT JOIN audio.audio_assets a ON a.id = v.primary_audio_id
            WHERE r.user_id = :uid
              AND r.target_type = 'VOCAB'
              AND r.next_review_at <= now()
              AND v.status = 'PUBLISHED'
            ORDER BY (r.state = 'WEAK') DESC, r.next_review_at
            LIMIT :limit
            """
        ),
        {"uid": user.id, "limit": settings.review_queue_size},
    )
    items = [dict(r._mapping) for r in rows]
    return {"count": len(items), "items": items}


@router.get("/review/exercises")
async def get_review_exercises(
    db: AsyncSession = Depends(get_session), user: User = Depends(get_current_user)
) -> dict:
    """Exercices de revision du jour, choisis par le serveur.

    On reutilise des exercices deja PUBLIES dont la bonne reponse est un element
    du a reviser : aucun contenu n'est genere a la volee, et la correction passe
    par le meme endpoint que les lecons (qui met a jour la repetition espacee).
    """
    rows = await db.execute(
        text(
            """
            SELECT DISTINCT ON (r.target_id)
                   e.id, e.type::text AS type, e.payload, r.state::text AS state
            FROM progress.review_items r
            JOIN learn.exercises e
              ON e.answer_spec->>'correct_id' = r.target_id::text
             AND e.status = 'PUBLISHED'
            WHERE r.user_id = :uid
              AND r.target_type = 'VOCAB'
              AND r.next_review_at <= now()
            ORDER BY r.target_id, (e.type = 'LISTEN_AND_CHOOSE') DESC
            """
        ),
        {"uid": user.id},
    )
    exercises = [dict(r._mapping) for r in rows]
    # Les elements faibles d'abord (SS14).
    exercises.sort(key=lambda e: e["state"] != "WEAK")
    exercises = exercises[: settings.review_queue_size]
    return {
        "count": len(exercises),
        "exercises": [
            {"id": e["id"], "type": e["type"], "payload": e["payload"]} for e in exercises
        ],
    }
