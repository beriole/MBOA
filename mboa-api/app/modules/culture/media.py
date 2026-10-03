"""Mediatheque par region et favoris (lot 9, ecrans 4, 7 et 8).

**D'ou vient le lien entre une region et des enregistrements ?**

Pas d'une table que quelqu'un aurait remplie de memoire. Il vient d'une **fiche
culturelle publiee** qui rattache une langue a une region : c'est elle qui
etablit le lien, et elle est sourcee. Les enregistrements proposes pour une
region sont donc ceux des langues qu'une fiche y documente, et la reponse dit
quelle fiche etablit ce rattachement.

**Ce qui n'existe pas n'est pas simule.** Aucune video n'est aujourd'hui dans le
catalogue, et MBOA n'en diffusera que sous licence etablie. Les compteurs le
disent au lieu d'afficher une vignette de remplissage.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.deps import get_current_user
from app.modules.iam.models import User

router = APIRouter(prefix="/culture", tags=["culture"])
favorites_router = APIRouter(prefix="/me/favorites", tags=["culture"])

#: Ce qu'on peut mettre de cote.
FAVORITE_TYPES = ("CULTURAL_CONTENT", "AUDIO")


# ---------------------------------------------------------------------------
# Mediatheque d'une region
# ---------------------------------------------------------------------------
@router.get("/regions/{region_id}/media")
async def region_media(
    region_id: uuid.UUID, db: AsyncSession = Depends(get_session)
) -> dict:
    """Les enregistrements et medias rattaches a une region.

    Les enregistrements ne sont pas « de la region » : ce sont ceux des langues
    qu'une fiche publiee y documente. La nuance est portee dans la reponse, pour
    qu'aucun ecran ne puisse la perdre en route.
    """
    region = (
        await db.execute(
            text("SELECT id, code, name FROM ref.regions WHERE id = :id"),
            {"id": region_id},
        )
    ).one_or_none()
    if region is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Région introuvable.")

    # Les langues documentees dans cette region, et la fiche qui l'etablit.
    langues = [
        dict(r._mapping)
        for r in await db.execute(
            text(
                """
                SELECT DISTINCT ON (l.id)
                       l.id, l.name, l.iso639_3,
                       c.id AS fiche_id, c.title_fr AS fiche_titre
                FROM culture.cultural_contents c
                JOIN ref.languages l ON l.id = c.language_id
                WHERE c.region_id = :id AND c.status = 'PUBLISHED'
                ORDER BY l.id, c.published_at DESC NULLS LAST
                """
            ),
            {"id": region_id},
        )
    ]

    enregistrements: list[dict] = []
    if langues:
        rows = await db.execute(
            text(
                """
                SELECT a.id, a.duration_ms, a.attribution, a.license::text AS license,
                       v.lemma, v.meaning_fr,
                       l.name AS language_name,
                       sp.display_code AS speaker_code
                FROM audio.audio_assets a
                JOIN corpus.vocabulary_items v
                  ON v.id = a.target_id AND a.target_type = 'VOCAB'
                JOIN ref.languages l ON l.id = a.language_id
                LEFT JOIN audio.speakers sp ON sp.id = a.speaker_id
                WHERE a.language_id = ANY(:langues) AND v.status = 'PUBLISHED'
                ORDER BY v.lemma
                """
            ),
            {"langues": [langue["id"] for langue in langues]},
        )
        enregistrements = [dict(r._mapping) for r in rows]

    # Medias attaches aux fiches de la region (image, audio, video).
    medias = [
        dict(r._mapping)
        for r in await db.execute(
            text(
                """
                SELECT m.id, m.kind::text AS kind, m.caption, m.credit, m.license,
                       c.id AS fiche_id, c.title_fr AS fiche_titre
                FROM culture.cultural_media m
                JOIN culture.cultural_contents c ON c.id = m.cultural_content_id
                WHERE c.region_id = :id AND c.status = 'PUBLISHED'
                ORDER BY m.position
                """
            ),
            {"id": region_id},
        )
    ]

    videos = [m for m in medias if m["kind"] == "VIDEO"]
    return {
        "region": dict(region._mapping),
        "langues": langues,
        "enregistrements": enregistrements,
        "medias": medias,
        "compteurs": {
            "enregistrements": len(enregistrements),
            "videos": len(videos),
            "images": len([m for m in medias if m["kind"] == "IMAGE"]),
        },
        "provenance": (
            "Les enregistrements proposés sont ceux des langues qu'une fiche publiée "
            "documente dans cette région. Chaque piste porte son attribution et sa "
            "licence."
            if enregistrements
            else "Aucune fiche publiée ne rattache encore de langue à cette région."
        ),
        "video": (
            "Aucune vidéo au catalogue. MBOA n'en diffusera que sous licence établie ; "
            "aucune illustration de remplissage n'est affichée."
            if not videos
            else None
        ),
    }


# ---------------------------------------------------------------------------
# Favoris
# ---------------------------------------------------------------------------
def _check_type(target_type: str) -> str:
    if target_type not in FAVORITE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Type inconnu. Valeurs acceptées : {', '.join(FAVORITE_TYPES)}.",
        )
    return target_type


async def _exists(db: AsyncSession, target_type: str, target_id: uuid.UUID) -> bool:
    """Un favori ne pointe que vers un contenu reellement accessible."""
    if target_type == "CULTURAL_CONTENT":
        requete = (
            "SELECT 1 FROM culture.cultural_contents "
            "WHERE id = :id AND status = 'PUBLISHED'"
        )
    else:
        requete = (
            "SELECT 1 FROM audio.audio_assets a "
            "JOIN corpus.vocabulary_items v "
            "  ON v.id = a.target_id AND a.target_type = 'VOCAB' "
            "WHERE a.id = :id AND v.status = 'PUBLISHED'"
        )
    return (await db.execute(text(requete), {"id": target_id})).first() is not None


@favorites_router.get("")
async def my_favorites(
    target_type: str | None = Query(default=None, alias="type"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Ce que la personne a mis de côté, fiches et enregistrements.

    Un favori dont la cible n'est plus publiée ne sort pas des listes : on ne
    ressert pas un contenu qui a été retiré, même s'il a été aimé.
    """
    if target_type is not None:
        _check_type(target_type)

    fiches: list[dict] = []
    if target_type in (None, "CULTURAL_CONTENT"):
        rows = await db.execute(
            text(
                """
                SELECT f.target_id AS id, f.created_at,
                       c.title_fr, c.summary_fr, c.reading_minutes,
                       cat.name_fr AS category_name, r.name AS region_name
                FROM culture.favorites f
                JOIN culture.cultural_contents c ON c.id = f.target_id
                JOIN culture.cultural_categories cat ON cat.id = c.category_id
                LEFT JOIN ref.regions r ON r.id = c.region_id
                WHERE f.user_id = :uid AND f.target_type = 'CULTURAL_CONTENT'
                  AND c.status = 'PUBLISHED'
                ORDER BY f.created_at DESC
                """
            ),
            {"uid": user.id},
        )
        fiches = [dict(r._mapping) for r in rows]

    enregistrements: list[dict] = []
    if target_type in (None, "AUDIO"):
        rows = await db.execute(
            text(
                """
                SELECT f.target_id AS id, f.created_at,
                       v.lemma, v.meaning_fr, a.attribution,
                       a.license::text AS license, l.name AS language_name
                FROM culture.favorites f
                JOIN audio.audio_assets a ON a.id = f.target_id
                JOIN corpus.vocabulary_items v
                  ON v.id = a.target_id AND a.target_type = 'VOCAB'
                JOIN ref.languages l ON l.id = a.language_id
                WHERE f.user_id = :uid AND f.target_type = 'AUDIO'
                  AND v.status = 'PUBLISHED'
                ORDER BY f.created_at DESC
                """
            ),
            {"uid": user.id},
        )
        enregistrements = [dict(r._mapping) for r in rows]

    return {
        "fiches": fiches,
        "enregistrements": enregistrements,
        "total": len(fiches) + len(enregistrements),
    }


