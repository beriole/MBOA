"""Dependances FastAPI communes : session, utilisateur courant, controle de role."""

from __future__ import annotations

import uuid
from collections.abc import Callable

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.security import decode_access_token
from app.modules.iam.models import User
from app.shared.enums import UserRole

CREDENTIALS_ERROR = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Authentification requise.",
    headers={"WWW-Authenticate": "Bearer"},
)


async def get_current_user(
    authorization: str | None = Header(default=None),
    db: AsyncSession = Depends(get_session),
) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise CREDENTIALS_ERROR

    token = authorization.split(" ", 1)[1].strip()
    try:
        payload = decode_access_token(token)
        user_id = uuid.UUID(payload["sub"])
    except (ValueError, KeyError) as exc:
        raise CREDENTIALS_ERROR from exc

    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if user is None or not user.is_active:
        raise CREDENTIALS_ERROR
    return user


def require_roles(*roles: UserRole) -> Callable:
    async def _guard(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Votre role ne permet pas cette action.",
            )
        return user

    return _guard
