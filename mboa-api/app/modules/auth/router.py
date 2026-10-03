"""Inscription, connexion, rafraichissement de session."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.deps import get_current_user
from app.core.security import (
    create_access_token,
    hash_password,
    hash_refresh_token,
    new_refresh_token,
    verify_password,
)
from app.modules.iam.models import RefreshToken, User
from app.shared.enums import UserRole

router = APIRouter(prefix="/auth", tags=["auth"])


class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=1, max_length=120)
    locale: str = Field(default="fr", max_length=8)
    daily_goal_xp: int = Field(default=20, ge=10, le=50)


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class RefreshIn(BaseModel):
    refresh_token: str


class TokenOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    id: uuid.UUID
    email: EmailStr
    display_name: str
    role: UserRole
    locale: str
    daily_goal_xp: int
    timezone: str


class ProfileEdit(BaseModel):
    """Modification du profil (SS15). Tous les champs sont facultatifs.

    L'e-mail et le role n'y figurent pas : le premier identifie le compte,
    le second ne se choisit pas soi-meme.
    """

    display_name: str | None = Field(default=None, min_length=1, max_length=120)
    locale: str | None = Field(default=None, pattern="^(fr|en)$")
    daily_goal_xp: int | None = Field(default=None, ge=10, le=50)
    timezone: str | None = Field(default=None, max_length=64)


class PasswordChange(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)


async def _issue_tokens(db: AsyncSession, user: User) -> TokenOut:
    raw, digest, expires = new_refresh_token()
    db.add(RefreshToken(user_id=user.id, token_hash=digest, expires_at=expires))
    await db.flush()
    return TokenOut(
        access_token=create_access_token(user.id, user.role.value),
        refresh_token=raw,
    )


@router.post("/register", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterIn, db: AsyncSession = Depends(get_session)) -> TokenOut:
    """Inscription. Le role LEARNER est impose : il n'est pas choisi par l'utilisateur."""
    existing = (
        await db.execute(select(User).where(User.email == payload.email.lower()))
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Cet e-mail est deja utilise."
        )

    user = User(
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        display_name=payload.display_name,
        role=UserRole.LEARNER,
        locale=payload.locale,
        daily_goal_xp=payload.daily_goal_xp,
    )
    db.add(user)
    await db.flush()
    return await _issue_tokens(db, user)


@router.post("/login", response_model=TokenOut)
async def login(payload: LoginIn, db: AsyncSession = Depends(get_session)) -> TokenOut:
    user = (
        await db.execute(select(User).where(User.email == payload.email.lower()))
    ).scalar_one_or_none()
    if user is None or not verify_password(payload.password, user.password_hash):
        # Message identique dans les deux cas : on ne revele pas l'existence du compte.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Identifiants invalides."
        )
    user.last_login_at = datetime.now(UTC)
    return await _issue_tokens(db, user)


@router.post("/refresh", response_model=TokenOut)
async def refresh(payload: RefreshIn, db: AsyncSession = Depends(get_session)) -> TokenOut:
    """Rotation du refresh token : l'ancien est revoque a chaque usage."""
    digest = hash_refresh_token(payload.refresh_token)
    token = (
        await db.execute(select(RefreshToken).where(RefreshToken.token_hash == digest))
    ).scalar_one_or_none()

    if token is None or token.revoked_at is not None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Jeton de rafraichissement invalide."
        )
    if token.expires_at < datetime.now(UTC):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Jeton de rafraichissement expire."
        )

    user = (await db.execute(select(User).where(User.id == token.user_id))).scalar_one()
    token.revoked_at = datetime.now(UTC)
    tokens = await _issue_tokens(db, user)
    return tokens


@router.get("/me", response_model=UserOut)
async def me(user: User = Depends(get_current_user)) -> User:
    return user


@router.patch("/me", response_model=UserOut)
async def update_profile(
    payload: ProfileEdit,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> User:
    """Modifie son propre profil.

    Le nom affiche est recopie sur la fiche de contributeur quand elle
    existe : les deux identites doivent rester celles d'une meme personne,
    sinon le journal de validation devient illisible. Les attestations deja
    delivrees, elles, gardent le nom sous lequel elles ont ete emises.
    """
    changes = payload.model_dump(exclude_none=True)
    if not changes:
        return user

    for field, value in changes.items():
        setattr(user, field, value)

    if "display_name" in changes:
        await db.execute(
            text(
                """
                UPDATE prov.contributors SET display_name = :name
                WHERE user_id = :uid
                """
            ),
            {"name": changes["display_name"], "uid": user.id},
        )
    return user


@router.post("/me/password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
    payload: PasswordChange,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> None:
    """Change son mot de passe.

    Le mot de passe actuel est exige : un telephone laisse deverrouille ne
    doit pas suffire a verrouiller le compte de quelqu'un d'autre. Toutes
    les autres sessions sont ensuite revoquees.
    """
    if not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Le mot de passe actuel est incorrect.",
        )
    if payload.new_password == payload.current_password:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Le nouveau mot de passe doit etre different de l'ancien.",
        )

    user.password_hash = hash_password(payload.new_password)
    await db.execute(
        text(
            """
            UPDATE iam.refresh_tokens SET revoked_at = now()
            WHERE user_id = :uid AND revoked_at IS NULL
            """
        ),
        {"uid": user.id},
    )