@favorites_router.put("/{target_type}/{target_id}", status_code=status.HTTP_201_CREATED)
async def add_favorite(
    target_type: str,
    target_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Met un contenu de côté. Idempotent : réappuyer ne change rien."""
    _check_type(target_type)
    if not await _exists(db, target_type, target_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ce contenu n'existe pas ou n'est pas publié.",
        )

    await db.execute(
        text(
            """
            INSERT INTO culture.favorites (id, user_id, target_type, target_id)
            VALUES (:id, :uid, :type, :target)
            ON CONFLICT (user_id, target_type, target_id) DO NOTHING
            """
        ),
        {"id": uuid.uuid4(), "uid": user.id, "type": target_type, "target": target_id},
    )
    return {"favori": True}


@favorites_router.delete("/{target_type}/{target_id}")
async def remove_favorite(
    target_type: str,
    target_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    _check_type(target_type)
    await db.execute(
        text(
            """
            DELETE FROM culture.favorites
            WHERE user_id = :uid AND target_type = :type AND target_id = :target
            """
        ),
        {"uid": user.id, "type": target_type, "target": target_id},
    )
    return {"favori": False}


@favorites_router.get("/{target_type}/{target_id}")
async def is_favorite(
    target_type: str,
    target_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    _check_type(target_type)
    found = (
        await db.execute(
            text(
                """
                SELECT 1 FROM culture.favorites
                WHERE user_id = :uid AND target_type = :type AND target_id = :target
                """
            ),
            {"uid": user.id, "type": target_type, "target": target_id},
        )
    ).first()
    return {"favori": found is not None}
