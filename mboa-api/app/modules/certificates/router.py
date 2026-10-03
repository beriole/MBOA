"""Attestations de parcours (SS15) : emission, telechargement, verification.

Le principe applique ici est celui de tout le projet, transpose a l'apprenant :
**on n'atteste que ce qu'on a constate**. L'attestation enonce des lecons
terminees et un score ; elle dit explicitement qu'elle ne certifie pas un
niveau de langue.

La verification est publique et sans authentification : une attestation qu'un
employeur ne peut pas verifier ne vaut rien. Elle ne divulgue que ce qui figure
deja sur le document remis.
"""

from __future__ import annotations

import secrets
import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.deps import get_current_user, require_roles
from app.modules.admin.router import record
from app.modules.certificates import pdf
from app.modules.iam.models import User
from app.shared.enums import UserRole

router = APIRouter(prefix="/me/certificates", tags=["attestations"])

#: Verification : ouverte, sans jeton.
public_router = APIRouter(prefix="/certificates", tags=["attestations"])

#: Revocation : reservee a l'administration.
admin_router = APIRouter(prefix="/admin/certificates", tags=["attestations"])

#: Alphabet sans 0/O ni 1/I/L : un code se lit au telephone sans ambiguite.
_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"

#: Colonnes exposees, identiques pour la liste, le PDF et la verification.
_COLUMNS = """
    c.id, c.code, c.learner_name, c.course_title, c.section_title,
    c.language_name, c.language_iso, c.level,
    c.lessons_completed, c.lessons_total, c.average_score, c.exercises_answered,
    c.started_at, c.completed_at, c.issued_at, c.revoked_at, c.revoked_reason
"""


def new_code(iso: str) -> str:
    suffix = "".join(secrets.choice(_ALPHABET) for _ in range(6))
    return f"MBOA-{iso.upper()}-{datetime.now(UTC).year}-{suffix}"


class IssueIn(BaseModel):
    section_id: uuid.UUID


class RevokeIn(BaseModel):
    reason: str = Field(min_length=5, max_length=500)


async def _progress_in_section(
    db: AsyncSession, user_id: uuid.UUID, section_id: uuid.UUID
) -> dict | None:
    """Etat du parcours d'une personne sur une section, lu depuis la progression."""
    row = (
        await db.execute(
            text(
                """
                SELECT s.id AS section_id, s.title_fr AS section_title,
                       co.title_fr AS course_title, co.level::text AS level,
                       l.name AS language_name, l.iso639_3 AS language_iso,
                       count(le.id) AS lessons_total,
                       count(p.id) FILTER (WHERE p.status = 'COMPLETED') AS lessons_completed,
                       COALESCE(
                           avg(p.best_score) FILTER (WHERE p.status = 'COMPLETED'), 0
                       ) AS average_score,
                       min(p.first_completed_at) AS started_at,
                       max(COALESCE(p.last_completed_at, p.first_completed_at)) AS completed_at
                FROM learn.sections s
                JOIN learn.courses co ON co.id = s.course_id
                JOIN ref.languages l ON l.id = co.language_id
                JOIN learn.units u ON u.section_id = s.id
                JOIN learn.lessons le ON le.unit_id = u.id
                LEFT JOIN progress.lesson_progress p
                       ON p.lesson_id = le.id AND p.user_id = :uid
                WHERE s.id = :sid
                GROUP BY s.id, s.title_fr, co.title_fr, co.level, l.name, l.iso639_3
                """
            ),
            {"uid": user_id, "sid": section_id},
        )
    ).one_or_none()
    return dict(row._mapping) if row else None


