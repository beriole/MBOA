"""Schema `audio` : actifs sonores (SS18).

L'audio est essentiel a une application de langue camerounaise. Chaque fichier
porte son locuteur, sa licence et sa source. Aucune synthese vocale generique
n'est utilisee pour representer une langue tonale (SS18, dernier paragraphe).
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
    Integer,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, Timestamped, UUIDPrimaryKey
from app.shared.enums import AudioQuality, SourceLicense


class Speaker(UUIDPrimaryKey, Timestamped, Base):
    """Locuteur. L'application ne recoit jamais que `display_code`, jamais l'identite."""

    __tablename__ = "speakers"
    __table_args__ = {"schema": "audio"}

    contributor_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("prov.contributors.id", ondelete="SET NULL"), nullable=True
    )
    #: Code anonymise expose au client, ex. "BAS-F-03".
    display_code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    language_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="RESTRICT"), nullable=False
    )
    variant_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("ref.language_variants.id", ondelete="SET NULL"),
        nullable=True,
    )
    region_label: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_native: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False
    )
    #: APP_PLAYBACK, ASR_TRAINING, PUBLIC_DATASET
    consent_scope: Mapped[list[str]] = mapped_column(
        ARRAY(Text), default=list, server_default="{}", nullable=False
    )


class RecordingSession(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "recording_sessions"
    __table_args__ = {"schema": "audio"}

    speaker_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("audio.speakers.id", ondelete="CASCADE"), nullable=False
    )
    recorded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    location: Mapped[str | None] = mapped_column(Text, nullable=True)
    device: Mapped[str | None] = mapped_column(Text, nullable=True)
    sample_rate: Mapped[int | None] = mapped_column(Integer, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)


class AudioAsset(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "audio_assets"
    __table_args__ = (
        Index("ix_audio_assets_target", "target_type", "target_id"),
        {"schema": "audio"},
    )

    session_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("audio.recording_sessions.id", ondelete="SET NULL"),
        nullable=True,
    )
    speaker_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("audio.speakers.id", ondelete="SET NULL"), nullable=True
    )
    language_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="RESTRICT"), nullable=False
    )

    #: Cle du fichier servi au client (Opus). En local : chemin relatif sous media/.
    file_key: Mapped[str] = mapped_column(Text, nullable=False)
    duration_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    #: Version ralentie (0.75x) pre-calculee, pour l'etape V2 de la prononciation.
    slow_file_key: Mapped[str | None] = mapped_column(Text, nullable=True)

    #: VOCAB, SENTENCE, DIALOGUE_TURN, LETTER, TONE_EXAMPLE
    target_type: Mapped[str | None] = mapped_column(String(32), nullable=True)
    target_id: Mapped[uuid.UUID | None] = mapped_column(PGUUID(as_uuid=True), nullable=True)

    license: Mapped[SourceLicense] = mapped_column(
        SAEnum(SourceLicense, name="source_license", schema="shared", create_type=False),
        default=SourceLicense.UNKNOWN,
        server_default="UNKNOWN",
        nullable=False,
    )
    source_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("prov.sources.id", ondelete="SET NULL"), nullable=True
    )
    #: Attribution a afficher, exigee par certaines licences (CC BY-SA de Lingua Libre).
    attribution: Mapped[str | None] = mapped_column(Text, nullable=True)

    quality: Mapped[AudioQuality] = mapped_column(
        SAEnum(AudioQuality, name="audio_quality", schema="shared", create_type=False),
        default=AudioQuality.ACCEPTABLE,
        server_default="ACCEPTABLE",
        nullable=False,
    )
