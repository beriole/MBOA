"""Espace contributeur : saisie des gloses et validation humaine (SS5, SS42).

C'est par ici qu'un locuteur natif transforme une forme attestee mais muette
(un mot enregistre, sans traduction) en contenu pedagogique publiable.

Regles appliquees :
  - modifier un contenu deja valide le renvoie en relecture ;
  - une decision (ACCEPT / REJECT / REQUEST_CHANGES) est toujours tracee ;
  - un exercice genere n'est jamais publie sans revue humaine (SS13).
"""

from __future__ import annotations

import json
import random
import unicodedata
import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.modules.cms.deps import Contributor, ensure_language_allowed, get_contributor
from app.modules.exercises.generator import (
    CorpusWord,
    GenerationError,
    generate_multiple_choice,
)
from app.shared.enums import ContentStatus, GrammaticalCategory, ValidationDecision

router = APIRouter(prefix="/cms", tags=["espace contributeur"])

#: Statuts sur lesquels un contributeur peut encore travailler.
EDITABLE = (
    ContentStatus.DRAFT,
    ContentStatus.SOURCE_FOUND,
    ContentStatus.TO_VERIFY,
    ContentStatus.HUMAN_REVIEW,
    ContentStatus.VALIDATED,
)


def strip_tones(value: str) -> str:
    decomposed = unicodedata.normalize("NFD", value)
    return unicodedata.normalize(
        "NFC", "".join(c for c in decomposed if not unicodedata.combining(c))
    )


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
class QueueItem(BaseModel):
    id: uuid.UUID
    lemma: str
    meaning_fr: str | None
    grammatical_category: str
    status: str
    audio_url: str | None
    audio_attribution: str | None
    source_title: str | None
    source_license: str | None
    source_locator: str | None
    has_gloss: bool


class QueueOut(BaseModel):
    language_id: uuid.UUID
    counts: dict[str, int]
    missing_gloss: int
    items: list[QueueItem]


class VocabularyEdit(BaseModel):
    """Saisie du contributeur. Tous les champs sont optionnels : on corrige au fil de l'eau."""

    meaning_fr: str | None = Field(default=None, max_length=300)
    meaning_en: str | None = Field(default=None, max_length=300)
    grammatical_category: GrammaticalCategory | None = None
    ipa: str | None = Field(default=None, max_length=120)
    tone_pattern: str | None = Field(default=None, max_length=32)
    #: Correction orthographique de la forme elle-meme, si le contributeur l'estime fautive.
    lemma: str | None = Field(default=None, max_length=200)
    note: str | None = Field(default=None, max_length=500)


class DecisionIn(BaseModel):
    decision: ValidationDecision
    comment: str | None = Field(default=None, max_length=500)


class ItemOut(BaseModel):
    id: uuid.UUID
    lemma: str
    meaning_fr: str | None
    status: str
    message: str


# ---------------------------------------------------------------------------
# File de travail
# ---------------------------------------------------------------------------
@router.get("/languages")
async def my_languages(
    contributor: Contributor = Depends(get_contributor),
    db: AsyncSession = Depends(get_session),
) -> list[dict]:
    """Les langues sur lesquelles le contributeur est habilite."""
    clause = "" if contributor.is_admin else "WHERE l.id = ANY(:ids)"
    rows = await db.execute(
        text(
            f"""
            SELECT l.id, l.name, l.iso639_3,
                   count(v.id) FILTER (WHERE v.meaning_fr IS NULL) AS sans_glose,
                   count(v.id) AS total
            FROM ref.languages l
            LEFT JOIN corpus.vocabulary_items v ON v.language_id = l.id
            {clause}
            GROUP BY l.id, l.name, l.iso639_3
            ORDER BY l.name
            """
        ),
        {} if contributor.is_admin else {"ids": list(contributor.language_ids)},
    )
    return [dict(r._mapping) for r in rows]


