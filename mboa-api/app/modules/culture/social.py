"""Commentaires et avis : ce que les gens disent, distinct de ce qui est etabli.

Une regle fondatrice du projet interdit d'inventer un fait culturel ou
linguistique. Ouvrir les commentaires n'y contrevient pas - a une condition,
qui structure tout ce module : **un avis n'est pas une source.**

Concretement :

  - un commentaire porte toujours le nom de qui l'ecrit et la date ; il n'est
    jamais fondu dans le corps d'une fiche, jamais repris dans un quiz, jamais
    compte comme une documentation ;
  - la note (1 a 5) mesure l'appreciation d'un objet vendu, pas la justesse d'un
    contenu culturel. On ne vote pas sur un fait ;
  - un contenu signale est masque en attendant l'examen, pas supprime : ce qui
    a ete dit reste consultable par l'administration.

La cible est polymorphe, comme les favoris : fiche culturelle, enregistrement
ou produit. Une seule table, une seule moderation.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.deps import get_current_user

router = APIRouter(prefix="/social", tags=["social"])

#: Ce sur quoi on peut s'exprimer, et l'etat que la cible doit avoir.
TARGETS = {
    "CULTURAL_CONTENT": ("culture.cultural_contents", "PUBLISHED"),
    "AUDIO": ("audio.audio_assets", None),
    "PRODUCT": ("market.products", "PUBLISHED"),
}

#: Une note n'a de sens que sur ce qui se juge : un objet, un service. Elle n'en
#: a aucun sur un fait de langue, et ce module la refuse.
RATEABLE = {"PRODUCT"}

NOTICE = (
    "Les commentaires expriment l'avis de leurs auteurs. Ils ne sont ni vérifiés "
    "ni sourcés, et ne font pas partie du contenu documenté."
)


class CommentIn(BaseModel):
    body_fr: str = Field(min_length=2, max_length=2000)
    rating: int | None = Field(default=None, ge=1, le=5)

    @field_validator("body_fr")
    @classmethod
    def _non_vide(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Un commentaire vide n'apporte rien.")
        return v.strip()


class ReportIn(BaseModel):
    reason: str = Field(min_length=5, max_length=500)


async def _check_target(db: AsyncSession, target_type: str, target_id: uuid.UUID) -> None:
    """Refuse de commenter ce qui n'existe pas ou n'est pas publie."""
    if target_type not in TARGETS:
        raise HTTPException(
            status_code=422,
            detail=f"Cible inconnue. Attendu : {', '.join(sorted(TARGETS))}.",
        )
    table, requis = TARGETS[target_type]
    condition = " AND status = :statut" if requis else ""
    params: dict = {"id": target_id}
    if requis:
        params["statut"] = requis
    trouve = (
        await db.execute(text(f"SELECT 1 FROM {table} WHERE id = :id{condition}"), params)
    ).scalar_one_or_none()
    if trouve is None:
        raise HTTPException(
            status_code=404,
            detail="Cet élément n'existe pas ou n'est pas publié : on ne commente "
            "que ce qui est visible.",
        )


@router.get("/{target_type}/{target_id}/comments")
async def list_comments(
    target_type: str,
    target_id: uuid.UUID,
    limit: int = Query(default=50, ge=1, le=200),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Les commentaires visibles, du plus recent au plus ancien."""
    if target_type not in TARGETS:
        raise HTTPException(status_code=422, detail="Cible inconnue.")

    rows = await db.execute(
        text(
            """
            SELECT c.id, c.body_fr, c.rating, c.created_at, c.author_label
            FROM culture.comments c
            WHERE c.target_type = :t AND c.target_id = :id AND c.hidden_at IS NULL
            ORDER BY c.created_at DESC
            LIMIT :n
            """
        ),
        {"t": target_type, "id": target_id, "n": limit},
    )
    commentaires = [dict(r._mapping) for r in rows]

    note = (
        await db.execute(
            text(
                """
                SELECT count(*) FILTER (WHERE rating IS NOT NULL) AS votants,
                       avg(rating)::numeric(3,2) AS moyenne
                FROM culture.comments
                WHERE target_type = :t AND target_id = :id AND hidden_at IS NULL
                """
            ),
            {"t": target_type, "id": target_id},
        )
    ).one()

    return {
        "commentaires": [
            {
                "id": str(c["id"]),
                "auteur": c["author_label"],
                "body_fr": c["body_fr"],
                "rating": c["rating"],
                "created_at": c["created_at"],
            }
            for c in commentaires
        ],
        "total": len(commentaires),
        "note_moyenne": float(note.moyenne) if note.moyenne is not None else None,
        "votants": note.votants,
        "notable": target_type in RATEABLE,
        "avertissement": NOTICE,
    }


