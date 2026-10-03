"""Schema `ref` : referentiel des langues et de la geographie.

L'architecture est generique : ajouter une langue est une insertion de donnees,
jamais une modification de code (exigence SS1 du cahier des charges).
"""

import uuid

from sqlalchemy import Boolean, ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base, Timestamped, UUIDPrimaryKey


class Language(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "languages"
    __table_args__ = {"schema": "ref"}

    iso639_3: Mapped[str] = mapped_column(String(3), unique=True, nullable=False, index=True)
    glottocode: Mapped[str | None] = mapped_column(String(16), nullable=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    autonym: Mapped[str | None] = mapped_column(String(120), nullable=True)
    guthrie_code: Mapped[str | None] = mapped_column(String(16), nullable=True)
    family: Mapped[str | None] = mapped_column(Text, nullable=True)
    #: Nombre de tons contrastifs documente. NULL tant qu'aucune source ne le confirme.
    tone_count: Mapped[int | None] = mapped_column(nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False
    )

    variants: Mapped[list["LanguageVariant"]] = relationship(
        back_populates="language", cascade="all, delete-orphan"
    )


class LanguageVariant(UUIDPrimaryKey, Timestamped, Base):
    """Variante dialectale et norme orthographique retenue."""

    __tablename__ = "language_variants"
    __table_args__ = (
        UniqueConstraint("language_id", "code", name="uq_language_variants_code"),
        {"schema": "ref"},
    )

    language_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="CASCADE"), nullable=False
    )
    code: Mapped[str] = mapped_column(String(32), nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    region_label: Mapped[str | None] = mapped_column(Text, nullable=True)
    #: Norme orthographique appliquee (ex. "AGLC", "Njock 2019").
    orthography: Mapped[str | None] = mapped_column(String(120), nullable=True)
    is_default: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False
    )

    language: Mapped[Language] = relationship(back_populates="variants")


class Region(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "regions"
    __table_args__ = {"schema": "ref"}

    code: Mapped[str] = mapped_column(String(16), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)


class CulturalArea(UUIDPrimaryKey, Timestamped, Base):
    """Les grandes aires culturelles du Cameroun."""

    __tablename__ = "cultural_areas"
    __table_args__ = {"schema": "ref"}

    code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)


class Community(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "communities"
    __table_args__ = {"schema": "ref"}

    name: Mapped[str] = mapped_column(String(120), nullable=False)
    cultural_area_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.cultural_areas.id", ondelete="SET NULL"), nullable=True
    )
    language_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="SET NULL"), nullable=True
    )