@router.get("/queue", response_model=QueueOut)
async def queue(
    language_id: uuid.UUID,
    only_missing_gloss: bool = Query(default=False),
    limit: int = Query(default=50, le=200),
    contributor: Contributor = Depends(get_contributor),
    db: AsyncSession = Depends(get_session),
) -> QueueOut:
    """Les entrees sur lesquelles il reste du travail."""
    ensure_language_allowed(contributor, language_id)

    counts = {
        row[0]: row[1]
        for row in await db.execute(
            text(
                """
                SELECT status::text, count(*) FROM corpus.vocabulary_items
                WHERE language_id = :lang GROUP BY 1
                """
            ),
            {"lang": language_id},
        )
    }
    missing = (
        await db.execute(
            text(
                """
                SELECT count(*) FROM corpus.vocabulary_items
                WHERE language_id = :lang AND meaning_fr IS NULL
                """
            ),
            {"lang": language_id},
        )
    ).scalar_one()

    rows = await db.execute(
        text(
            f"""
            SELECT v.id, v.lemma, v.meaning_fr, v.grammatical_category::text AS grammatical_category,
                   v.status::text AS status,
                   CASE WHEN a.id IS NULL THEN NULL ELSE '/api/v1/audio/' || a.id END AS audio_url,
                   a.attribution AS audio_attribution,
                   s.title AS source_title, s.license::text AS source_license,
                   r.locator AS source_locator
            FROM corpus.vocabulary_items v
            LEFT JOIN audio.audio_assets a ON a.id = v.primary_audio_id
            LEFT JOIN prov.sources s ON s.id = v.source_id
            LEFT JOIN LATERAL (
                SELECT locator FROM prov.source_references
                WHERE target_type = 'vocabulary_items' AND target_id = v.id LIMIT 1
            ) r ON true
            WHERE v.language_id = :lang
              AND v.status <> 'REJECTED'
              {"AND v.meaning_fr IS NULL" if only_missing_gloss else ""}
            ORDER BY (v.meaning_fr IS NULL) DESC, v.lemma
            LIMIT :limit
            """
        ),
        {"lang": language_id, "limit": limit},
    )

    items = [
        QueueItem(**dict(r._mapping), has_gloss=r.meaning_fr is not None) for r in rows
    ]
    return QueueOut(
        language_id=language_id, counts=counts, missing_gloss=missing, items=items
    )


