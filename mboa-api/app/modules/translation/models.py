"""Schema `translate` : demandes de traduction et leur tracabilite (SS41).

Le cahier des charges impose de tracer, pour chaque traduction :
source_language, target_language, model, model_version, confidence,
human_validation. On le fait des la V1, alors meme que le seul « modele » est
une recherche dans le corpus : le jour ou un modele neuronal arrivera, les
reponses passees resteront distinguables des nouvelles.
"""

import uuid

from sqlalchemy import Enum as SAEnum, Float, ForeignKey, Index, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, Timestamped, UUIDPrimaryKey
from app.shared.enums import HumanValidation, TranslationMode


class TranslationRequest(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "translation_requests"
    __table_args__ = (
        Index("ix_translation_requests_user", "user_id", "created_at"),
        {"schema": "translate"},
    )

    user_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="SET NULL"), nullable=True
    )

    #: Langue de depart. NULL cote francais : le francais n'est pas dans `ref.languages`.
    source_language_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="SET NULL"), nullable=True
    )
    target_language_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="SET NULL"), nullable=True
    )
    #: 'fr' ou le code ISO de la langue nationale, pour lire la trace sans jointure.
    source_code: Mapped[str] = mapped_column(String(8), nullable=False)
    target_code: Mapped[str] = mapped_column(String(8), nullable=False)

    input_text: Mapped[str] = mapped_column(Text, nullable=False)

    mode: Mapped[TranslationMode] = mapped_column(
        SAEnum(TranslationMode, name="translation_mode", schema="shared", create_type=False),
        nullable=False,
    )
    model: Mapped[str] = mapped_column(String(64), nullable=False)
    model_version: Mapped[str] = mapped_column(String(32), nullable=False)

    #: Confiance de la meilleure correspondance, dans [0, 1]. NULL si aucune.
    confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    match_count: Mapped[int] = mapped_column(default=0, server_default="0", nullable=False)
    #: Correspondances renvoyees, telles qu'affichees a l'utilisateur.
    matches: Mapped[list] = mapped_column(JSONB, default=list, server_default="[]", nullable=False)

    human_validation: Mapped[HumanValidation] = mapped_column(
        SAEnum(HumanValidation, name="human_validation", schema="shared", create_type=False),
        default=HumanValidation.NONE,
        server_default="NONE",
        nullable=False,
    )
    #: Remarque de l'utilisateur quand il signale une traduction douteuse.
    report_comment: Mapped[str | None] = mapped_column(Text, nullable=True)
