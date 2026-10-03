"""Schema `corpus` : donnees linguistiques, du brut importe jusqu'au valide (SS6).

Regle absolue du projet (SS2) : aucune entree ici n'est inventee. Chaque objet
porte un `source_id` et ne peut atteindre VALIDATED qu'apres acceptation par un
validateur humain habilite. Les triggers de la migration 0002 rendent cette
regle inviolable, y compris depuis psql.
"""

import uuid

from sqlalchemy import (
    ARRAY,
    CheckConstraint,
    Enum as SAEnum,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base, Timestamped, UUIDPrimaryKey
from app.shared.enums import GrammaticalCategory
from app.shared.mixins import ProvenanceMixin


class VocabularyItem(UUIDPrimaryKey, Timestamped, ProvenanceMixin, Base):
    """Une unite lexicale attestee par une source."""

    __tablename__ = "vocabulary_items"
    __table_args__ = (
        UniqueConstraint(
            "language_id",
            "lemma",
            "grammatical_category",
            "meaning_fr",
            name="uq_vocabulary_items_lemma",
        ),
        Index("ix_vocabulary_items_search", "lemma_toneless"),
        Index("ix_vocabulary_items_language_status", "language_id", "status"),
        {"schema": "corpus"},
    )

    language_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="RESTRICT"), nullable=False
    )
    variant_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("ref.language_variants.id", ondelete="SET NULL"),
        nullable=True,
    )

    #: Forme ecrite, normalisee en Unicode NFC (contrainte verifiee en base).
    lemma: Mapped[str] = mapped_column(Text, nullable=False)
    #: Meme forme sans diacritiques tonales : sert a la recherche tolerante.
    lemma_toneless: Mapped[str] = mapped_column(Text, nullable=False)

    grammatical_category: Mapped[GrammaticalCategory] = mapped_column(
        SAEnum(
            GrammaticalCategory, name="grammatical_category", schema="shared", create_type=False
        ),
        nullable=False,
    )
    #: Classes nominales bantoues (Basaa notamment). NULL si non pertinent ou non atteste.
    noun_class_sg: Mapped[int | None] = mapped_column(Integer, nullable=True)
    noun_class_pl: Mapped[int | None] = mapped_column(Integer, nullable=True)

    #: Glose francaise. NULLABLE a dessein : une forme peut etre attestee et
    #: enregistree par un locuteur natif avant que son sens ait ete valide.
    #: Les exercices de traduction exigent une glose ; les exercices audio, non.
    meaning_fr: Mapped[str | None] = mapped_column(Text, nullable=True)
    meaning_en: Mapped[str | None] = mapped_column(Text, nullable=True)

    ipa: Mapped[str | None] = mapped_column(Text, nullable=True)
    #: Schema tonal atteste, ex. "H-B". NULL tant qu'aucune source ne le documente.
    tone_pattern: Mapped[str | None] = mapped_column(String(32), nullable=True)

    primary_audio_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("audio.audio_assets.id", ondelete="SET NULL"), nullable=True
    )
    image_key: Mapped[str | None] = mapped_column(Text, nullable=True)

    difficulty: Mapped[int] = mapped_column(
        Integer, default=1, server_default="1", nullable=False
    )
    tags: Mapped[list[str]] = mapped_column(
        ARRAY(Text), default=list, server_default="{}", nullable=False
    )


class ExampleSentence(UUIDPrimaryKey, Timestamped, ProvenanceMixin, Base):
    """Une phrase attestee, avec sa traduction et sa segmentation validee."""

    __tablename__ = "example_sentences"
    __table_args__ = (
        Index("ix_example_sentences_language_status", "language_id", "status"),
        {"schema": "corpus"},
    )

    language_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="RESTRICT"), nullable=False
    )
    variant_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("ref.language_variants.id", ondelete="SET NULL"),
        nullable=True,
    )

    text: Mapped[str] = mapped_column(Text, nullable=False)
    text_toneless: Mapped[str] = mapped_column(Text, nullable=False)
    translation_fr: Mapped[str | None] = mapped_column(Text, nullable=True)
    translation_en: Mapped[str | None] = mapped_column(Text, nullable=True)

    #: Segmentation en mots, validee par un humain. Utilisee par ORDER_WORDS et FILL_BLANK.
    tokens: Mapped[list | None] = mapped_column(JSONB, nullable=True)

    vocabulary_item_ids: Mapped[list[uuid.UUID]] = mapped_column(
        ARRAY(PGUUID(as_uuid=True)), default=list, server_default="{}", nullable=False
    )
    primary_audio_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("audio.audio_assets.id", ondelete="SET NULL"), nullable=True
    )
    difficulty: Mapped[int] = mapped_column(
        Integer, default=1, server_default="1", nullable=False
    )


class GrammarRule(UUIDPrimaryKey, Timestamped, ProvenanceMixin, Base):
    """Une regle de grammaire redigee par MBOA d'apres une source citee.

    L'explication est redigee avec nos propres mots : le droit d'auteur protege
    l'expression, pas le fait linguistique. La source est citee via SourceReference.
    """

    __tablename__ = "grammar_rules"
    __table_args__ = (
        CheckConstraint("char_length(explanation_fr) <= 600", name="explanation_max_600"),
        {"schema": "corpus"},
    )

    language_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="RESTRICT"), nullable=False
    )
    title_fr: Mapped[str] = mapped_column(Text, nullable=False)
    explanation_fr: Mapped[str] = mapped_column(Text, nullable=False)
    #: PRONOUN, NOUN_CLASS, VERB_TENSE, NEGATION, QUESTION, POSSESSION, LOCATIVE, NUMERAL, OTHER
    category: Mapped[str] = mapped_column(String(32), nullable=False)
    example_sentence_ids: Mapped[list[uuid.UUID]] = mapped_column(
        ARRAY(PGUUID(as_uuid=True)), default=list, server_default="{}", nullable=False
    )
    difficulty: Mapped[int] = mapped_column(Integer, default=1, nullable=False)


class ImportBatch(UUIDPrimaryKey, Timestamped, Base):
    """Un lot d'import : SOURCE EXTERNE -> IMPORT -> RAW -> NORMALISATION (SS43)."""

    __tablename__ = "import_batches"
    __table_args__ = {"schema": "corpus"}

    source_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("prov.sources.id", ondelete="RESTRICT"), nullable=False
    )
    label: Mapped[str] = mapped_column(Text, nullable=False)
    row_count: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    normalizer_version: Mapped[str] = mapped_column(
        String(32), default="1.0", server_default="1.0", nullable=False
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    records: Mapped[list["RawRecord"]] = relationship(
        back_populates="batch", cascade="all, delete-orphan"
    )


class RawRecord(UUIDPrimaryKey, Timestamped, Base):
    """Une ligne brute importee, avant toute transformation pedagogique."""

    __tablename__ = "raw_records"
    __table_args__ = {"schema": "corpus"}

    import_batch_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("corpus.import_batches.id", ondelete="CASCADE"),
        nullable=False,
    )
    row_index: Mapped[int] = mapped_column(Integer, nullable=False)
    raw: Mapped[dict] = mapped_column(JSONB, nullable=False)
    normalized: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    mapped_target_type: Mapped[str | None] = mapped_column(String(64), nullable=True)
    mapped_target_id: Mapped[uuid.UUID | None] = mapped_column(PGUUID(as_uuid=True), nullable=True)
    #: RAW, NORMALIZED, MAPPED, DISCARDED
    state: Mapped[str] = mapped_column(
        String(16), default="RAW", server_default="RAW", nullable=False
    )

    batch: Mapped[ImportBatch] = relationship(back_populates="records")
