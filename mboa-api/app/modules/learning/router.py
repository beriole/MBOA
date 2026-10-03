"""Contenu pedagogique servi a l'application.

Regle : seules les lignes au statut PUBLISHED sortent de l'API. Un contenu en
cours de validation n'est jamais visible par un apprenant.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.deps import get_current_user
from app.modules.iam.models import User

router = APIRouter(tags=["apprentissage"])


class LanguageOut(BaseModel):
    id: uuid.UUID
    iso639_3: str
    name: str
    autonym: str | None
    tone_count: int | None
    courses_count: int
    published_words: int


@router.get("/languages", response_model=list[LanguageOut])
async def list_languages(db: AsyncSession = Depends(get_session)) -> list[dict]:
    rows = await db.execute(
        text(
            """
            SELECT l.id, l.iso639_3, l.name, l.autonym, l.tone_count,
                   (SELECT count(*) FROM learn.courses c
                     WHERE c.language_id = l.id AND c.status = 'PUBLISHED') AS courses_count,
                   (SELECT count(*) FROM corpus.vocabulary_items v
                     WHERE v.language_id = l.id AND v.status = 'PUBLISHED') AS published_words
            FROM ref.languages l
            WHERE l.is_active
            ORDER BY l.name
            """
        )
    )
    return [dict(r._mapping) for r in rows]


@router.get("/languages/{language_id}/path")
async def get_path(
    language_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> dict:
    """Le parcours complet : sections, unites, lecons, avec l'etat de l'apprenant.

    L'etat de deverrouillage est calcule par le serveur (SS39) : le client se
    contente de l'afficher.
    """
    rows = await db.execute(
        text(
            """
            SELECT c.id AS course_id, c.title_fr AS course_title, c.level::text AS level,
                   s.id AS section_id, s.position AS section_position, s.title_fr AS section_title,
                   s.objective_fr AS section_objective,
                   u.id AS unit_id, u.position AS unit_position, u.title_fr AS unit_title,
                   u.objective_fr AS unit_objective,
                   le.id AS lesson_id, le.position AS lesson_position, le.title_fr AS lesson_title,
                   le.kind::text AS lesson_kind, le.estimated_minutes, le.xp_reward,
                   lp.status::text AS progress_status, lp.best_score
            FROM learn.courses c
            JOIN learn.sections s ON s.course_id = c.id AND s.status = 'PUBLISHED'
            JOIN learn.units u ON u.section_id = s.id AND u.status = 'PUBLISHED'
            JOIN learn.lessons le ON le.unit_id = u.id AND le.status = 'PUBLISHED'
            LEFT JOIN progress.lesson_progress lp
                   ON lp.lesson_id = le.id AND lp.user_id = :uid
            WHERE c.language_id = :lang AND c.status = 'PUBLISHED'
            ORDER BY c.position, s.position, u.position, le.position
            """
        ),
        {"lang": language_id, "uid": user.id},
    )
    records = [dict(r._mapping) for r in rows]
    if not records:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Aucun parcours publie pour cette langue.",
        )

    sections: dict[uuid.UUID, dict] = {}
    previous_completed = True  # la premiere lecon est toujours accessible

    for record in records:
        section = sections.setdefault(
            record["section_id"],
            {
                "id": record["section_id"],
                "position": record["section_position"],
                "title_fr": record["section_title"],
                "objective_fr": record["section_objective"],
                "units": {},
            },
        )
        unit = section["units"].setdefault(
            record["unit_id"],
            {
                "id": record["unit_id"],
                "position": record["unit_position"],
                "title_fr": record["unit_title"],
                "objective_fr": record["unit_objective"],
                "lessons": [],
            },
        )

        stored = record["progress_status"]
        if stored == "COMPLETED":
            state = "COMPLETED"
        elif previous_completed:
            state = stored if stored in ("IN_PROGRESS",) else "AVAILABLE"
        else:
            state = "LOCKED"

        unit["lessons"].append(
            {
                "id": record["lesson_id"],
                "position": record["lesson_position"],
                "title_fr": record["lesson_title"],
                "kind": record["lesson_kind"],
                "estimated_minutes": record["estimated_minutes"],
                "xp_reward": record["xp_reward"],
                "status": state,
                "best_score": record["best_score"],
            }
        )
        previous_completed = state == "COMPLETED"

    return {
        "course": {
            "id": records[0]["course_id"],
            "title_fr": records[0]["course_title"],
            "level": records[0]["level"],
        },
        "sections": [
            {**section, "units": list(section["units"].values())}
            for section in sections.values()
        ],
    }


@router.get("/lessons/{lesson_id}")
async def get_lesson(
    lesson_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> dict:
    """Le contenu d'une lecon.

    `answer_spec` n'est JAMAIS envoye au client : la correction reste au serveur.
    """
    lesson = (
        await db.execute(
            text(
                """
                SELECT le.id, le.title_fr, le.kind::text AS kind, le.estimated_minutes,
                       le.xp_reward, u.id AS unit_id,
                       u.title_fr AS unit_title, u.objective_fr AS unit_objective
                FROM learn.lessons le
                JOIN learn.units u ON u.id = le.unit_id
                WHERE le.id = :id AND le.status = 'PUBLISHED'
                """
            ),
            {"id": lesson_id},
        )
    ).one_or_none()

    if lesson is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lecon introuvable.")

    blocks = await db.execute(
        text(
            """
            SELECT b.id, b.position, b.kind::text AS kind, b.payload,
                   e.id AS exercise_id, e.type::text AS exercise_type,
                   e.payload AS exercise_payload, e.explanation_fr
            FROM learn.lesson_blocks b
            LEFT JOIN learn.exercises e ON e.id = b.exercise_id AND e.status = 'PUBLISHED'
            WHERE b.lesson_id = :id
            ORDER BY b.position
            """
        ),
        {"id": lesson_id},
    )

    # Carte « Le savais-tu ? » de l'unite (SS21) : la culture apparait la ou on
    # apprend, pas dans un menu separe. Nulle si l'unite n'en a pas.
    card = (
        await db.execute(
            text(
                """
                SELECT c.id, c.title_fr, c.summary_fr, cat.name_fr AS category_name,
                       s.title AS source_title
                FROM culture.cultural_links link
                JOIN culture.cultural_contents c ON c.id = link.cultural_content_id
                JOIN culture.cultural_categories cat ON cat.id = c.category_id
                LEFT JOIN prov.sources s ON s.id = c.source_id
                WHERE link.target_type = 'UNIT' AND link.target_id = :unit
                  AND link.placement = 'DID_YOU_KNOW' AND c.status = 'PUBLISHED'
                ORDER BY link.created_at LIMIT 1
                """
            ),
            {"unit": lesson.unit_id},
        )
    ).one_or_none()

    return {
        "id": lesson.id,
        "title_fr": lesson.title_fr,
        "culture_card": dict(card._mapping) if card else None,
        "kind": lesson.kind,
        "estimated_minutes": lesson.estimated_minutes,
        "xp_reward": lesson.xp_reward,
        "unit": {"title_fr": lesson.unit_title, "objective_fr": lesson.unit_objective},
        "blocks": [
            {
                "id": b.id,
                "position": b.position,
                "kind": b.kind,
                "payload": b.payload,
                "exercise": (
                    {
                        "id": b.exercise_id,
                        "type": b.exercise_type,
                        "payload": b.exercise_payload,
                    }
                    if b.exercise_id
                    else None
                ),
            }
            for b in blocks
        ],
    }


@router.get("/vocabulary/{item_id}/provenance")
async def get_provenance(item_id: uuid.UUID, db: AsyncSession = Depends(get_session)) -> dict:
    """Provenance complete d'une entree : source, references, validation, historique.

    Cet endpoint rend la tracabilite verifiable depuis l'application elle-meme.
    """
    item = (
        await db.execute(
            text(
                """
                SELECT v.id, v.lemma, v.meaning_fr, v.status::text AS status,
                       s.title AS source_title, s.license::text AS license, s.url AS source_url,
                       c.display_name AS validated_by
                FROM corpus.vocabulary_items v
                LEFT JOIN prov.sources s ON s.id = v.source_id
                LEFT JOIN prov.contributors c ON c.id = v.validated_by
                WHERE v.id = :id
                """
            ),
            {"id": item_id},
        )
    ).one_or_none()

    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Entree introuvable.")

    references = await db.execute(
        text(
            """
            SELECT locator, consulted_at FROM prov.source_references
            WHERE target_type = 'vocabulary_items' AND target_id = :id
            """
        ),
        {"id": item_id},
    )
    history = await db.execute(
        text(
            """
            SELECT from_status, to_status, occurred_at FROM prov.status_transitions
            WHERE target_type = 'vocabulary_items' AND target_id = :id
            ORDER BY occurred_at
            """
        ),
        {"id": item_id},
    )

    return {
        "id": item.id,
        "lemma": item.lemma,
        "meaning_fr": item.meaning_fr,
        "status": item.status,
        "source": {
            "title": item.source_title,
            "license": item.license,
            "url": item.source_url,
        },
        "validated_by": item.validated_by,
        "references": [dict(r._mapping) for r in references],
        "history": [dict(r._mapping) for r in history],
    }
