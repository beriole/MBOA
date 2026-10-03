"""Schema `iam` : comptes, roles, sessions."""

import uuid
from datetime import datetime

from sqlalchemy import (
    ARRAY,
    Boolean,
    DateTime,
    Enum as SAEnum,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, Timestamped, UUIDPrimaryKey
from app.shared.enums import UserRole


class User(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "users"
    __table_args__ = {"schema": "iam"}

    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    display_name: Mapped[str] = mapped_column(String(120), nullable=False)

    #: Le role LEARNER est impose a l'inscription (cf. cahier des charges, tableau des acteurs).
    role: Mapped[UserRole] = mapped_column(
        SAEnum(UserRole, name="user_role", schema="shared", create_type=False),
        default=UserRole.LEARNER,
        server_default="LEARNER",
        nullable=False,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False
    )

    #: Langue de l'interface (fr / en), distincte de la langue apprise.
    locale: Mapped[str] = mapped_column(
        String(8), default="fr", server_default="fr", nullable=False
    )
    timezone: Mapped[str] = mapped_column(
        String(64), default="Africa/Douala", server_default="Africa/Douala", nullable=False
    )
    daily_goal_xp: Mapped[int] = mapped_column(
        default=20, server_default="20", nullable=False
    )

    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class RefreshToken(UUIDPrimaryKey, Timestamped, Base):
    """Refresh token rotatif : chaque usage revoque le precedent."""

    __tablename__ = "refresh_tokens"
    __table_args__ = {"schema": "iam"}

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    token_hash: Mapped[str] = mapped_column(String(128), unique=True, nullable=False, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    replaced_by: Mapped[uuid.UUID | None] = mapped_column(PGUUID(as_uuid=True), nullable=True)


class LearnerPreferences(UUIDPrimaryKey, Timestamped, Base):
    """Ce que la personne declare a la configuration initiale (lot 3).

    Ces reponses orientent ce qu'on lui propose ; elles ne verrouillent rien et
    se modifient depuis le profil. Deux precautions :

      - les **notifications** enregistrent un consentement, elles ne declenchent
        rien : aucun envoi n'est branche, et l'ecran le dit ;
      - le **test de positionnement** n'est pas un examen. On note qu'il a ete
        propose et ce que la personne a repondu, pas un niveau qu'on lui
        attribuerait.
    """

    __tablename__ = "learner_preferences"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_learner_preferences_user_id"),
        {"schema": "iam"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )

    #: Codes de `LearningMotivation`.
    motivations: Mapped[list[str]] = mapped_column(
        ARRAY(Text), default=list, server_default="{}", nullable=False
    )
    #: Codes de rubriques du Culture Hub (`CulturalCategoryCode`).
    interests: Mapped[list[str]] = mapped_column(
        ARRAY(Text), default=list, server_default="{}", nullable=False
    )
    #: Minutes annoncees par jour. L'objectif en XP du profil en decoule.
    daily_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)

    #: {"reminders": bool, "new_content": bool, "tips": bool, "offers": bool}
    notifications: Mapped[dict] = mapped_column(
        JSONB, default=dict, server_default="{}", nullable=False
    )

    #: Le test a-t-il ete propose, et accepte ?
    placement_test_offered: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False
    )
    placement_test_accepted: Mapped[bool | None] = mapped_column(Boolean, nullable=True)

    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
