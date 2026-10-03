"""Culture Hub : consultation du patrimoine (SS20) et lien avec les lecons (SS21).

Comme partout ailleurs, seules les fiches PUBLISHED sortent de l'API, et chacune
expose ses sources : une affirmation culturelle sans provenance n'a pas sa place
dans MBOA.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session

router = APIRouter(prefix="/culture", tags=["culture"])

_CONTENT_COLUMNS = """
    c.id, c.title_fr, c.summary_fr, c.reading_minutes,
    cat.code::text AS category_code, cat.name_fr AS category_name,
    r.name AS region_name, l.name AS language_name
"""

_CONTENT_JOINS = """
    FROM culture.cultural_contents c
    JOIN culture.cultural_categories cat ON cat.id = c.category_id
    LEFT JOIN ref.regions r ON r.id = c.region_id
    LEFT JOIN ref.languages l ON l.id = c.language_id
"""


@router.get("/categories")
async def categories(db: AsyncSession = Depends(get_session)) -> list[dict]:
    """Les rubriques, avec le nombre de fiches publiees dans chacune.

    Les rubriques vides sont renvoyees aussi : montrer ce qui reste a documenter
    fait partie du propos.
    """
    rows = await db.execute(
        text(
            """
            SELECT cat.id, cat.code::text AS code, cat.name_fr, cat.description_fr,
                   cat.position,
                   count(c.id) FILTER (WHERE c.status = 'PUBLISHED') AS published_count
            FROM culture.cultural_categories cat
            LEFT JOIN culture.cultural_contents c ON c.category_id = cat.id
            WHERE cat.is_active
            GROUP BY cat.id, cat.code, cat.name_fr, cat.description_fr, cat.position
            ORDER BY count(c.id) FILTER (WHERE c.status = 'PUBLISHED') DESC, cat.position
            """
        )
    )
    return [dict(r._mapping) for r in rows]


@router.get("")
async def list_contents(
    category: str | None = Query(default=None, description="code de rubrique"),
    region_id: uuid.UUID | None = None,
    language_id: uuid.UUID | None = None,
    limit: int = Query(default=30, le=100),
    db: AsyncSession = Depends(get_session),
) -> dict:
    conditions = ["c.status = 'PUBLISHED'"]
    params: dict = {"limit": limit}
    if category:
        conditions.append("cat.code::text = :category")
        params["category"] = category
    if region_id:
        conditions.append("c.region_id = :region")
        params["region"] = region_id
    if language_id:
        conditions.append("c.language_id = :language")
        params["language"] = language_id

    rows = await db.execute(
        text(
            f"""
            SELECT {_CONTENT_COLUMNS}
            {_CONTENT_JOINS}
            WHERE {' AND '.join(conditions)}
            ORDER BY c.published_at DESC NULLS LAST, c.title_fr
            LIMIT :limit
            """
        ),
        params,
    )
    items = [dict(r._mapping) for r in rows]
    return {"count": len(items), "items": items}


# Declaree avant `/{content_id}` : sinon « cards » serait pris pour un identifiant.
@router.get("/cards/unit/{unit_id}")
async def culture_card(
    unit_id: uuid.UUID, db: AsyncSession = Depends(get_session)
) -> dict | None:
    """La carte « Le savais-tu ? » d'une unite (SS21).

    Renvoie `null` quand aucune fiche n'est rattachee : l'application affiche
    alors simplement la lecon sans carte, plutot qu'un contenu de remplissage.
    """
    row = (
        await db.execute(
            text(
                """
                SELECT c.id, c.title_fr, c.summary_fr, cat.name_fr AS category_name,
                       s.title AS source_title
                FROM culture.cultural_links link
                JOIN culture.cultural_contents c ON c.id = link.cultural_content_id
                JOIN culture.cultural_categories cat ON cat.id = c.category_id
                LEFT JOIN prov.sources s ON s.id = c.source_id
                WHERE link.target_type = 'UNIT' AND link.target_id = :id
                  AND link.placement = 'DID_YOU_KNOW'
                  AND c.status = 'PUBLISHED'
                ORDER BY link.created_at
                LIMIT 1
                """
            ),
            {"id": unit_id},
        )
    ).one_or_none()

    return dict(row._mapping) if row else None


@router.get("/{content_id}")
async def get_content(
    content_id: uuid.UUID, db: AsyncSession = Depends(get_session)
) -> dict:
    row = (
        await db.execute(
            text(
                f"""
                SELECT {_CONTENT_COLUMNS}, c.body_fr, c.category_id, c.language_id,
                       s.title AS source_title, s.license::text AS source_license,
                       s.url AS source_url, s.authors AS source_authors, s.year AS source_year,
                       contrib.display_name AS validated_by
                {_CONTENT_JOINS}
                LEFT JOIN prov.sources s ON s.id = c.source_id
                LEFT JOIN prov.contributors contrib ON contrib.id = c.validated_by
                WHERE c.id = :id AND c.status = 'PUBLISHED'
                """
            ),
            {"id": content_id},
        )
    ).one_or_none()

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Fiche introuvable.")

    references = await db.execute(
        text(
            """
            SELECT s.title, s.authors, s.year, s.url, s.license::text AS license, r.locator
            FROM prov.source_references r
            JOIN prov.sources s ON s.id = r.source_id
            WHERE r.target_type = 'cultural_contents' AND r.target_id = :id
            ORDER BY s.year DESC NULLS LAST
            """
        ),
        {"id": content_id},
    )
    media = await db.execute(
        text(
            """
            SELECT kind::text AS kind, file_key, caption, credit, license
            FROM culture.cultural_media
            WHERE cultural_content_id = :id ORDER BY position
            """
        ),
        {"id": content_id},
    )
    related = await db.execute(
        text(
            f"""
            SELECT {_CONTENT_COLUMNS}
            {_CONTENT_JOINS}
            WHERE c.status = 'PUBLISHED' AND c.id <> :id
              AND (c.category_id = :category OR c.language_id = :language)
            ORDER BY (c.category_id = :category) DESC
            LIMIT 3
            """
        ),
        {"id": content_id, "category": row.category_id, "language": row.language_id},
    )

    payload = dict(row._mapping)
    payload.pop("category_id", None)
    payload.pop("language_id", None)
    payload["sources"] = [dict(r._mapping) for r in references]
    payload["media"] = [dict(r._mapping) for r in media]
    payload["related"] = [dict(r._mapping) for r in related]
    return payload