@router.get("")
async def my_certificates(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_session)
) -> dict:
    """Les attestations obtenues, et celles qui peuvent l'etre.

    `disponibles` ne liste que des sections reellement terminees : le bouton
    n'apparait pas avant que le parcours ne soit fait.
    """
    delivrees = await db.execute(
        text(
            f"""
            SELECT {_COLUMNS}, c.section_id
            FROM progress.certificates c
            WHERE c.user_id = :uid
            ORDER BY c.issued_at DESC
            """
        ),
        {"uid": user.id},
    )
    obtenues = [dict(r._mapping) for r in delivrees]
    deja = {r["section_id"] for r in obtenues}

    # Sections entierement terminees et pas encore attestees.
    rows = await db.execute(
        text(
            """
            SELECT s.id AS section_id, s.title_fr AS section_title,
                   co.title_fr AS course_title, l.name AS language_name,
                   count(le.id) AS lessons_total,
                   count(p.id) FILTER (WHERE p.status = 'COMPLETED') AS lessons_completed
            FROM learn.sections s
            JOIN learn.courses co ON co.id = s.course_id
            JOIN ref.languages l ON l.id = co.language_id
            JOIN learn.units u ON u.section_id = s.id
            JOIN learn.lessons le ON le.unit_id = u.id
            LEFT JOIN progress.lesson_progress p
                   ON p.lesson_id = le.id AND p.user_id = :uid
            GROUP BY s.id, s.title_fr, co.title_fr, l.name
            HAVING count(le.id) > 0
               AND count(p.id) FILTER (WHERE p.status = 'COMPLETED') = count(le.id)
            ORDER BY s.position
            """
        ),
        {"uid": user.id},
    )
    disponibles = [
        dict(r._mapping) for r in rows if r._mapping["section_id"] not in deja
    ]
    return {"delivrees": obtenues, "disponibles": disponibles}


