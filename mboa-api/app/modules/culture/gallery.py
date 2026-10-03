"""La mediatheque : photographies et videos libres, servies en local.

Ce module ne decrit pas ce qu'on voit. Il sert un fichier, et il sert avec lui
les trois choses sans lesquelles la rediffusion serait illicite : **l'auteur, la
licence, et l'adresse de la page d'origine**. Le titre affiche est celui que
l'auteur a donne sur Commons ; MBOA n'en ajoute aucun.

Le `theme` est une etiquette de rangement (artisanat, danse, marche…), choisie
pour l'affichage. Ce n'est pas une affirmation sur le contenu : une photo rangee
sous « sculpture » n'est pas pour autant declaree representer telle culture.
"""

from __future__ import annotations

import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import FileResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session

router = APIRouter(prefix="/culture", tags=["culture"])

MEDIA_ROOT = Path(__file__).resolve().parents[3] / "media"
CULTURE_ROOT = MEDIA_ROOT / "culture"

#: Types servis. On ne devine pas depuis l'extension seule : une extension se
#: renomme, et servir un fichier sous un type qui n'est pas le sien expose le
#: navigateur a l'interpreter de travers.
TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".svg": "image/svg+xml",
    ".webm": "video/webm",
    ".ogv": "video/ogg",
    ".mp4": "video/mp4",
}


def _payload(row) -> dict:
    return {
        "id": str(row.id),
        "kind": row.kind,
        "url": f"/api/v1/culture/media/{row.file_key}",
        # Les mots de l'auteur, pas ceux de MBOA.
        "titre": row.title,
        "description": row.description,
        "auteur": row.author,
        "license": row.license,
        "source_url": row.source_url,
        "theme": row.theme,
        "region": getattr(row, "region", None),
        "largeur": row.width,
        "hauteur": row.height,
    }


@router.get("/gallery")
async def gallery(
    theme: str | None = Query(default=None),
    kind: str | None = Query(default=None, pattern="^(IMAGE|VIDEO)$"),
    limit: int = Query(default=60, ge=1, le=200),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """La mediatheque, avec ses themes et leurs effectifs."""
    conditions: list[str] = []
    params: dict = {"n": limit}
    if theme:
        conditions.append("m.theme = :theme")
        params["theme"] = theme
    if kind:
        conditions.append("m.kind::text = :kind")
        params["kind"] = kind
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""

    rows = await db.execute(
        text(
            f"""
            SELECT m.id, m.kind::text AS kind, m.file_key, m.title, m.description,
                   m.author, m.license, m.source_url, m.theme, m.width, m.height,
                   r.name AS region
            FROM culture.media_library m
            LEFT JOIN ref.regions r ON r.id = m.region_id
            {where}
            ORDER BY m.kind DESC, m.created_at DESC
            LIMIT :n
            """
        ),
        params,
    )
    medias = [_payload(r) for r in rows]

    themes = [
        {"code": r.theme, "total": r.total, "videos": r.videos}
        for r in await db.execute(
            text(
                """
                SELECT theme,
                       count(*) AS total,
                       count(*) FILTER (WHERE kind = 'VIDEO') AS videos
                FROM culture.media_library
                GROUP BY theme
                ORDER BY count(*) DESC
                """
            )
        )
    ]

    return {
        "medias": medias,
        "themes": themes,
        "total": sum(t["total"] for t in themes),
        "avertissement": (
            "Ces photographies et ces vidéos viennent de Wikimedia Commons. "
            "Chacune porte son auteur, sa licence et l'adresse de sa page "
            "d'origine. Les titres sont ceux de leurs auteurs : MBOA n'ajoute "
            "aucune description de son cru, et ne dit pas de qui ou de quoi "
            "relève ce qu'on voit."
        ),
    }


@router.get("/media/{chemin:path}")
async def get_media(chemin: str) -> FileResponse:
    """Sert un fichier de la mediatheque."""
    fichier = (MEDIA_ROOT / chemin).resolve()
    if (
        not fichier.is_relative_to(CULTURE_ROOT.resolve())
        or not fichier.is_file()
        or fichier.suffix.lower() not in TYPES
    ):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Média introuvable.")

    return FileResponse(
        fichier,
        media_type=TYPES[fichier.suffix.lower()],
        headers={"Cache-Control": "public, max-age=604800, immutable"},
    )


@router.get("/gallery/{media_id}")
async def media_detail(media_id: uuid.UUID, db: AsyncSession = Depends(get_session)) -> dict:
    row = (
        await db.execute(
            text(
                """
                SELECT m.id, m.kind::text AS kind, m.file_key, m.title, m.description,
                       m.author, m.license, m.source_url, m.theme, m.width, m.height,
                       r.name AS region
                FROM culture.media_library m
                LEFT JOIN ref.regions r ON r.id = m.region_id
                WHERE m.id = :id
                """
            ),
            {"id": media_id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Média introuvable.")
    return _payload(row)
