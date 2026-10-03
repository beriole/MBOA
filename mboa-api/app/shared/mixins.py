"""Colonnes communes a tout contenu soumis au circuit de provenance et de validation.

Toute table qui herite de ProvenanceMixin est soumise aux regles du SS2 / SS4 / SS5 :
  - pas de passage a VALIDATED sans source ;
  - pas de passage a PUBLISHED sans passer par VALIDATED ;
  - le validateur ne peut pas etre le redacteur.
Ces regles sont appliquees par des triggers PostgreSQL (migration 0002), donc
inviolables meme si du code applicatif les oublie.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum as SAEnum, ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.enums import ContentStatus


class ProvenanceMixin:
    status: Mapped[ContentStatus] = mapped_column(
        SAEnum(ContentStatus, name="content_status", schema="shared", create_type=False),
        default=ContentStatus.DRAFT,
        server_default="DRAFT",
        nullable=False,
        index=True,
    )
    source_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("prov.sources.id", ondelete="RESTRICT"), nullable=True
    )
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("prov.contributors.id", ondelete="SET NULL"), nullable=True
    )
    validated_by: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("prov.contributors.id", ondelete="SET NULL"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
