"""Configuration initiale de l'apprenant (lot 3 des maquettes).

Les huit etapes de la planche demandent, dans l'ordre : la langue, la motivation,
le niveau, le temps quotidien, les centres d'interet, un test de positionnement
facultatif, les notifications, puis un recapitulatif.

Deux choses sont dites franchement plutot que simulees :

  - **les notifications** enregistrent un consentement ; aucun envoi n'est
    branche, et rien ici ne pretend le contraire ;
  - **le test de positionnement** n'est propose que si le corpus publie permet
    de poser de vraies questions : assez nombreuses, et d'au moins deux types.
    Vingt-quatre questions d'ecoute sur treize mots disent si l'on reconnait
    ces treize sons, pas si l'on est debutant ou avance. Dans ce cas, l'etape
    se declare indisponible au lieu de produire un faux niveau.
"""

from __future__ import annotations

import json
import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.deps import get_current_user
from app.modules.iam.models import User
from app.shared.enums import (
    MINUTES_TO_XP,
    NOTIFICATION_KEYS,
    CulturalCategoryCode,
    LearningMotivation,
)

router = APIRouter(prefix="/me/preferences", tags=["configuration"])

#: En deca, un test de positionnement ne mesurerait rien de fiable.
MIN_QUESTIONS_FOR_PLACEMENT = 8

#: Un test bati sur un seul type d'exercice ne situe pas un niveau : il mesure
#: une seule competence. Vingt-quatre questions d'ecoute sur treize mots disent
#: si l'on reconnait ces treize sons, pas si l'on est debutant ou avance.
MIN_EXERCISE_TYPES_FOR_PLACEMENT = 2


class PreferencesIn(BaseModel):
    """Tous les champs sont facultatifs : la configuration se remplit par etapes."""

    motivations: list[LearningMotivation] | None = None
    interests: list[CulturalCategoryCode] | None = None
    daily_minutes: int | None = None
    notifications: dict[str, bool] | None = None
    placement_test_accepted: bool | None = None
    completed: bool = False


def _empty(user_id: uuid.UUID) -> dict:
    return {
        "motivations": [],
        "interests": [],
        "daily_minutes": None,
        "notifications": {key: False for key in NOTIFICATION_KEYS},
        "placement_test_offered": False,
        "placement_test_accepted": None,
        "completed_at": None,
    }


async def _read(db: AsyncSession, user_id: uuid.UUID) -> dict:
    row = (
        await db.execute(
            text(
                """
                SELECT motivations, interests, daily_minutes, notifications,
                       placement_test_offered, placement_test_accepted, completed_at
                FROM iam.learner_preferences WHERE user_id = :uid
                """
            ),
            {"uid": user_id},
        )
    ).one_or_none()
    if row is None:
        return _empty(user_id)
    data = dict(row._mapping)
    data["notifications"] = {
        key: bool(data["notifications"].get(key, False)) for key in NOTIFICATION_KEYS
    }
    return data


async def placement_availability(db: AsyncSession, language_id: uuid.UUID | None) -> dict:
    """Le corpus publie permet-il un test de positionnement honnete ?

    On compte les exercices reellement publies pour la langue. Un test bati sur
    moins que cela donnerait un resultat que rien ne soutient.
    """
    conditions = ["status = 'PUBLISHED'"]
    params: dict = {}
    if language_id is not None:
        conditions.append("language_id = :lang")
        params["lang"] = language_id

    row = (
        await db.execute(
            text(
                f"""
                SELECT count(*) AS total, count(DISTINCT type) AS types
                FROM learn.exercises WHERE {' AND '.join(conditions)}
                """
            ),
            params,
        )
    ).one()

    assez_de_questions = row.total >= MIN_QUESTIONS_FOR_PLACEMENT
    assez_varie = row.types >= MIN_EXERCISE_TYPES_FOR_PLACEMENT

    if assez_de_questions and assez_varie:
        explication = "Un court test tiré du corpus publié peut situer votre point de départ."
    elif not assez_de_questions:
        explication = (
            "Le corpus publié ne permet pas encore de situer un niveau : il n'y a "
            "pas assez de questions."
        )
    else:
        explication = (
            "Le corpus publié ne comporte qu'un seul type d'exercice. Un test bâti "
            "dessus mesurerait une seule compétence, pas un niveau."
        )

    return {
        "disponible": assez_de_questions and assez_varie,
        "exercices_publies": row.total,
        "types_publies": row.types,
        "minimum_requis": MIN_QUESTIONS_FOR_PLACEMENT,
        "types_requis": MIN_EXERCISE_TYPES_FOR_PLACEMENT,
        "explication": explication,
    }


