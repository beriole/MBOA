"""Console d'administration (SS43, SS44).

Ce module ne cree aucun contenu : il gere les comptes, les habilitations et les
parametres, et il donne a voir l'etat reel de la plateforme. Le contenu, lui,
reste soumis au circuit de provenance : un administrateur ne publie pas un mot
en passant par ici. C'est delibere : le pouvoir d'administrer n'est pas le
pouvoir d'affirmer qu'un mot existe.

Trois regles traversent tout le module :

1. tout acte est motive et journalise (`admin.audit_log`) ;
2. un administrateur ne peut ni modifier son propre role ni se desactiver,
   pour qu'il reste toujours au moins un compte capable de reparer une erreur ;
3. habiliter quelqu'un a valider une langue suppose un dossier : c'est la
   demande de specialiste, conservee avec la decision.
"""

from __future__ import annotations

import json
import uuid
from datetime import UTC, datetime
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.deps import get_current_user, require_roles
from app.modules.admin import stats
from app.modules.iam.models import User
from app.shared.enums import (
    VALIDATION_SCOPES,
    ApplicationStatus,
    ContributorRole,
    UserRole,
)

router = APIRouter(prefix="/admin", tags=["administration"])

#: Route ouverte a tout compte connecte : deposer sa candidature.
candidate_router = APIRouter(prefix="/me", tags=["administration"])

require_admin = require_roles(UserRole.ADMIN)

#: Parametres livres avec la plateforme. Chaque ligne est un choix de politique,
#: pas un reglage technique : ces derniers restent dans la configuration serveur.
DEFAULT_SETTINGS: tuple[dict[str, Any], ...] = (
    {
        "key": "registration_open",
        "value": True,
        "description_fr": "Les nouvelles inscriptions sont acceptees.",
    },
    {
        "key": "default_daily_goal_xp",
        "value": 20,
        "description_fr": "Objectif quotidien propose par defaut a l'inscription.",
    },
    {
        "key": "review_required_before_publish",
        "value": True,
        "description_fr": (
            "Relecture humaine obligatoire avant publication. Ce parametre est "
            "affiche pour memoire : la regle est appliquee par la base de donnees "
            "et ne peut pas etre desactivee ici."
        ),
        "is_editable": False,
    },
    {
        "key": "support_email",
        "value": "contact@example.org",
        "description_fr": "Adresse affichee aux utilisateurs en cas de probleme.",
    },
)


# ---------------------------------------------------------------------------
# Journal
# ---------------------------------------------------------------------------
async def record(
    db: AsyncSession,
    *,
    actor: User,
    action: str,
    target_type: str,
    target_id: uuid.UUID | None,
    target_label: str | None,
    reason: str,
    details: dict | None = None,
) -> None:
    """Consigne un acte d'administration.

    `actor_label` fige l'identite de l'auteur : si le compte est supprime plus
    tard, le journal reste lisible.
    """
    await db.execute(
        text(
            """
            INSERT INTO admin.audit_log
                (id, actor_user_id, actor_label, action, target_type, target_id,
                 target_label, reason, details)
            VALUES (:id, :actor, :label, :action, :tt, :ti, :tl, :reason,
                    CAST(:details AS jsonb))
            """
        ),
        {
            "id": uuid.uuid4(),
            "actor": actor.id,
            "label": f"{actor.display_name} <{actor.email}>",
            "action": action,
            "tt": target_type,
            "ti": target_id,
            "tl": target_label,
            "reason": reason.strip(),
            "details": json.dumps(details or {}),
        },
    )


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
class Motivated(BaseModel):
    """Toute action d'administration porte un motif.

    Cinq caracteres minimum : assez pour empecher un point ou un espace, pas
    assez pour transformer la console en formulaire administratif.
    """

    reason: str = Field(min_length=5, max_length=500)


class RoleChange(Motivated):
    role: UserRole


class StatusChange(Motivated):
    is_active: bool