# ---------------------------------------------------------------------------
# Saisie
# ---------------------------------------------------------------------------
async def _load_item(db: AsyncSession, item_id: uuid.UUID) -> Any:
    row = (
        await db.execute(
            text(
                """
                SELECT id, language_id, lemma, meaning_fr, status::text AS status,
                       created_by, source_id
                FROM corpus.vocabulary_items WHERE id = :id
                """
            ),
            {"id": item_id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Entree introuvable.")
    return row


@router.patch("/vocabulary/{item_id}", response_model=ItemOut)
async def edit_vocabulary(
    item_id: uuid.UUID,
    payload: VocabularyEdit,
    contributor: Contributor = Depends(get_contributor),
    db: AsyncSession = Depends(get_session),
) -> ItemOut:
    """Enregistre la saisie d'un contributeur.

    Modifier un contenu deja VALIDATED ou PUBLISHED le renvoie en relecture :
    une correction ne peut pas contourner la validation humaine.
    """
    item = await _load_item(db, item_id)
    ensure_language_allowed(contributor, item.language_id)

    fields = payload.model_dump(exclude_unset=True, exclude_none=True)
    note = fields.pop("note", None)
    if not fields and note is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Aucune modification fournie."
        )

    assignments = []
    params: dict[str, Any] = {"id": item_id}

    if "lemma" in fields:
        lemma = unicodedata.normalize("NFC", fields.pop("lemma").strip())
        assignments += ["lemma = :lemma", "lemma_toneless = :toneless"]
        params |= {"lemma": lemma, "toneless": strip_tones(lemma)}

    if "grammatical_category" in fields:
        assignments.append(
            "grammatical_category = CAST(:category AS shared.grammatical_category)"
        )
        params["category"] = fields.pop("grammatical_category").value

    for column in ("meaning_fr", "meaning_en", "ipa", "tone_pattern"):
        if column in fields:
            assignments.append(f"{column} = :{column}")
            params[column] = fields.pop(column).strip() or None

    # Une modification de fond exige une nouvelle relecture.
    new_status = item.status
    if assignments and item.status in ("VALIDATED", "PUBLISHED"):
        new_status = ContentStatus.HUMAN_REVIEW.value
    elif assignments and item.status in ("DRAFT", "SOURCE_FOUND", "TO_VERIFY"):
        new_status = ContentStatus.HUMAN_REVIEW.value

    if assignments:
        assignments.append("status = CAST(:status AS shared.content_status)")
        params["status"] = new_status
        # La paternite revient a celui qui ecrit le contenu : sans cela, un
        # contributeur pourrait saisir une glose sur une entree importee en lot,
        # puis la valider lui-meme.
        assignments.append("created_by = :author")
        params["author"] = contributor.id
        await db.execute(
            text(
                f"UPDATE corpus.vocabulary_items SET {', '.join(assignments)} WHERE id = :id"
            ),
            params,
        )

    if note:
        await db.execute(
            text(
                """
                INSERT INTO prov.content_validations
                    (id, target_type, target_id, validator_contributor_id, decision, comment, decided_at)
                VALUES (:id, 'vocabulary_items', :target, :cid, 'REQUEST_CHANGES', :comment, now())
                """
            ),
            {"id": uuid.uuid4(), "target": item_id, "cid": contributor.id, "comment": note},
        )

    updated = await _load_item(db, item_id)
    return ItemOut(
        id=updated.id,
        lemma=updated.lemma,
        meaning_fr=updated.meaning_fr,
        status=updated.status,
        message=(
            "Saisie enregistree. En attente de relecture par un autre contributeur."
            if new_status == ContentStatus.HUMAN_REVIEW.value
            else "Saisie enregistree."
        ),
    )


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
@router.post("/vocabulary/{item_id}/decision", response_model=ItemOut)
async def decide(
    item_id: uuid.UUID,
    payload: DecisionIn,
    contributor: Contributor = Depends(get_contributor),
    db: AsyncSession = Depends(get_session),
) -> ItemOut:
    """Accepter, rejeter ou demander une modification.

    La regle « le redacteur ne valide pas son propre travail » est verifiee par
    la base : on la signale ici avec un message comprehensible.
    """
    item = await _load_item(db, item_id)
    ensure_language_allowed(contributor, item.language_id)

    if item.status == ContentStatus.PUBLISHED.value:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce contenu est deja publie. Modifiez-le pour le renvoyer en relecture.",
        )

    await db.execute(
        text(
            """
            INSERT INTO prov.content_validations
                (id, target_type, target_id, validator_contributor_id, decision, comment, decided_at)
            VALUES (:id, 'vocabulary_items', :target, :cid,
                    CAST(:decision AS shared.validation_decision), :comment, now())
            """
        ),
        {
            "id": uuid.uuid4(),
            "target": item_id,
            "cid": contributor.id,
            "decision": payload.decision.value,
            "comment": payload.comment,
        },
    )

    if payload.decision is ValidationDecision.ACCEPT:
        if item.created_by == contributor.id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "Vous avez saisi cette entree : un autre contributeur doit la valider."
                ),
            )
        if item.meaning_fr is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Renseignez d'abord la traduction francaise.",
            )
        await db.execute(
            text(
                """
                UPDATE corpus.vocabulary_items
                SET status = 'VALIDATED', validated_by = :cid
                WHERE id = :id
                """
            ),
            {"cid": contributor.id, "id": item_id},
        )
        message = "Entree validee. Elle peut maintenant etre publiee."
    elif payload.decision is ValidationDecision.REJECT:
        await db.execute(
            text(
                "UPDATE corpus.vocabulary_items SET status = 'REJECTED' WHERE id = :id"
            ),
            {"id": item_id},
        )
        message = "Entree rejetee. Elle ne sera jamais publiee."
    else:
        await db.execute(
            text(
                """
                UPDATE corpus.vocabulary_items
                SET status = 'TO_VERIFY' WHERE id = :id
                """
            ),
            {"id": item_id},
        )
        message = "Modification demandee. L'entree retourne dans la file."

    updated = await _load_item(db, item_id)
    return ItemOut(
        id=updated.id,
        lemma=updated.lemma,
        meaning_fr=updated.meaning_fr,
        status=updated.status,
        message=message,
    )


@router.post("/vocabulary/{item_id}/publish", response_model=ItemOut)
async def publish(
    item_id: uuid.UUID,
    contributor: Contributor = Depends(get_contributor),
    db: AsyncSession = Depends(get_session),
) -> ItemOut:
    item = await _load_item(db, item_id)
    ensure_language_allowed(contributor, item.language_id)

    if item.status != ContentStatus.VALIDATED.value:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Seule une entree VALIDATED peut etre publiee (statut actuel : {item.status}).",
        )

    await db.execute(
        text("UPDATE corpus.vocabulary_items SET status = 'PUBLISHED' WHERE id = :id"),
        {"id": item_id},
    )
    updated = await _load_item(db, item_id)
    return ItemOut(
        id=updated.id,
        lemma=updated.lemma,
        meaning_fr=updated.meaning_fr,
        status=updated.status,
        message="Entree publiee : elle apparait desormais dans l'application.",
    )


