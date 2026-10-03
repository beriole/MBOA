"""Outils de demonstration, montes UNIQUEMENT quand ENVIRONMENT=local.

Permet de montrer la repetition espacee sans attendre 24 heures.
"""

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.deps import get_current_user
from app.modules.iam.models import User

router = APIRouter(prefix="/dev", tags=["demonstration (local uniquement)"])


@router.post("/advance-day")
async def advance_day(
    db: AsyncSession = Depends(get_session), user: User = Depends(get_current_user)
) -> dict:
    """Avance d'un jour l'horloge de revision de l'utilisateur courant."""
    result = await db.execute(
        text(
            """
            UPDATE progress.review_items
            SET next_review_at = next_review_at - interval '1 day'
            WHERE user_id = :uid
            """
        ),
        {"uid": user.id},
    )
    await db.execute(
        text(
            """
            UPDATE game.streaks
            SET last_activity_date = last_activity_date - 1
            WHERE user_id = :uid AND last_activity_date IS NOT NULL
            """
        ),
        {"uid": user.id},
    )
    return {"items_shifted": result.rowcount}
