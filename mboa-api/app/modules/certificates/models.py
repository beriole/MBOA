"""Attestations de parcours (SS15).

Une attestation MBOA dit ce qui a reellement ete fait : des lecons terminees,
un score, des dates. Elle ne dit pas un niveau de langue. MBOA ne fait passer
aucun examen oral et n'evalue pas la production orale ; pretendre certifier un
niveau serait du meme ordre que d'inventer un mot.

Trois proprietes structurent la table :

1. les libelles sont FIGES a l'emission (`learner_name`, `course_title`...).
   Si le cours est renomme ou le compte supprime, l'attestation reste lisible
   et verifiable telle qu'elle a ete delivree ;
2. le `code` est public et sert a la verification par un tiers ;
3. une attestation ne s'efface pas : elle se revoque, avec un motif.

La condition d'emission - toutes les lecons du perimetre terminees - est
verifiee par un trigger, pas seulement par l'API : une attestation ne peut pas
naitre d'un INSERT direct.
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, Timestamped, UUIDPrimaryKey


class Certificate(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "certificates"
    __table_args__ = (
        # Une seule attestation en cours par personne et par perimetre.
        UniqueConstraint("user_id", "section_id", name="uq_certificates_user_section"),
        CheckConstraint(
            "average_score >= 0 AND average_score <= 1", name="score_between_0_and_1"
        ),
        CheckConstraint("lessons_completed > 0", name="lessons_completed_positive"),
        Index("ix_certificates_user", "user_id"),
        {"schema": "progress"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    section_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("learn.sections.id", ondelete="RESTRICT"), nullable=False
    )

    #: Code public, lisible a voix haute : MBOA-BAS-2026-7F3K2Q.
    code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False, index=True)

    # --- libelles figes a l'emission ------------------------------------
    learner_name: Mapped[str] = mapped_column(Text, nullable=False)
    course_title: Mapped[str] = mapped_column(Text, nullable=False)
    section_title: Mapped[str] = mapped_column(Text, nullable=False)
    language_name: Mapped[str] = mapped_column(Text, nullable=False)
    language_iso: Mapped[str] = mapped_column(String(8), nullable=False)
    level: Mapped[str] = mapped_column(String(32), nullable=False)

    # --- ce qui est atteste ---------------------------------------------
    lessons_completed: Mapped[int] = mapped_column(Integer, nullable=False)
    lessons_total: Mapped[int] = mapped_column(Integer, nullable=False)
    #: Moyenne des meilleurs scores, dans [0, 1].
    average_score: Mapped[float] = mapped_column(Float, nullable=False)
    exercises_answered: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    #: Date de la premiere lecon terminee du perimetre.
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    issued_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default="now()"
    )

    # --- revocation ------------------------------------------------------
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
