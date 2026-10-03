"""Schema `learn` : structure pedagogique publiee (SS8, SS37).

L'application mobile ne contient AUCUN cours code en dur (SS42) : tout est servi
depuis ces tables. Ajouter une langue ou une unite est une insertion de donnees.
"""

import uuid

from sqlalchemy import (
    ARRAY,
    Boolean,
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
from app.shared.enums import CourseLevel, ExerciseType, LessonBlockKind, LessonKind
from app.shared.mixins import ProvenanceMixin


class Course(UUIDPrimaryKey, Timestamped, ProvenanceMixin, Base):
    __tablename__ = "courses"
    __table_args__ = {"schema": "learn"}

    language_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="RESTRICT"), nullable=False
    )
    variant_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("ref.language_variants.id", ondelete="SET NULL"),
        nullable=True,
    )
    level: Mapped[CourseLevel] = mapped_column(
        SAEnum(CourseLevel, name="course_level", schema="shared", create_type=False), nullable=False
    )
    title_fr: Mapped[str] = mapped_column(Text, nullable=False)
    description_fr: Mapped[str | None] = mapped_column(Text, nullable=True)
    position: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )

    sections: Mapped[list["Section"]] = relationship(
        back_populates="course", cascade="all, delete-orphan", order_by="Section.position"
    )


class Section(UUIDPrimaryKey, Timestamped, ProvenanceMixin, Base):
    __tablename__ = "sections"
    __table_args__ = (
        UniqueConstraint("course_id", "position", name="uq_sections_position"),
        {"schema": "learn"},
    )

    course_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("learn.courses.id", ondelete="CASCADE"), nullable=False
    )
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    title_fr: Mapped[str] = mapped_column(Text, nullable=False)
    objective_fr: Mapped[str | None] = mapped_column(Text, nullable=True)

    course: Mapped[Course] = relationship(back_populates="sections")
    units: Mapped[list["Unit"]] = relationship(
        back_populates="section", cascade="all, delete-orphan", order_by="Unit.position"
    )


class Unit(UUIDPrimaryKey, Timestamped, ProvenanceMixin, Base):
    """Une unite = un objectif communicatif + ses slots de contenu (livrable D3)."""

    __tablename__ = "units"
    __table_args__ = (
        UniqueConstraint("section_id", "position", name="uq_units_position"),
        {"schema": "learn"},
    )

    section_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("learn.sections.id", ondelete="CASCADE"), nullable=False
    )
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    title_fr: Mapped[str] = mapped_column(Text, nullable=False)
    #: Formule "A la fin de cette unite, je peux ...".
    objective_fr: Mapped[str] = mapped_column(Text, nullable=False)

    target_vocab_ids: Mapped[list[uuid.UUID]] = mapped_column(
        ARRAY(PGUUID(as_uuid=True)), default=list, server_default="{}", nullable=False
    )
    target_sentence_ids: Mapped[list[uuid.UUID]] = mapped_column(
        ARRAY(PGUUID(as_uuid=True)), default=list, server_default="{}", nullable=False
    )
    grammar_rule_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("corpus.grammar_rules.id", ondelete="SET NULL"), nullable=True
    )

    section: Mapped[Section] = relationship(back_populates="units")
    lessons: Mapped[list["Lesson"]] = relationship(
        back_populates="unit", cascade="all, delete-orphan", order_by="Lesson.position"
    )


class Lesson(UUIDPrimaryKey, Timestamped, ProvenanceMixin, Base):
    __tablename__ = "lessons"
    __table_args__ = (
        UniqueConstraint("unit_id", "position", name="uq_lessons_position"),
        {"schema": "learn"},
    )

    unit_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("learn.units.id", ondelete="CASCADE"), nullable=False
    )
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    kind: Mapped[LessonKind] = mapped_column(
        SAEnum(LessonKind, name="lesson_kind", schema="shared", create_type=False),
        default=LessonKind.LESSON,
        server_default="LESSON",
        nullable=False,
    )
    title_fr: Mapped[str] = mapped_column(Text, nullable=False)
    #: Cible imposee par le SS11 : une session tient en 3 a 7 minutes.
    estimated_minutes: Mapped[int] = mapped_column(
        Integer, default=5, server_default="5", nullable=False
    )
    xp_reward: Mapped[int] = mapped_column(
        Integer, default=10, server_default="10", nullable=False
    )

    unit: Mapped[Unit] = relationship(back_populates="lessons")
    blocks: Mapped[list["LessonBlock"]] = relationship(
        back_populates="lesson", cascade="all, delete-orphan", order_by="LessonBlock.position"
    )


class LessonBlock(UUIDPrimaryKey, Timestamped, Base):
    """INTRO / TEACH / PRACTICE / CULTURE_CARD / RECAP (livrable D4)."""

    __tablename__ = "lesson_blocks"
    __table_args__ = {"schema": "learn"}

    lesson_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("learn.lessons.id", ondelete="CASCADE"), nullable=False
    )
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    kind: Mapped[LessonBlockKind] = mapped_column(
        SAEnum(LessonBlockKind, name="lesson_block_kind", schema="shared", create_type=False),
        nullable=False,
    )
    payload: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    exercise_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("learn.exercises.id", ondelete="SET NULL"), nullable=True
    )

    lesson: Mapped[Lesson] = relationship(back_populates="blocks")


class Exercise(UUIDPrimaryKey, Timestamped, ProvenanceMixin, Base):
    """Exercice genere a partir du corpus valide (SS13).

    `generated_from` trace les objets sources. Un trigger interdit de referencer
    un item qui ne serait pas VALIDATED ou PUBLISHED : une mauvaise reponse ne
    peut donc jamais enseigner une forme inventee.
    """

    __tablename__ = "exercises"
    __table_args__ = (
        Index("ix_exercises_language_status", "language_id", "status"),
        {"schema": "learn"},
    )

    language_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="RESTRICT"), nullable=False
    )
    type: Mapped[ExerciseType] = mapped_column(
        SAEnum(ExerciseType, name="exercise_type", schema="shared", create_type=False),
        nullable=False,
    )
    schema_version: Mapped[int] = mapped_column(
        Integer, default=1, server_default="1", nullable=False
    )
    #: Contenu presente a l'apprenant. Ne contient JAMAIS la reponse.
    payload: Mapped[dict] = mapped_column(JSONB, nullable=False)
    #: Specification de correction, jamais envoyee au client.
    answer_spec: Mapped[dict] = mapped_column(JSONB, nullable=False)
    #: [{"type": "VOCAB", "id": "..."}] : tracabilite vers le corpus.
    generated_from: Mapped[list] = mapped_column(
        JSONB, default=list, server_default="[]", nullable=False
    )
    generator_version: Mapped[str] = mapped_column(
        String(32), default="1.0", server_default="1.0", nullable=False
    )
    difficulty: Mapped[int] = mapped_column(
        Integer, default=1, server_default="1", nullable=False
    )
    #: Explication courte affichee apres une erreur (SS17), <= 140 caracteres.
    explanation_fr: Mapped[str | None] = mapped_column(String(140), nullable=True)


class ContentRelease(UUIDPrimaryKey, Timestamped, Base):
    """Version publiee du contenu d'une langue, utilisee par le mode hors-ligne."""

    __tablename__ = "content_releases"
    __table_args__ = {"schema": "learn"}

    language_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="CASCADE"), nullable=False
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    manifest: Mapped[dict] = mapped_column(JSONB, nullable=False)
    is_current: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False
    )