class HabilitationIn(Motivated):
    language_id: uuid.UUID
    scope: list[str] = Field(default_factory=lambda: ["LEXICON"])
    contributor_role: ContributorRole = ContributorRole.NATIVE_SPEAKER
    affiliation: str | None = Field(default=None, max_length=200)


class ApplicationIn(BaseModel):
    language_id: uuid.UUID
    claimed_role: ContributorRole
    relationship_fr: str = Field(min_length=20, max_length=1000)
    affiliation: str | None = Field(default=None, max_length=200)
    referees_fr: str | None = Field(default=None, max_length=1000)
    evidence_url: str | None = Field(default=None, max_length=500)
    requested_scope: list[str] = Field(default_factory=lambda: ["LEXICON"])


class ApplicationDecision(Motivated):
    decision: Literal["ACCEPT", "REJECT", "NEEDS_INFO"]
    #: Perimetre finalement accorde ; a defaut, celui demande.
    granted_scope: list[str] | None = None


class SettingChange(Motivated):
    value: Any


def _check_scope(scope: list[str]) -> list[str]:
    unknown = [s for s in scope if s not in VALIDATION_SCOPES]
    if unknown:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Perimetre inconnu : {', '.join(unknown)}.",
        )
    if not scope:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Une habilitation sans perimetre n'a pas de sens.",
        )
    return scope