# ---------------------------------------------------------------------------
# Exercices : generation puis revue
# ---------------------------------------------------------------------------
@router.post("/units/{unit_id}/generate-exercises")
async def generate_exercises(
    unit_id: uuid.UUID,
    contributor: Contributor = Depends(get_contributor),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Cree les exercices que le corpus permet desormais.

    Concretement : des que des gloses sont publiees, les exercices de sens
    deviennent possibles. Ils sont crees en DRAFT et attendent une revue.
    """
    unit = (
        await db.execute(
            text(
                """
                SELECT u.id, u.target_vocab_ids, c.language_id, u.section_id
                FROM learn.units u
                JOIN learn.sections s ON s.id = u.section_id
                JOIN learn.courses c ON c.id = s.course_id
                WHERE u.id = :id
                """
            ),
            {"id": unit_id},
        )
    ).one_or_none()
    if unit is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unite introuvable.")
    ensure_language_allowed(contributor, unit.language_id)

    rows = await db.execute(
        text(
            """
            SELECT v.id, v.lemma, v.meaning_fr,
                   CASE WHEN a.id IS NULL THEN NULL ELSE '/api/v1/audio/' || a.id END AS audio_url,
                   a.attribution
            FROM corpus.vocabulary_items v
            LEFT JOIN audio.audio_assets a ON a.id = v.primary_audio_id
            WHERE v.id = ANY(:ids) AND v.status = 'PUBLISHED'
            """
        ),
        {"ids": list(unit.target_vocab_ids)},
    )
    words = [
        CorpusWord(
            id=str(r.id),
            lemma=r.lemma,
            meaning_fr=r.meaning_fr,
            audio_url=r.audio_url,
            audio_attribution=r.attribution,
        )
        for r in rows
    ]
    glossed = [w for w in words if w.has_gloss]

    if len(glossed) < 4:
        return {
            "created": 0,
            "glossed_words": len(glossed),
            "message": (
                f"{len(glossed)} mot(s) traduit(s) sur les 4 necessaires : il faut au moins "
                "quatre traductions validees pour composer un exercice de sens avec des "
                "distracteurs reels."
            ),
        }

    existing = {
        row[0]
        for row in await db.execute(
            text(
                """
                SELECT answer_spec->>'correct_id' FROM learn.exercises
                WHERE type = 'MULTIPLE_CHOICE' AND status <> 'REJECTED'
                """
            )
        )
    }

    rng = random.Random(20260923)
    created = 0
    for word in glossed:
        if word.id in existing:
            continue
        try:
            generated = generate_multiple_choice(word, glossed, rng=rng)
        except GenerationError:
            continue

        await db.execute(
            text(
                """
                INSERT INTO learn.exercises
                    (id, language_id, type, payload, answer_spec, generated_from,
                     generator_version, status, source_id, created_by)
                VALUES (:id, :lang, CAST(:type AS shared.exercise_type),
                        CAST(:payload AS jsonb), CAST(:spec AS jsonb), CAST(:from AS jsonb),
                        :gv, 'DRAFT', :src, :by)
                """
            ),
            {
                "id": uuid.uuid4(),
                "lang": unit.language_id,
                "type": generated.type.value,
                "payload": json.dumps(generated.payload, ensure_ascii=False),
                "spec": json.dumps(generated.answer_spec, ensure_ascii=False),
                "from": json.dumps(generated.generated_from),
                "gv": generated.generator_version,
                "src": (await _load_item(db, uuid.UUID(word.id))).source_id,
                "by": contributor.id,
            },
        )
        created += 1

    return {
        "created": created,
        "glossed_words": len(glossed),
        "message": (
            f"{created} exercice(s) de sens cree(s), en attente de revue."
            if created
            else "Aucun nouvel exercice : ceux du corpus actuel existent deja."
        ),
    }


@router.get("/exercises/pending")
async def pending_exercises(
    language_id: uuid.UUID,
    contributor: Contributor = Depends(get_contributor),
    db: AsyncSession = Depends(get_session),
) -> list[dict]:
    ensure_language_allowed(contributor, language_id)
    rows = await db.execute(
        text(
            """
            SELECT id, type::text AS type, payload, status::text AS status
            FROM learn.exercises
            WHERE language_id = :lang AND status IN ('DRAFT', 'HUMAN_REVIEW', 'VALIDATED')
            ORDER BY created_at
            """
        ),
        {"lang": language_id},
    )
    return [dict(r._mapping) for r in rows]


@router.post("/exercises/{exercise_id}/decision")
async def decide_exercise(
    exercise_id: uuid.UUID,
    payload: DecisionIn,
    contributor: Contributor = Depends(get_contributor),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Revue d'un exercice genere, puis publication (SS13)."""
    row = (
        await db.execute(
            text(
                """
                SELECT id, language_id, status::text AS status, created_by
                FROM learn.exercises WHERE id = :id
                """
            ),
            {"id": exercise_id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exercice introuvable.")
    ensure_language_allowed(contributor, row.language_id)

    if payload.decision is not ValidationDecision.ACCEPT:
        await db.execute(
            text("UPDATE learn.exercises SET status = 'REJECTED' WHERE id = :id"),
            {"id": exercise_id},
        )
        return {"status": "REJECTED", "message": "Exercice ecarte."}

    if row.created_by == contributor.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Vous avez genere cet exercice : un autre contributeur doit le valider.",
        )

    await db.execute(
        text(
            """
            INSERT INTO prov.content_validations
                (id, target_type, target_id, validator_contributor_id, decision, comment, decided_at)
            VALUES (:id, 'exercises', :target, :cid, 'ACCEPT', :comment, now())
            """
        ),
        {
            "id": uuid.uuid4(),
            "target": exercise_id,
            "cid": contributor.id,
            "comment": payload.comment,
        },
    )
    for step in ("HUMAN_REVIEW",):
        await db.execute(
            text(
                "UPDATE learn.exercises SET status = CAST(:s AS shared.content_status) WHERE id = :id"
            ),
            {"s": step, "id": exercise_id},
        )
    await db.execute(
        text(
            "UPDATE learn.exercises SET status = 'VALIDATED', validated_by = :cid WHERE id = :id"
        ),
        {"cid": contributor.id, "id": exercise_id},
    )
    await db.execute(
        text("UPDATE learn.exercises SET status = 'PUBLISHED' WHERE id = :id"),
        {"id": exercise_id},
    )
    return {"status": "PUBLISHED", "message": "Exercice publie."}


@router.post("/lessons/{lesson_id}/attach-exercises")
async def attach_exercises(
    lesson_id: uuid.UUID,
    contributor: Contributor = Depends(get_contributor),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Ajoute a la lecon les exercices publies qui n'y figurent pas encore.

    Le bloc RECAP reste en dernier : les nouveaux exercices s'inserent avant lui.
    """
    lesson = (
        await db.execute(
            text(
                """
                SELECT le.id, c.language_id
                FROM learn.lessons le
                JOIN learn.units u ON u.id = le.unit_id
                JOIN learn.sections s ON s.id = u.section_id
                JOIN learn.courses c ON c.id = s.course_id
                WHERE le.id = :id
                """
            ),
            {"id": lesson_id},
        )
    ).one_or_none()
    if lesson is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lecon introuvable.")
    ensure_language_allowed(contributor, lesson.language_id)

    orphans = (
        await db.execute(
            text(
                """
                SELECT e.id FROM learn.exercises e
                WHERE e.language_id = :lang AND e.status = 'PUBLISHED'
                  AND NOT EXISTS (
                      SELECT 1 FROM learn.lesson_blocks b WHERE b.exercise_id = e.id
                  )
                ORDER BY e.created_at
                """
            ),
            {"lang": lesson.language_id},
        )
    ).scalars().all()

    if not orphans:
        return {"attached": 0, "message": "Tous les exercices publies sont deja dans une lecon."}

    recap = (
        await db.execute(
            text(
                """
                SELECT id, position FROM learn.lesson_blocks
                WHERE lesson_id = :id AND kind = 'RECAP'
                ORDER BY position DESC LIMIT 1
                """
            ),
            {"id": lesson_id},
        )
    ).one_or_none()
    position = (
        recap.position
        if recap
        else (
            await db.execute(
                text(
                    "SELECT COALESCE(max(position), -1) + 1 FROM learn.lesson_blocks "
                    "WHERE lesson_id = :id"
                ),
                {"id": lesson_id},
            )
        ).scalar_one()
    )

    for exercise_id in orphans:
        await db.execute(
            text(
                """
                INSERT INTO learn.lesson_blocks (id, lesson_id, position, kind, exercise_id)
                VALUES (:id, :lesson, :pos, 'PRACTICE', :ex)
                """
            ),
            {"id": uuid.uuid4(), "lesson": lesson_id, "pos": position, "ex": exercise_id},
        )
        position += 1

    if recap:
        await db.execute(
            text("UPDATE learn.lesson_blocks SET position = :pos WHERE id = :id"),
            {"pos": position, "id": recap.id},
        )

    return {"attached": len(orphans), "message": f"{len(orphans)} exercice(s) ajoute(s) a la lecon."}