@router.post("/{target_type}/{target_id}/comments", status_code=status.HTTP_201_CREATED)
async def add_comment(
    target_type: str,
    target_id: uuid.UUID,
    payload: CommentIn,
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Publie un commentaire, eventuellement note."""
    await _check_target(db, target_type, target_id)

    if payload.rating is not None and target_type not in RATEABLE:
        raise HTTPException(
            status_code=422,
            detail="On ne note pas un contenu culturel : une note mesure une "
            "appréciation, pas l'exactitude d'un fait. Le commentaire seul est "
            "accepté ici.",
        )

    # Le nom est fige a l'ecriture : un pseudonyme change plus tard ne doit pas
    # reecrire ce qui a ete dit sous l'ancien.
    libelle = user.display_name or user.email.split("@")[0]

    row = (
        await db.execute(
            text(
                """
                INSERT INTO culture.comments
                    (id, user_id, author_label, target_type, target_id, body_fr, rating)
                VALUES (gen_random_uuid(), :u, :label, :t, :id, :body, :note)
                RETURNING id, created_at
                """
            ),
            {
                "u": user.id,
                "label": libelle,
                "t": target_type,
                "id": target_id,
                "body": payload.body_fr,
                "note": payload.rating,
            },
        )
    ).one()
    await db.commit()

    return {
        "id": str(row.id),
        "auteur": libelle,
        "body_fr": payload.body_fr,
        "rating": payload.rating,
        "created_at": row.created_at,
        "avertissement": NOTICE,
    }


@router.delete("/comments/{comment_id}")
async def delete_comment(
    comment_id: uuid.UUID,
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Retire son propre commentaire."""
    supprime = (
        await db.execute(
            text("DELETE FROM culture.comments WHERE id = :id AND user_id = :u RETURNING id"),
            {"id": comment_id, "u": user.id},
        )
    ).scalar_one_or_none()
    if supprime is None:
        raise HTTPException(
            status_code=404,
            detail="Commentaire introuvable, ou écrit par quelqu'un d'autre.",
        )
    await db.commit()
    return {"supprime": True}


@router.post("/comments/{comment_id}/report", status_code=status.HTTP_202_ACCEPTED)
async def report_comment(
    comment_id: uuid.UUID,
    payload: ReportIn,
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Signale un commentaire.

    Le signalement masque immediatement, mais ne supprime pas : l'administration
    doit pouvoir lire ce qui a ete signale pour trancher. Un signalement abusif
    se voit, puisque son auteur et son motif sont conserves.
    """
    existe = (
        await db.execute(
            text("SELECT 1 FROM culture.comments WHERE id = :id"), {"id": comment_id}
        )
    ).scalar_one_or_none()
    if existe is None:
        raise HTTPException(status_code=404, detail="Commentaire introuvable.")

    await db.execute(
        text(
            """
            INSERT INTO culture.comment_reports (id, comment_id, user_id, reason)
            VALUES (gen_random_uuid(), :c, :u, :r)
            ON CONFLICT (comment_id, user_id) DO UPDATE SET reason = EXCLUDED.reason
            """
        ),
        {"c": comment_id, "u": user.id, "r": payload.reason},
    )
    await db.execute(
        text(
            "UPDATE culture.comments SET hidden_at = now(), "
            "hidden_reason = :motif WHERE id = :id AND hidden_at IS NULL"
        ),
        {"id": comment_id, "motif": "Signalé, en attente d'examen"},
    )
    await db.commit()
    return {
        "signale": True,
        "message": "Le commentaire est masqué en attendant l'examen. Il n'est pas "
        "supprimé : l'administration doit pouvoir le lire pour trancher.",
    }