async def _user_or_404(db: AsyncSession, user_id: uuid.UUID):
    row = (
        await db.execute(
            text(
                """
                SELECT id, email, display_name, role::text AS role, is_active,
                       locale, daily_goal_xp, created_at, last_login_at
                FROM iam.users WHERE id = :id
                """
            ),
            {"id": user_id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Compte introuvable.")
    return row


# ---------------------------------------------------------------------------
# Tableau de bord
# ---------------------------------------------------------------------------
@router.get("/dashboard")
async def dashboard(
    _: User = Depends(require_admin), db: AsyncSession = Depends(get_session)
) -> dict:
    """Etat de la plateforme : activite, charge de relecture, integrite."""
    return await stats.dashboard(db)


@router.get("/integrity")
async def integrity(
    _: User = Depends(require_admin), db: AsyncSession = Depends(get_session)
) -> dict:
    """Les controles du cahier des charges, isoles pour un suivi rapproche.

    `conforme` vaut false des qu'un seul contenu publie echappe aux regles.
    """
    return await stats.integrity(db)


# ---------------------------------------------------------------------------
# Comptes
# ---------------------------------------------------------------------------
@router.get("/users")
async def list_users(
    q: str | None = Query(default=None, description="e-mail ou nom affiche"),
    role: UserRole | None = None,
    is_active: bool | None = None,
    limit: int = Query(default=30, le=100),
    offset: int = 0,
    _: User = Depends(require_admin),
    db: AsyncSession = Depends(get_session),
) -> dict:
    conditions = ["true"]
    params: dict = {"limit": limit, "offset": offset}
    if q:
        conditions.append("(u.email ILIKE :q OR u.display_name ILIKE :q)")
        params["q"] = f"%{q}%"
    if role is not None:
        conditions.append("u.role = CAST(:role AS shared.user_role)")
        params["role"] = role.value
    if is_active is not None:
        conditions.append("u.is_active = :active")
        params["active"] = is_active

    where = " AND ".join(conditions)
    total = (
        await db.execute(
            text(f"SELECT count(*) FROM iam.users u WHERE {where}"), params
        )
    ).scalar_one()

    rows = await db.execute(
        text(
            f"""
            SELECT u.id, u.email, u.display_name, u.role::text AS role, u.is_active,
                   u.created_at, u.last_login_at,
                   c.id AS contributor_id,
                   (SELECT count(*) FROM prov.validation_assignments a
                     WHERE a.contributor_id = c.id AND a.is_active) AS habilitations
            FROM iam.users u
            LEFT JOIN prov.contributors c ON c.user_id = u.id
            WHERE {where}
            ORDER BY u.created_at DESC
            LIMIT :limit OFFSET :offset
            """
        ),
        params,
    )
    return {"total": total, "items": [dict(r._mapping) for r in rows]}


@router.get("/users/{user_id}")
async def user_detail(
    user_id: uuid.UUID,
    _: User = Depends(require_admin),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Fiche d'un compte, avec ce qu'il a produit et ce qu'il a le droit de valider."""
    user = await _user_or_404(db, user_id)

    contributor = (
        await db.execute(
            text(
                """
                SELECT id, display_name, role, affiliation, is_active
                FROM prov.contributors WHERE user_id = :uid
                """
            ),
            {"uid": user_id},
        )
    ).one_or_none()

    habilitations: list[dict] = []
    contributions: dict = {"mots_rediges": 0, "mots_valides": 0, "fiches_redigees": 0}
    if contributor is not None:
        rows = await db.execute(
            text(
                """
                SELECT a.language_id, l.name AS language_name, l.iso639_3,
                       a.scope, a.is_active
                FROM prov.validation_assignments a
                JOIN ref.languages l ON l.id = a.language_id
                WHERE a.contributor_id = :cid
                ORDER BY l.name
                """
            ),
            {"cid": contributor.id},
        )
        habilitations = [dict(r._mapping) for r in rows]
        counts = (
            await db.execute(
                text(
                    """
                    SELECT
                        (SELECT count(*) FROM corpus.vocabulary_items
                          WHERE created_by = :cid) AS mots_rediges,
                        (SELECT count(*) FROM corpus.vocabulary_items
                          WHERE validated_by = :cid) AS mots_valides,
                        (SELECT count(*) FROM culture.cultural_contents
                          WHERE created_by = :cid) AS fiches_redigees
                    """
                ),
                {"cid": contributor.id},
            )
        ).one()
        contributions = dict(counts._mapping)

    journal = await db.execute(
        text(
            """
            SELECT action, reason, actor_label, created_at
            FROM admin.audit_log
            WHERE target_type = 'USER' AND target_id = :uid
            ORDER BY created_at DESC LIMIT 20
            """
        ),
        {"uid": user_id},
    )

    return {
        "compte": dict(user._mapping),
        "contributeur": dict(contributor._mapping) if contributor else None,
        "habilitations": habilitations,
        "contributions": contributions,
        "journal": [dict(r._mapping) for r in journal],
    }


@router.post("/users/{user_id}/role")
async def change_role(
    user_id: uuid.UUID,
    payload: RoleChange,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Change le role d'un compte.

    Promouvoir quelqu'un au rang de specialiste culturel ne l'habilite PAS a
    valider : il faut en plus une habilitation par langue. Les deux gestes sont
    distincts a dessein, pour qu'aucun ne se fasse par inadvertance.
    """
    if user_id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un administrateur ne modifie pas son propre role. "
            "Demandez-le a un autre administrateur.",
        )
    user = await _user_or_404(db, user_id)
    if user.role == payload.role.value:
        raise HTTPException(status_code=409, detail="Ce compte a deja ce role.")

    await db.execute(
        text("UPDATE iam.users SET role = CAST(:r AS shared.user_role) WHERE id = :id"),
        {"r": payload.role.value, "id": user_id},
    )
    await record(
        db,
        actor=admin,
        action="USER_ROLE_CHANGED",
        target_type="USER",
        target_id=user_id,
        target_label=user.email,
        reason=payload.reason,
        details={"avant": user.role, "apres": payload.role.value},
    )
    return {"id": str(user_id), "role": payload.role.value}


@router.post("/users/{user_id}/status")
async def change_status(
    user_id: uuid.UUID,
    payload: StatusChange,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Active ou desactive un compte.

    La desactivation revoque les jetons de rafraichissement en cours : la
    session ouverte sur un telephone ne survit pas a la decision.
    """
    if user_id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un administrateur ne desactive pas son propre compte.",
        )
    user = await _user_or_404(db, user_id)
    if user.is_active == payload.is_active:
        raise HTTPException(status_code=409, detail="Ce compte est deja dans cet etat.")

    await db.execute(
        text("UPDATE iam.users SET is_active = :a WHERE id = :id"),
        {"a": payload.is_active, "id": user_id},
    )
    if not payload.is_active:
        await db.execute(
            text(
                """
                UPDATE iam.refresh_tokens SET revoked_at = now()
                WHERE user_id = :id AND revoked_at IS NULL
                """
            ),
            {"id": user_id},
        )
    await record(
        db,
        actor=admin,
        action="USER_ACTIVATED" if payload.is_active else "USER_DEACTIVATED",
        target_type="USER",
        target_id=user_id,
        target_label=user.email,
        reason=payload.reason,
        details={"is_active": payload.is_active},
    )
    return {"id": str(user_id), "is_active": payload.is_active}


@router.post("/users/{user_id}/habilitations", status_code=status.HTTP_201_CREATED)
async def grant_habilitation(
    user_id: uuid.UUID,
    payload: HabilitationIn,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Habilite un compte a valider une langue (SS5).

    C'est l'acte le plus lourd de consequences de toute la console : il donne
    le droit de faire passer un contenu a VALIDATED, donc de decider qu'une
    forme est juste. Il ne s'exerce que sur un specialiste culturel declare.
    """
    scope = _check_scope(payload.scope)
    user = await _user_or_404(db, user_id)
    if user.role not in (UserRole.CULTURAL_SPECIALIST.value, UserRole.ADMIN.value):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce compte n'est pas specialiste culturel. Changez d'abord son role.",
        )

    language = (
        await db.execute(
            text("SELECT id, name FROM ref.languages WHERE id = :id"),
            {"id": payload.language_id},
        )
    ).one_or_none()
    if language is None:
        raise HTTPException(status_code=404, detail="Langue inconnue.")

    contributor_id = (
        await db.execute(
            text("SELECT id FROM prov.contributors WHERE user_id = :uid"), {"uid": user_id}
        )
    ).scalar_one_or_none()

    if contributor_id is None:
        contributor_id = uuid.uuid4()
        await db.execute(
            text(
                """
                INSERT INTO prov.contributors (id, user_id, display_name, role, affiliation)
                VALUES (:id, :uid, :name, :role, :aff)
                """
            ),
            {
                "id": contributor_id,
                "uid": user_id,
                "name": user.display_name,
                "role": payload.contributor_role.value,
                "aff": payload.affiliation,
            },
        )

    await db.execute(
        text(
            """
            INSERT INTO prov.validation_assignments
                (id, contributor_id, language_id, scope, is_active)
            VALUES (:id, :cid, :lang, :scope, true)
            ON CONFLICT (contributor_id, language_id)
            DO UPDATE SET scope = EXCLUDED.scope, is_active = true
            """
        ),
        {
            "id": uuid.uuid4(),
            "cid": contributor_id,
            "lang": payload.language_id,
            "scope": scope,
        },
    )
    await record(
        db,
        actor=admin,
        action="HABILITATION_GRANTED",
        target_type="USER",
        target_id=user_id,
        target_label=user.email,
        reason=payload.reason,
        details={"langue": language.name, "perimetre": scope},
    )
    return {
        "contributor_id": str(contributor_id),
        "language": language.name,
        "scope": scope,
    }


@router.delete("/users/{user_id}/habilitations/{language_id}")
async def revoke_habilitation(
    user_id: uuid.UUID,
    language_id: uuid.UUID,
    reason: str = Query(min_length=5, max_length=500),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Retire le droit de valider une langue.

    L'habilitation est desactivee, jamais effacee : les contenus deja valides
    gardent la trace de qui les a valides et sous quelle autorite.
    """
    user = await _user_or_404(db, user_id)
    updated = await db.execute(
        text(
            """
            UPDATE prov.validation_assignments a
            SET is_active = false
            FROM prov.contributors c
            WHERE a.contributor_id = c.id AND c.user_id = :uid
              AND a.language_id = :lang AND a.is_active
            RETURNING a.id
            """
        ),
        {"uid": user_id, "lang": language_id},
    )
    if updated.first() is None:
        raise HTTPException(status_code=404, detail="Aucune habilitation active a retirer.")

    await record(
        db,
        actor=admin,
        action="HABILITATION_REVOKED",
        target_type="USER",
        target_id=user_id,
        target_label=user.email,
        reason=reason,
        details={"language_id": str(language_id)},
    )
    return {"revoked": True}


# ---------------------------------------------------------------------------
# Demandes d'habilitation (le KYC de MBOA)
# ---------------------------------------------------------------------------
@candidate_router.post("/specialist-application", status_code=status.HTTP_201_CREATED)
async def apply(
    payload: ApplicationIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Deposer une candidature de specialiste culturel.

    La verification ne porte pas sur une identite bancaire mais sur la
    legitimite a repondre d'une langue : quel rapport la personne entretient
    avec elle, et qui peut en temoigner.
    """
    scope = _check_scope(payload.requested_scope)
    if user.role in (UserRole.CULTURAL_SPECIALIST, UserRole.ADMIN):
        existing = (
            await db.execute(
                text(
                    """
                    SELECT 1 FROM prov.validation_assignments a
                    JOIN prov.contributors c ON c.id = a.contributor_id
                    WHERE c.user_id = :uid AND a.language_id = :lang AND a.is_active
                    """
                ),
                {"uid": user.id, "lang": payload.language_id},
            )
        ).first()
        if existing:
            raise HTTPException(
                status_code=409, detail="Vous etes deja habilite pour cette langue."
            )

    pending = (
        await db.execute(
            text(
                """
                SELECT id FROM admin.specialist_applications
                WHERE user_id = :uid AND language_id = :lang
                  AND status IN ('PENDING','NEEDS_INFO')
                """
            ),
            {"uid": user.id, "lang": payload.language_id},
        )
    ).first()
    if pending:
        raise HTTPException(
            status_code=409,
            detail="Une demande est deja en cours pour cette langue.",
        )

    if (
        await db.execute(
            text("SELECT 1 FROM ref.languages WHERE id = :id"), {"id": payload.language_id}
        )
    ).first() is None:
        raise HTTPException(status_code=404, detail="Langue inconnue.")

    application_id = uuid.uuid4()
    await db.execute(
        text(
            """
            INSERT INTO admin.specialist_applications
                (id, user_id, language_id, claimed_role, relationship_fr, affiliation,
                 referees_fr, evidence_url, requested_scope, status)
            VALUES (:id, :uid, :lang, :role, :rel, :aff, :ref, :url, :scope, 'PENDING')
            """
        ),
        {
            "id": application_id,
            "uid": user.id,
            "lang": payload.language_id,
            "role": payload.claimed_role.value,
            "rel": payload.relationship_fr,
            "aff": payload.affiliation,
            "ref": payload.referees_fr,
            "url": payload.evidence_url,
            "scope": scope,
        },
    )
    return {"id": str(application_id), "status": "PENDING"}


@candidate_router.get("/specialist-application")
async def my_applications(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_session)
) -> list[dict]:
    rows = await db.execute(
        text(
            """
            SELECT a.id, a.status::text AS status, a.requested_scope, a.review_note,
                   a.created_at, a.reviewed_at, l.name AS language_name
            FROM admin.specialist_applications a
            JOIN ref.languages l ON l.id = a.language_id
            WHERE a.user_id = :uid
            ORDER BY a.created_at DESC
            """
        ),
        {"uid": user.id},
    )
    return [dict(r._mapping) for r in rows]


@router.get("/applications")
async def list_applications(
    application_status: ApplicationStatus | None = Query(default=None, alias="status"),
    limit: int = Query(default=30, le=100),
    _: User = Depends(require_admin),
    db: AsyncSession = Depends(get_session),
) -> list[dict]:
    conditions = ["true"]
    params: dict = {"limit": limit}
    if application_status is not None:
        conditions.append("a.status = CAST(:st AS shared.application_status)")
        params["st"] = application_status.value

    rows = await db.execute(
        text(
            f"""
            SELECT a.id, a.status::text AS status, a.claimed_role, a.relationship_fr,
                   a.affiliation, a.referees_fr, a.evidence_url, a.requested_scope,
                   a.created_at, a.reviewed_at, a.review_note,
                   u.id AS user_id, u.email, u.display_name, u.role::text AS user_role,
                   l.id AS language_id, l.name AS language_name
            FROM admin.specialist_applications a
            JOIN iam.users u ON u.id = a.user_id
            JOIN ref.languages l ON l.id = a.language_id
            WHERE {' AND '.join(conditions)}
            ORDER BY (a.status = 'PENDING') DESC, a.created_at
            LIMIT :limit
            """
        ),
        params,
    )
    return [dict(r._mapping) for r in rows]


@router.post("/applications/{application_id}/decision")
async def decide_application(
    application_id: uuid.UUID,
    payload: ApplicationDecision,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Statue sur une demande.

    ACCEPT fait trois choses d'un seul tenant, parce que les separer laisserait
    un compte a moitie habilite : le role passe a specialiste culturel, une
    fiche de contributeur est creee si elle manque, et l'habilitation par langue
    est posee. Le motif de la decision est conserve avec le dossier.
    """
    row = (
        await db.execute(
            text(
                """
                SELECT a.*, u.email, u.display_name, u.role::text AS user_role,
                       l.name AS language_name
                FROM admin.specialist_applications a
                JOIN iam.users u ON u.id = a.user_id
                JOIN ref.languages l ON l.id = a.language_id
                WHERE a.id = :id
                """
            ),
            {"id": application_id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Demande introuvable.")
    if row.status == ApplicationStatus.ACCEPTED.value:
        raise HTTPException(status_code=409, detail="Cette demande est deja acceptee.")
    if row.user_id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="On ne statue pas sur sa propre demande.",
        )

    new_status = {
        "ACCEPT": ApplicationStatus.ACCEPTED,
        "REJECT": ApplicationStatus.REJECTED,
        "NEEDS_INFO": ApplicationStatus.NEEDS_INFO,
    }[payload.decision]

    granted: list[str] = []
    if payload.decision == "ACCEPT":
        granted = _check_scope(payload.granted_scope or list(row.requested_scope))
        if row.user_role == UserRole.LEARNER.value:
            await db.execute(
                text(
                    "UPDATE iam.users SET role = 'CULTURAL_SPECIALIST' WHERE id = :id"
                ),
                {"id": row.user_id},
            )
        contributor_id = (
            await db.execute(
                text("SELECT id FROM prov.contributors WHERE user_id = :uid"),
                {"uid": row.user_id},
            )
        ).scalar_one_or_none()
        if contributor_id is None:
            contributor_id = uuid.uuid4()
            await db.execute(
                text(
                    """
                    INSERT INTO prov.contributors
                        (id, user_id, display_name, role, affiliation)
                    VALUES (:id, :uid, :name, :role, :aff)
                    """
                ),
                {
                    "id": contributor_id,
                    "uid": row.user_id,
                    "name": row.display_name,
                    "role": row.claimed_role,
                    "aff": row.affiliation,
                },
            )
        await db.execute(
            text(
                """
                INSERT INTO prov.validation_assignments
                    (id, contributor_id, language_id, scope, is_active)
                VALUES (:id, :cid, :lang, :scope, true)
                ON CONFLICT (contributor_id, language_id)
                DO UPDATE SET scope = EXCLUDED.scope, is_active = true
                """
            ),
            {
                "id": uuid.uuid4(),
                "cid": contributor_id,
                "lang": row.language_id,
                "scope": granted,
            },
        )

    await db.execute(
        text(
            """
            UPDATE admin.specialist_applications
            SET status = CAST(:st AS shared.application_status),
                reviewed_by = :by, reviewed_at = :at, review_note = :note
            WHERE id = :id
            """
        ),
        {
            "st": new_status.value,
            "by": admin.id,
            "at": datetime.now(UTC),
            "note": payload.reason,
            "id": application_id,
        },
    )
    await record(
        db,
        actor=admin,
        action=f"APPLICATION_{new_status.value}",
        target_type="SPECIALIST_APPLICATION",
        target_id=application_id,
        target_label=f"{row.email} / {row.language_name}",
        reason=payload.reason,
        details={"perimetre_accorde": granted} if granted else None,
    )
    return {"id": str(application_id), "status": new_status.value, "scope": granted}


# ---------------------------------------------------------------------------
# Parametres
# ---------------------------------------------------------------------------
async def ensure_default_settings(db: AsyncSession) -> None:
    """Depose les parametres livres avec la plateforme, sans ecraser les reglages."""
    for setting in DEFAULT_SETTINGS:
        await db.execute(
            text(
                """
                INSERT INTO admin.platform_settings
                    (key, value, description_fr, is_editable)
                VALUES (:key, CAST(:value AS jsonb), :desc, :editable)
                ON CONFLICT (key) DO NOTHING
                """
            ),
            {
                "key": setting["key"],
                "value": json.dumps(setting["value"]),
                "desc": setting["description_fr"],
                "editable": setting.get("is_editable", True),
            },
        )


@router.get("/settings")
async def list_settings(
    _: User = Depends(require_admin), db: AsyncSession = Depends(get_session)
) -> list[dict]:
    await ensure_default_settings(db)
    rows = await db.execute(
        text(
            """
            SELECT s.key, s.value, s.description_fr, s.is_editable, s.updated_at,
                   u.email AS updated_by_email
            FROM admin.platform_settings s
            LEFT JOIN iam.users u ON u.id = s.updated_by
            ORDER BY s.key
            """
        )
    )
    return [dict(r._mapping) for r in rows]


@router.put("/settings/{key}")
async def update_setting(
    key: str,
    payload: SettingChange,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_session),
) -> dict:
    await ensure_default_settings(db)
    row = (
        await db.execute(
            text(
                "SELECT key, value, is_editable FROM admin.platform_settings WHERE key = :k"
            ),
            {"k": key},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Parametre inconnu.")
    if not row.is_editable:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce parametre est verrouille : la regle qu'il decrit est appliquee "
            "par la base de donnees et ne se desactive pas depuis la console.",
        )
    if type(payload.value) is not type(row.value):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="La valeur fournie n'est pas du meme type que la valeur actuelle.",
        )

    await db.execute(
        text(
            """
            UPDATE admin.platform_settings
            SET value = CAST(:v AS jsonb), updated_by = :by
            WHERE key = :k
            """
        ),
        {"v": json.dumps(payload.value), "by": admin.id, "k": key},
    )
    await record(
        db,
        actor=admin,
        action="SETTING_CHANGED",
        target_type="SETTING",
        target_id=None,
        target_label=key,
        reason=payload.reason,
        details={"avant": row.value, "apres": payload.value},
    )
    return {"key": key, "value": payload.value}


# ---------------------------------------------------------------------------
# Journal
# ---------------------------------------------------------------------------
@router.get("/audit")
async def audit(
    action: str | None = None,
    target_id: uuid.UUID | None = None,
    limit: int = Query(default=50, le=200),
    _: User = Depends(require_admin),
    db: AsyncSession = Depends(get_session),
) -> list[dict]:
    """Le journal des actes d'administration.

    En lecture seule : aucune route ne permet d'en effacer une ligne.
    """
    conditions = ["true"]
    params: dict = {"limit": limit}
    if action:
        conditions.append("action = :action")
        params["action"] = action
    if target_id:
        conditions.append("target_id = :target")
        params["target"] = target_id

    rows = await db.execute(
        text(
            f"""
            SELECT id, actor_label, action, target_type, target_id, target_label,
                   reason, details, created_at
            FROM admin.audit_log
            WHERE {' AND '.join(conditions)}
            ORDER BY created_at DESC, id
            LIMIT :limit
            """
        ),
        params,
    )
    return [dict(r._mapping) for r in rows]
