"""Traduction : recherche dans le corpus, historique, signalement.

Aucune generation automatique. Le champ `mode` vaut toujours LEXICON tant
qu'aucun modele n'a ete entraine et evalue pour la langue concernee (SS41).
"""

from __future__ import annotations

import json
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.deps import get_current_user
from app.modules.iam.models import User
from app.modules.translation import service
from app.shared.enums import HumanValidation, TranslationMode

router = APIRouter(prefix="/translate", tags=["traduction"])


class TranslateIn(BaseModel):
    language_id: uuid.UUID
    text: str = Field(min_length=1, max_length=200)
    #: True : on saisit la langue nationale et on veut le francais.
    into_french: bool = True


class TranslateOut(BaseModel):
    request_id: uuid.UUID
    mode: TranslationMode
    model: str
    model_version: str
    confidence: float | None
    message: str
    matches: list[dict]
    #: Rappel permanent : l'outil ne traduit pas des phrases libres.
    disclaimer: str


class ReportIn(BaseModel):
    comment: str | None = Field(default=None, max_length=500)


DISCLAIMER = (
    "MBOA ne traduit pas de phrases libres : il recherche dans un corpus vérifié "
    "par des locuteurs. Un mot absent du corpus n'est pas un mot inexistant."
)


@router.post("", response_model=TranslateOut)
async def translate(
    payload: TranslateIn,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> TranslateOut:
    language = (
        await db.execute(
            text("SELECT id, name, iso639_3 FROM ref.languages WHERE id = :id"),
            {"id": payload.language_id},
        )
    ).one_or_none()
    if language is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Langue inconnue.")

    matches = await service.search(
        db,
        language_id=language.id,
        query=payload.text,
        into_french=payload.into_french,
    )
    message = service.explain(
        matches, into_french=payload.into_french, language_name=language.name
    )
    serialized = [m.as_dict() for m in matches]
    confidence = matches[0].confidence if matches else None

    request_id = uuid.uuid4()
    await db.execute(
        text(
            """
            INSERT INTO translate.translation_requests
                (id, user_id, source_language_id, target_language_id,
                 source_code, target_code, input_text, mode, model, model_version,
                 confidence, match_count, matches, human_validation)
            VALUES (:id, :uid, :src_lang, :tgt_lang, :src, :tgt, :input,
                    CAST(:mode AS shared.translation_mode), :model, :version,
                    :confidence, :count, CAST(:matches AS jsonb),
                    CAST('NONE' AS shared.human_validation))
            """
        ),
        {
            "id": request_id,
            "uid": user.id,
            "src_lang": language.id if payload.into_french else None,
            "tgt_lang": None if payload.into_french else language.id,
            "src": language.iso639_3 if payload.into_french else service.PIVOT,
            "tgt": service.PIVOT if payload.into_french else language.iso639_3,
            "input": payload.text,
            "mode": TranslationMode.LEXICON.value,
            "model": service.ENGINE,
            "version": service.ENGINE_VERSION,
            "confidence": confidence,
            "count": len(matches),
            "matches": json.dumps(serialized, ensure_ascii=False),
        },
    )

    return TranslateOut(
        request_id=request_id,
        mode=TranslationMode.LEXICON,
        model=service.ENGINE,
        model_version=service.ENGINE_VERSION,
        confidence=confidence,
        message=message,
        matches=serialized,
        disclaimer=DISCLAIMER,
    )


@router.get("/history")
async def history(
    db: AsyncSession = Depends(get_session), user: User = Depends(get_current_user)
) -> list[dict]:
    rows = await db.execute(
        text(
            """
            SELECT id, input_text, source_code, target_code, confidence,
                   match_count, human_validation::text AS human_validation, created_at
            FROM translate.translation_requests
            WHERE user_id = :uid
            ORDER BY created_at DESC
            LIMIT 30
            """
        ),
        {"uid": user.id},
    )
    return [dict(r._mapping) for r in rows]


@router.post("/{request_id}/report")
async def report(
    request_id: uuid.UUID,
    payload: ReportIn,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> dict:
    """Signale une traduction douteuse : elle rejoint la file des specialistes."""
    updated = await db.execute(
        text(
            """
            UPDATE translate.translation_requests
            SET human_validation = CAST(:s AS shared.human_validation),
                report_comment = :comment
            WHERE id = :id AND user_id = :uid
            """
        ),
        {
            "s": HumanValidation.REQUESTED.value,
            "comment": payload.comment,
            "id": request_id,
            "uid": user.id,
        },
    )
    if updated.rowcount == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Demande introuvable.")
    return {
        "status": HumanValidation.REQUESTED.value,
        "message": "Merci : un spécialiste examinera cette traduction.",
    }
