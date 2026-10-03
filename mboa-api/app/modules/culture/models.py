"""Schema `culture` : patrimoine immateriel (SS20, SS38).

Meme exigence que pour la langue : une fiche culturelle porte une source, passe
par une validation humaine, et ne peut pas etre publiee autrement. Les triggers
du schema s'appliquent a `cultural_contents` comme au corpus linguistique.

Le lien avec l'apprentissage (SS21) passe par `cultural_links` : une fiche peut
s'afficher au sein d'une lecon sous la forme d'une carte « Le savais-tu ? ».
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum as SAEnum,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base, Timestamped, UUIDPrimaryKey
from app.shared.enums import CulturalCategoryCode, CulturalLinkPlacement, CulturalMediaKind
from app.shared.mixins import ProvenanceMixin


class CulturalCategory(UUIDPrimaryKey, Timestamped, Base):
    """Les rubriques du Culture Hub, fixees par le cahier des charges (SS20)."""

    __tablename__ = "cultural_categories"
    __table_args__ = {"schema": "culture"}

    code: Mapped[CulturalCategoryCode] = mapped_column(
        SAEnum(
            CulturalCategoryCode,
            name="cultural_category_code",
            schema="shared",
            create_type=False,
        ),
        unique=True,
        nullable=False,
    )
    name_fr: Mapped[str] = mapped_column(String(80), nullable=False)
    description_fr: Mapped[str | None] = mapped_column(Text, nullable=True)
    position: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False
    )


class CulturalContent(UUIDPrimaryKey, Timestamped, ProvenanceMixin, Base):
    """Une fiche du patrimoine : peuple, histoire, conte, danse, tenue...

    `summary_fr` est court a dessein : c'est lui qui s'affiche dans la carte
    « Le savais-tu ? » a la fin d'une lecon.
    """

    __tablename__ = "cultural_contents"
    __table_args__ = (
        Index("ix_cultural_contents_category_status", "category_id", "status"),
        {"schema": "culture"},
    )

    category_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("culture.cultural_categories.id", ondelete="RESTRICT"),
        nullable=False,
    )

    title_fr: Mapped[str] = mapped_column(Text, nullable=False)
    #: <= 280 caracteres : contrainte d'affichage de la carte culturelle.
    summary_fr: Mapped[str] = mapped_column(String(280), nullable=False)
    body_fr: Mapped[str | None] = mapped_column(Text, nullable=True)

    #: Rattachements geographiques et communautaires, tous facultatifs : une
    #: fiche peut concerner une aire entiere comme une seule communaute.
    cultural_area_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.cultural_areas.id", ondelete="SET NULL"), nullable=True
    )
    community_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.communities.id", ondelete="SET NULL"), nullable=True
    )
    region_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.regions.id", ondelete="SET NULL"), nullable=True
    )
    language_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="SET NULL"), nullable=True
    )

    reading_minutes: Mapped[int] = mapped_column(
        Integer, default=2, server_default="2", nullable=False
    )

    media: Mapped[list["CulturalMedia"]] = relationship(
        back_populates="content", cascade="all, delete-orphan"
    )


class CulturalMedia(UUIDPrimaryKey, Timestamped, Base):
    """Image, son ou video accompagnant une fiche, avec son credit et sa licence."""

    __tablename__ = "cultural_media"
    __table_args__ = {"schema": "culture"}

    cultural_content_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("culture.cultural_contents.id", ondelete="CASCADE"),
        nullable=False,
    )
    kind: Mapped[CulturalMediaKind] = mapped_column(
        SAEnum(
            CulturalMediaKind, name="cultural_media_kind", schema="shared", create_type=False
        ),
        nullable=False,
    )
    file_key: Mapped[str] = mapped_column(Text, nullable=False)
    caption: Mapped[str | None] = mapped_column(Text, nullable=True)
    #: Mention obligatoire pour les licences qui l'exigent (CC BY, CC BY-SA).
    credit: Mapped[str | None] = mapped_column(Text, nullable=True)
    license: Mapped[str | None] = mapped_column(String(32), nullable=True)
    position: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)

    content: Mapped[CulturalContent] = relationship(back_populates="media")


class CulturalLink(UUIDPrimaryKey, Timestamped, Base):
    """Rattache une fiche a un objet pedagogique (SS21).

    C'est ce lien qui evite deux menus separes : la culture apparait la ou on
    apprend, au moment ou elle eclaire ce qu'on vient de voir.
    """

    __tablename__ = "cultural_links"
    __table_args__ = (
        UniqueConstraint(
            "cultural_content_id",
            "target_type",
            "target_id",
            name="uq_cultural_links_target",
        ),
        Index("ix_cultural_links_target", "target_type", "target_id"),
        {"schema": "culture"},
    )

    cultural_content_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("culture.cultural_contents.id", ondelete="CASCADE"),
        nullable=False,
    )
    #: UNIT, LESSON, VOCAB, PROVERB, STORY
    target_type: Mapped[str] = mapped_column(String(32), nullable=False)
    target_id: Mapped[uuid.UUID] = mapped_column(PGUUID(as_uuid=True), nullable=False)
    placement: Mapped[CulturalLinkPlacement] = mapped_column(
        SAEnum(
            CulturalLinkPlacement,
            name="cultural_link_placement",
            schema="shared",
            create_type=False,
        ),
        default=CulturalLinkPlacement.DID_YOU_KNOW,
        server_default="DID_YOU_KNOW",
        nullable=False,
    )


class Favorite(UUIDPrimaryKey, Timestamped, Base):
    """Ce qu'une personne met de cote (lot 9, ecran 8).

    Polymorphe : une fiche culturelle ou un enregistrement. On ne stocke pas de
    copie du contenu, seulement une reference : si une fiche est retiree, le
    favori cesse simplement de sortir des listes, sans laisser d'orphelin
    affichable.
    """

    __tablename__ = "favorites"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "target_type", "target_id", name="uq_favorites_user_target"
        ),
        Index("ix_favorites_user", "user_id", "created_at"),
        {"schema": "culture"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    #: CULTURAL_CONTENT ou AUDIO.
    target_type: Mapped[str] = mapped_column(String(32), nullable=False)
    target_id: Mapped[uuid.UUID] = mapped_column(PGUUID(as_uuid=True), nullable=False)


class Comment(UUIDPrimaryKey, Timestamped, Base):
    """Un avis, attache a une fiche, un enregistrement ou un produit.

    Trois choix de structure portent la regle « un avis n'est pas une source » :

    - `author_label` est fige a l'ecriture. Changer de pseudonyme plus tard ne
      doit pas reecrire ce qui a ete dit sous l'ancien.
    - `rating` reste nul pour tout ce qui n'est pas un objet vendu. Une note sur
      un fait de langue n'aurait aucun sens : on ne vote pas sur ce qui est.
    - `hidden_at` masque sans supprimer. L'administration doit pouvoir lire ce
      qui a ete signale pour trancher, et un signalement abusif doit se voir.
    """

    __tablename__ = "comments"
    __table_args__ = (
        CheckConstraint("rating IS NULL OR (rating BETWEEN 1 AND 5)", name="rating_1_to_5"),
        CheckConstraint("length(btrim(body_fr)) >= 2", name="body_not_blank"),
        Index("ix_comments_target", "target_type", "target_id", "created_at"),
        {"schema": "culture"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    #: Le nom affiche au moment ou le commentaire a ete ecrit.
    author_label: Mapped[str] = mapped_column(String(120), nullable=False)

    #: CULTURAL_CONTENT, AUDIO ou PRODUCT.
    target_type: Mapped[str] = mapped_column(String(32), nullable=False)
    target_id: Mapped[uuid.UUID] = mapped_column(PGUUID(as_uuid=True), nullable=False)

    body_fr: Mapped[str] = mapped_column(Text, nullable=False)
    rating: Mapped[int | None] = mapped_column(Integer, nullable=True)

    hidden_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    hidden_reason: Mapped[str | None] = mapped_column(Text, nullable=True)


class CommentReport(UUIDPrimaryKey, Timestamped, Base):
    """Un signalement. Conserve son auteur et son motif, pour les deux sens."""

    __tablename__ = "comment_reports"
    __table_args__ = (
        UniqueConstraint("comment_id", "user_id", name="uq_comment_reports_once"),
        CheckConstraint("length(btrim(reason)) >= 5", name="reason_not_blank"),
        {"schema": "culture"},
    )

    comment_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("culture.comments.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    reason: Mapped[str] = mapped_column(Text, nullable=False)


class MediaLibrary(UUIDPrimaryKey, Timestamped, Base):
    """Photographies et vidéos rapatriées de Wikimedia Commons.

    Le catalogue n'avait aucune image : les fiches culturelles sont du texte, et
    `cultural_media` exige une fiche pour porter un média. Or il existe sur
    Commons des photographies et des vidéos du Cameroun réellement libres, avec
    un auteur nommé et une licence explicite. Les écarter revenait à laisser des
    écrans vides alors que la matière existe.

    Ce que cette table **ne** fait **pas** : affirmer quoi que ce soit sur ce
    qu'on voit. `title` et `description` sont les mots de l'auteur du média,
    recopiés tels quels depuis Commons, et l'écran les présente comme tels. MBOA
    n'ajoute aucune attribution culturelle de son cru — dire d'un masque qu'il
    est bamileke serait une affirmation, et elle n'appartient pas à la
    plateforme.

    `source_url` pointe vers la page Commons : la licence, l'auteur et
    l'historique y restent vérifiables par n'importe qui.
    """

    __tablename__ = "media_library"
    __table_args__ = (
        UniqueConstraint("source_url", name="uq_media_library_source"),
        CheckConstraint("length(btrim(author)) > 0", name="author_not_blank"),
        CheckConstraint("length(btrim(license)) > 0", name="license_not_blank"),
        Index("ix_media_library_theme", "theme"),
        {"schema": "culture"},
    )

    kind: Mapped[CulturalMediaKind] = mapped_column(
        SAEnum(
            CulturalMediaKind, name="cultural_media_kind", schema="shared", create_type=False
        ),
        nullable=False,
    )

    #: Chemin relatif sous `media/`, par exemple `culture/<uuid>.jpg`.
    file_key: Mapped[str] = mapped_column(Text, nullable=False)

    #: Le titre donné par l'auteur sur Commons. Ce ne sont pas les mots de MBOA.
    title: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    #: Obligatoires : sans eux, le média ne peut pas être rediffusé légalement.
    author: Mapped[str] = mapped_column(Text, nullable=False)
    license: Mapped[str] = mapped_column(String(64), nullable=False)
    source_url: Mapped[str] = mapped_column(Text, nullable=False)

    #: Regroupement d'affichage (artisanat, danse, marché, paysage…). C'est une
    #: étiquette de rangement, pas une affirmation sur le contenu.
    theme: Mapped[str] = mapped_column(String(40), nullable=False)

    region_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.regions.id", ondelete="SET NULL"), nullable=True
    )

    width: Mapped[int | None] = mapped_column(Integer, nullable=True)
    height: Mapped[int | None] = mapped_column(Integer, nullable=True)
    duration_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