@router.get("")
async def read_preferences(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_session)
) -> dict:
    """Les reponses de configuration, et ce que chaque etape peut proposer."""
    return {
        "preferences": await _read(db, user.id),
        "choix": {
            "motivations": [m.value for m in LearningMotivation],
            "interets": [c.value for c in CulturalCategoryCode],
            "minutes": sorted(MINUTES_TO_XP),
            "notifications": list(NOTIFICATION_KEYS),
        },
        "daily_goal_xp": user.daily_goal_xp,
    }


@router.get("/placement")
async def placement(
    language_id: uuid.UUID | None = None,
    _: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    return await placement_availability(db, language_id)


@router.put("")
async def save_preferences(
    payload: PreferencesIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Enregistre une etape de la configuration.

    Choisir un temps quotidien met a jour l'objectif en XP du profil : les deux
    ne doivent pas raconter deux choses differentes.
    """
    if payload.daily_minutes is not None and payload.daily_minutes not in MINUTES_TO_XP:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Durees proposees : {', '.join(str(m) for m in sorted(MINUTES_TO_XP))} minutes.",
        )
    if payload.notifications is not None:
        inconnues = set(payload.notifications) - set(NOTIFICATION_KEYS)
        if inconnues:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Reglage inconnu : {', '.join(sorted(inconnues))}.",
            )

    current = await _read(db, user.id)
    merged = {
        "motivations": (
            [m.value for m in payload.motivations]
            if payload.motivations is not None
            else current["motivations"]
        ),
        "interests": (
            [c.value for c in payload.interests]
            if payload.interests is not None
            else current["interests"]
        ),
        "daily_minutes": payload.daily_minutes or current["daily_minutes"],
        "notifications": (
            {**current["notifications"], **payload.notifications}
            if payload.notifications is not None
            else current["notifications"]
        ),
        "placement_accepted": (
            payload.placement_test_accepted
            if payload.placement_test_accepted is not None
            else current["placement_test_accepted"]
        ),
    }

    await db.execute(
        text(
            """
            INSERT INTO iam.learner_preferences
                (id, user_id, motivations, interests, daily_minutes, notifications,
                 placement_test_offered, placement_test_accepted, completed_at)
            VALUES (:id, :uid, :motivations, :interests, :minutes,
                    CAST(:notifications AS jsonb), :offered, :accepted, :completed)
            ON CONFLICT (user_id) DO UPDATE SET
                motivations = EXCLUDED.motivations,
                interests = EXCLUDED.interests,
                daily_minutes = EXCLUDED.daily_minutes,
                notifications = EXCLUDED.notifications,
                placement_test_offered = iam.learner_preferences.placement_test_offered
                                         OR EXCLUDED.placement_test_offered,
                placement_test_accepted = EXCLUDED.placement_test_accepted,
                completed_at = COALESCE(EXCLUDED.completed_at,
                                        iam.learner_preferences.completed_at)
            """
        ),
        {
            "id": uuid.uuid4(),
            "uid": user.id,
            "motivations": merged["motivations"],
            "interests": merged["interests"],
            "minutes": merged["daily_minutes"],
            "notifications": json.dumps(merged["notifications"]),
            "offered": payload.placement_test_accepted is not None,
            "accepted": merged["placement_accepted"],
            "completed": datetime.now(UTC) if payload.completed else None,
        },
    )

    if payload.daily_minutes is not None:
        user.daily_goal_xp = MINUTES_TO_XP[payload.daily_minutes]

    return {
        "preferences": await _read(db, user.id),
        "daily_goal_xp": user.daily_goal_xp,
    }


@router.get("/summary")
async def summary(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_session)
) -> dict:
    """Recapitulatif de fin de configuration (lot 3, ecran 9).

    Il n'affiche que ce qui a reellement ete choisi : une ligne vide reste vide
    plutot que de montrer une valeur par defaut presentee comme un choix.
    """
    preferences = await _read(db, user.id)
    interets = preferences["interests"]

    rubriques: list[str] = []
    if interets:
        rows = await db.execute(
            text(
                """
                SELECT name_fr FROM culture.cultural_categories
                WHERE code::text = ANY(:codes) AND is_active
                ORDER BY position
                """
            ),
            {"codes": interets},
        )
        rubriques = [r.name_fr for r in rows]

    return {
        "nom": user.display_name,
        "motivations": preferences["motivations"],
        "interets": rubriques,
        "minutes": preferences["daily_minutes"],
        "daily_goal_xp": user.daily_goal_xp,
        "notifications_actives": [
            key for key, active in preferences["notifications"].items() if active
        ],
        "test_de_positionnement": preferences["placement_test_accepted"],
        "termine": preferences["completed_at"] is not None,
    }
