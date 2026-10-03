"""Schema `prov` : registre de provenance (SS4) et validation humaine (SS5).

C'est le coeur de l'integrite de MBOA : aucune donnee linguistique ou culturelle
ne peut etre publiee sans etre rattachee a une source identifiee et sans avoir
ete acceptee par un validateur habilite pour la langue concernee.
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    ARRAY,
    Boolean,
    DateTime,
    Enum as SAEnum,
    ForeignKey,
    Index,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base, Timestamped, UUIDPrimaryKey
from app.shared.enums import SourceKind, SourceLicense, ValidationDecision


class Source(UUIDPrimaryKey, Timestamped, Base):
    """Une ressource externe ou interne dont provient une donnee."""

    __tablename__ = "sources"
    __table_args__ = {"schema": "prov"}

    kind: Mapped[SourceKind] = mapped_column(
        SAEnum(SourceKind, name="source_kind", schema="shared", create_type=False), nullable=False
    )
    title: Mapped[str] = mapped_column(Text, nullable=False)
    authors: Mapped[list[str]] = mapped_column(
        ARRAY(Text), default=list, server_default="{}", nullable=False
    )
    year: Mapped[int | None] = mapped_column(nullable=True)
    publisher: Mapped[str | None] = mapped_column(Text, nullable=True)
    isbn_issn: Mapped[str | None] = mapped_column(String(64), nullable=True)
    url: Mapped[str | None] = mapped_column(Text, nullable=True)

    license: Mapped[SourceLicense] = mapped_column(
        SAEnum(SourceLicense, name="source_license", schema="shared", create_type=False),
        default=SourceLicense.UNKNOWN,
        server_default="UNKNOWN",
        nullable=False,
    )
    #: Reference du contrat ou du courriel d'autorisation, quand la licence l'exige.
    agreement_ref: Mapped[str | None] = mapped_column(Text, nullable=True)
    agreement_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    #: Usages autorises : LEXICON, GRAMMAR, AUDIO, CULTURE, MT_TRAINING, ASR_TRAINING
    usable_for: Mapped[list[str]] = mapped_column(
        ARRAY(Text), default=list, server_default="{}", nullable=False
    )

    consulted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    documents: Mapped[list["SourceDocument"]] = relationship(
        back_populates="source", cascade="all, delete-orphan"
    )


class SourceDocument(UUIDPrimaryKey, Timestamped, Base):
    """Un fichier ou une page precise appartenant a une source."""

    __tablename__ = "source_documents"
    __table_args__ = {"schema": "prov"}

    source_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("prov.sources.id", ondelete="CASCADE"), nullable=False
    )
    label: Mapped[str] = mapped_column(Text, nullable=False)
    file_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    url: Mapped[str | None] = mapped_column(Text, nullable=True)
    pages: Mapped[str | None] = mapped_column(String(64), nullable=True)
    checksum: Mapped[str | None] = mapped_column(String(128), nullable=True)

    source: Mapped[Source] = relationship(back_populates="documents")


class SourceReference(UUIDPrimaryKey, Timestamped, Base):
    """Lien precis entre un objet du corpus et un endroit d'une source.

    `locator` designe la page, l'entree de dictionnaire, l'URL ou l'horodatage audio.
    `quote_excerpt` est limite a 300 caracteres : il releve de la courte citation,
    jamais de la reproduction d'une ressource protegee.
    """

    __tablename__ = "source_references"
    __table_args__ = (
        Index("ix_source_references_target", "target_type", "target_id"),
        {"schema": "prov"},
    )

    source_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("prov.sources.id", ondelete="CASCADE"), nullable=False
    )
    source_document_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("prov.source_documents.id", ondelete="SET NULL"),
        nullable=True,
    )
    target_type: Mapped[str] = mapped_column(String(64), nullable=False)
    target_id: Mapped[uuid.UUID] = mapped_column(PGUUID(as_uuid=True), nullable=False)
    locator: Mapped[str | None] = mapped_column(Text, nullable=True)
    quote_excerpt: Mapped[str | None] = mapped_column(String(300), nullable=True)
    consulted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Contributor(UUIDPrimaryKey, Timestamped, Base):
    """Personne physique qui saisit, enregistre ou valide du contenu."""

    __tablename__ = "contributors"
    __table_args__ = {"schema": "prov"}

    user_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="SET NULL"), nullable=True
    )
    display_name: Mapped[str] = mapped_column(Text, nullable=False)
    #: LINGUIST, NATIVE_SPEAKER, TEACHER, RECORDIST, EDITOR
    role: Mapped[str] = mapped_column(String(32), nullable=False)
    affiliation: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False
    )


class ValidationAssignment(UUIDPrimaryKey, Timestamped, Base):
    """Habilitation : qui a le droit de valider quoi, pour quelle langue.

    Un validateur ne peut accepter un contenu que si une ligne active existe ici
    pour la langue concernee. Verifie par trigger.
    """

    __tablename__ = "validation_assignments"
    __table_args__ = (
        UniqueConstraint("contributor_id", "language_id", name="uq_assignment_contributor_language"),
        {"schema": "prov"},
    )

    contributor_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("prov.contributors.id", ondelete="CASCADE"), nullable=False
    )
    language_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="CASCADE"), nullable=False
    )
    #: LEXICON, GRAMMAR, AUDIO, CULTURE, EXERCISE
    scope: Mapped[list[str]] = mapped_column(
        ARRAY(Text), default=list, server_default="{}", nullable=False
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False
    )


class ContentValidation(UUIDPrimaryKey, Timestamped, Base):
    """Historique des decisions de validation humaine (SS5)."""

    __tablename__ = "content_validations"
    __table_args__ = (
        Index("ix_content_validations_target", "target_type", "target_id"),
        {"schema": "prov"},
    )

    target_type: Mapped[str] = mapped_column(String(64), nullable=False)
    target_id: Mapped[uuid.UUID] = mapped_column(PGUUID(as_uuid=True), nullable=False)
    validator_contributor_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("prov.contributors.id", ondelete="RESTRICT"), nullable=False
    )
    decision: Mapped[ValidationDecision] = mapped_column(
        SAEnum(ValidationDecision, name="validation_decision", schema="shared", create_type=False),
        nullable=False,
    )
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    corrected_fields: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    decided_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default="now()"
    )
