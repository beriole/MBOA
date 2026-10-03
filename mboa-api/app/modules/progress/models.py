"""Schemas `progress` et `game` : progression, repetition espacee (SS14), gamification (SS15).

Toutes ces valeurs sont calculees par le serveur. Le client Flutter ne fait que
rejouer des evenements : il n'arbitre jamais un score, un XP ou un deverrouillage
(SS39, derniere ligne).
"""

import uuid
from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Enum as SAEnum,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, Timestamped, UUIDPrimaryKey
from app.shared.enums import MasteryState, ProgressStatus, ReviewTargetType


class LessonSession(UUIDPrimaryKey, Timestamped, Base):
    """Une session de leçon ouverte par POST /lessons/{id}/start."""

    __tablename__ = "lesson_sessions"
    __table_args__ = {"schema": "progress"}

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    lesson_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("learn.lessons.id", ondelete="CASCADE"), nullable=False
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default="now()"
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    score: Mapped[float | None] = mapped_column(Float, nullable=True)
    xp_awarded: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )


class ExerciseAttempt(UUIDPrimaryKey, Timestamped, Base):
    """Append-only : aucune mise a jour, donc aucun conflit lors de la synchronisation."""

    __tablename__ = "exercise_attempts"
    __table_args__ = (
        UniqueConstraint("client_attempt_id", name="uq_exercise_attempts_client_attempt_id"),
        Index("ix_exercise_attempts_user", "user_id", "attempted_at"),
        {"schema": "progress"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    exercise_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("learn.exercises.id", ondelete="CASCADE"), nullable=False
    )
    session_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("progress.lesson_sessions.id", ondelete="SET NULL"),
        nullable=True,
    )
    #: UUID genere par le client : garantit l'idempotence de la synchronisation hors-ligne.
    client_attempt_id: Mapped[uuid.UUID] = mapped_column(PGUUID(as_uuid=True), nullable=False)
    answer: Mapped[dict] = mapped_column(JSONB, nullable=False)
    is_correct: Mapped[bool] = mapped_column(Boolean, nullable=False)
    response_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    attempted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default="now()"
    )
    #: ONLINE ou OFFLINE_SYNC
    origin: Mapped[str] = mapped_column(
        String(16), default="ONLINE", server_default="ONLINE", nullable=False
    )


class LessonProgress(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "lesson_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "lesson_id", name="uq_lesson_progress_user_lesson"),
        {"schema": "progress"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    lesson_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("learn.lessons.id", ondelete="CASCADE"), nullable=False
    )
    status: Mapped[ProgressStatus] = mapped_column(
        SAEnum(ProgressStatus, name="progress_status", schema="shared", create_type=False),
        default=ProgressStatus.AVAILABLE,
        server_default="AVAILABLE",
        nullable=False,
    )
    best_score: Mapped[float] = mapped_column(
        Float, default=0.0, server_default="0", nullable=False
    )
    attempts: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    first_completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    last_completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class ReviewItem(UUIDPrimaryKey, Timestamped, Base):
    """Repetition espacee (SS14). Une erreur ne disparait pas a la fin de la lecon."""

    __tablename__ = "review_items"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "target_type", "target_id", name="uq_review_items_user_target"
        ),
        Index("ix_review_items_due", "user_id", "next_review_at"),
        {"schema": "progress"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    target_type: Mapped[ReviewTargetType] = mapped_column(
        SAEnum(ReviewTargetType, name="review_target_type", schema="shared", create_type=False),
        nullable=False,
    )
    target_id: Mapped[uuid.UUID] = mapped_column(PGUUID(as_uuid=True), nullable=False)

    state: Mapped[MasteryState] = mapped_column(
        SAEnum(MasteryState, name="mastery_state", schema="shared", create_type=False),
        default=MasteryState.NEW,
        server_default="NEW",
        nullable=False,
    )
    times_seen: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    correct_count: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    wrong_count: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    next_review_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    interval_days: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    mastery_score: Mapped[float] = mapped_column(
        Float, default=0.0, server_default="0", nullable=False
    )
    lapses: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )


class XpLedger(UUIDPrimaryKey, Timestamped, Base):
    """Journal append-only des XP. Le total est une somme, jamais un compteur modifiable."""

    __tablename__ = "xp_ledger"
    __table_args__ = (
        Index("ix_xp_ledger_user", "user_id", "created_at"),
        {"schema": "game"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    #: LESSON_COMPLETE, EXERCISE_CORRECT, REVIEW, STREAK_BONUS, CHECKPOINT, ACHIEVEMENT
    reason: Mapped[str] = mapped_column(String(32), nullable=False)
    ref_type: Mapped[str | None] = mapped_column(String(32), nullable=True)
    ref_id: Mapped[uuid.UUID | None] = mapped_column(PGUUID(as_uuid=True), nullable=True)


class Streak(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "streaks"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_streaks_user_id"),
        {"schema": "game"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    current_days: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    longest_days: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    #: Date locale de l'utilisateur, pas UTC.
    last_activity_date: Mapped[date | None] = mapped_column(Date, nullable=True)


class Achievement(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "achievements"
    __table_args__ = {"schema": "game"}

    code: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    title_fr: Mapped[str] = mapped_column(Text, nullable=False)
    description_fr: Mapped[str] = mapped_column(Text, nullable=False)
    rule: Mapped[dict] = mapped_column(JSONB, nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False
    )


class UserAchievement(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "user_achievements"
    __table_args__ = (
        UniqueConstraint("user_id", "achievement_id", name="uq_user_achievements"),
        {"schema": "game"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    achievement_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("game.achievements.id", ondelete="CASCADE"), nullable=False
    )
    earned_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default="now()"
    )
