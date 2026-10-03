"""Controle d'acces de l'espace contributeur (SS5).

Deux verifications distinctes :

1. le ROLE : seuls un specialiste culturel ou un administrateur entrent ici ;
2. l'HABILITATION : un specialiste ne peut agir que sur les langues pour
   lesquelles une ligne active existe dans `prov.validation_assignments`.

La base applique de toute facon la seconde regle au moment de la validation
(trigger `trg_status_guard`). On la verifie ici en amont pour renvoyer un
message clair plutot qu'une erreur SQL.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass

from fastapi import Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.deps import get_current_user
from app.modules.iam.models import User
from app.shared.enums import UserRole

CMS_ROLES = (UserRole.CULTURAL_SPECIALIST, UserRole.ADMIN)


@dataclass(frozen=True)
class Contributor:
    """Le contributeur lie au compte connecte, et ses habilitations."""

    id: uuid.UUID
    display_name: str
    language_ids: frozenset[uuid.UUID]
    is_admin: bool

    def may_work_on(self, language_id: uuid.UUID) -> bool:
        return self.is_admin or language_id in self.language_ids


async def get_contributor(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> Contributor:
    if user.role not in CMS_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cet espace est reserve aux specialistes culturels.",
        )

    row = (
        await db.execute(
            text("SELECT id, display_name FROM prov.contributors WHERE user_id = :uid"),
            {"uid": user.id},
        )
    ).one_or_none()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Aucune fiche de contributeur n'est rattachee a ce compte. "
                "Un administrateur doit la creer avant toute contribution."
            ),
        )

    languages = (
        await db.execute(
            text(
                """
                SELECT language_id FROM prov.validation_assignments
                WHERE contributor_id = :cid AND is_active
                """
            ),
            {"cid": row.id},
        )
    ).scalars()

    return Contributor(
        id=row.id,
        display_name=row.display_name,
        language_ids=frozenset(languages),
        is_admin=user.role is UserRole.ADMIN,
    )


def ensure_language_allowed(contributor: Contributor, language_id: uuid.UUID) -> None:
    if not contributor.may_work_on(language_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous n'etes pas habilite pour cette langue.",
        )