@router.post("", status_code=status.HTTP_201_CREATED)
async def issue(
    payload: IssueIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Emet l'attestation d'une section terminee.

    Idempotent : redemander la meme attestation renvoie celle qui existe, avec
    son code d'origine. Une attestation qui changerait de numero a chaque appel
    ne serait pas verifiable.
    """
    existing = (
        await db.execute(
            text(
                f"""
                SELECT {_COLUMNS} FROM progress.certificates c
                WHERE c.user_id = :uid AND c.section_id = :sid
                """
            ),
            {"uid": user.id, "sid": payload.section_id},
        )
    ).one_or_none()
    if existing is not None:
        return dict(existing._mapping)

    etat = await _progress_in_section(db, user.id, payload.section_id)
    if etat is None:
        raise HTTPException(status_code=404, detail="Section introuvable ou sans lecon.")
    if etat["lessons_completed"] < etat["lessons_total"]:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"Parcours incomplet : {etat['lessons_completed']} lecon(s) terminee(s) "
                f"sur {etat['lessons_total']}."
            ),
        )

    answered = (
        await db.execute(
            text(
                """
                SELECT count(*) FROM progress.exercise_attempts a
                JOIN progress.lesson_sessions ls ON ls.id = a.session_id
                JOIN learn.lessons le ON le.id = ls.lesson_id
                JOIN learn.units u ON u.id = le.unit_id
                WHERE a.user_id = :uid AND u.section_id = :sid
                """
            ),
            {"uid": user.id, "sid": payload.section_id},
        )
    ).scalar_one()

    certificate_id = uuid.uuid4()
    params = {
        "id": certificate_id,
        "uid": user.id,
        "sid": payload.section_id,
        "code": new_code(etat["language_iso"]),
        "name": user.display_name,
        "course": etat["course_title"],
        "section": etat["section_title"],
        "lang": etat["language_name"],
        "iso": etat["language_iso"],
        "level": etat["level"],
        "done": etat["lessons_completed"],
        "total": etat["lessons_total"],
        "score": round(float(etat["average_score"]), 4),
        "answered": answered,
        "started": etat["started_at"],
        "completed": etat["completed_at"] or datetime.now(UTC),
    }
    try:
        await db.execute(
            text(
                """
                INSERT INTO progress.certificates
                    (id, user_id, section_id, code, learner_name, course_title,
                     section_title, language_name, language_iso, level,
                     lessons_completed, lessons_total, average_score,
                     exercises_answered, started_at, completed_at)
                VALUES (:id, :uid, :sid, :code, :name, :course, :section, :lang, :iso,
                        :level, :done, :total, :score, :answered, :started, :completed)
                """
            ),
            params,
        )
    except DBAPIError as exc:
        # Le trigger recompte le parcours : si l'API et la base divergent,
        # c'est la base qui tranche.
        if "MBOA[" in str(exc.orig):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="La base a refuse cette attestation : le parcours ne la justifie pas.",
            ) from exc
        raise

    issued = (
        await db.execute(
            text(f"SELECT {_COLUMNS} FROM progress.certificates c WHERE c.id = :id"),
            {"id": certificate_id},
        )
    ).one()
    return dict(issued._mapping)


def _verification_url(code: str) -> str:
    return f"mboa.local/attestation/{code}"


@router.get("/{certificate_id}/pdf")
async def download(
    certificate_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> Response:
    row = (
        await db.execute(
            text(
                f"""
                SELECT {_COLUMNS} FROM progress.certificates c
                WHERE c.id = :id AND c.user_id = :uid
                """
            ),
            {"id": certificate_id, "uid": user.id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Attestation introuvable.")

    data = dict(row._mapping)
    if data["revoked_at"] is not None:
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail="Cette attestation a ete revoquee ; elle n'est plus telechargeable.",
        )

    content = pdf.render(data, verification_url=_verification_url(data["code"]))
    return Response(
        content=content,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="attestation-{data["code"]}.pdf"'
        },
    )


@public_router.get("/verify/{code}")
async def verify(code: str, db: AsyncSession = Depends(get_session)) -> dict:
    """Verification publique d'une attestation, sans authentification.

    Ne renvoie que ce qui figure sur le document remis. Un code inconnu donne
    une reponse claire plutot qu'un 404 muet : c'est un tiers qui interroge,
    pas un developpeur.
    """
    row = (
        await db.execute(
            text(f"SELECT {_COLUMNS} FROM progress.certificates c WHERE c.code = :code"),
            {"code": code.strip().upper()},
        )
    ).one_or_none()

    if row is None:
        return {
            "valide": False,
            "motif": "Aucune attestation ne porte ce code.",
            "code": code.strip().upper(),
        }

    data = dict(row._mapping)
    if data["revoked_at"] is not None:
        return {
            "valide": False,
            "motif": "Cette attestation a ete revoquee.",
            "revoquee_le": data["revoked_at"],
            "code": data["code"],
        }

    return {
        "valide": True,
        "code": data["code"],
        "titulaire": data["learner_name"],
        "parcours": data["section_title"],
        "cours": data["course_title"],
        "langue": data["language_name"],
        "lecons_terminees": data["lessons_completed"],
        "lecons_totales": data["lessons_total"],
        "score_moyen": round(data["average_score"] * 100),
        "achevee_le": data["completed_at"],
        "delivree_le": data["issued_at"],
        "portee": pdf.DISCLAIMER,
    }


@admin_router.get("")
async def list_certificates(
    q: str | None = Query(default=None, description="code ou nom du titulaire"),
    limit: int = Query(default=50, le=200),
    _: User = Depends(require_roles(UserRole.ADMIN)),
    db: AsyncSession = Depends(get_session),
) -> list[dict]:
    conditions = ["true"]
    params: dict = {"limit": limit}
    if q:
        conditions.append("(c.code ILIKE :q OR c.learner_name ILIKE :q)")
        params["q"] = f"%{q}%"

    rows = await db.execute(
        text(
            f"""
            SELECT {_COLUMNS} FROM progress.certificates c
            WHERE {' AND '.join(conditions)}
            ORDER BY c.issued_at DESC LIMIT :limit
            """
        ),
        params,
    )
    return [dict(r._mapping) for r in rows]


@admin_router.post("/{certificate_id}/revoke")
async def revoke(
    certificate_id: uuid.UUID,
    payload: RevokeIn,
    admin: User = Depends(require_roles(UserRole.ADMIN)),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Revoque une attestation.

    On ne l'efface pas : le code continue de repondre a la verification, en
    disant qu'elle a ete revoquee. Une attestation qui disparaitrait laisserait
    le tiers qui la detient sans reponse.
    """
    row = (
        await db.execute(
            text(
                """
                SELECT id, code, learner_name, revoked_at
                FROM progress.certificates WHERE id = :id
                """
            ),
            {"id": certificate_id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Attestation introuvable.")
    if row.revoked_at is not None:
        raise HTTPException(status_code=409, detail="Cette attestation est deja revoquee.")

    await db.execute(
        text(
            """
            UPDATE progress.certificates
            SET revoked_at = now(), revoked_reason = :reason WHERE id = :id
            """
        ),
        {"reason": payload.reason, "id": certificate_id},
    )
    await record(
        db,
        actor=admin,
        action="CERTIFICATE_REVOKED",
        target_type="CERTIFICATE",
        target_id=certificate_id,
        target_label=f"{row.code} / {row.learner_name}",
        reason=payload.reason,
    )
    return {"code": row.code, "revoked": True}
