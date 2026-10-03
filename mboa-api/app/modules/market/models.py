"""Schema `market` : artisanat, commandes, livraisons (SS45 a SS48).

Trois partis pris structurent ce schema, et chacun repond a une contrainte
reelle du projet plutot qu'a une habitude de place de marche :

1. **L'argent ne passe pas par MBOA.** La plateforme n'a ni entite juridique
   ni compte marchand. Le seul mode de reglement ouvert est donc l'espece
   remise au livreur a la livraison - le mode dominant au Cameroun. Le circuit
   va jusqu'au bout, mais aucun franc ne transite ici : un trigger interdit le
   statut `PAID` et tout autre mode de paiement. Ce que le livreur saisit est
   une DECLARATION d'encaissement, consignee comme telle.

2. **Un objet vendu affirme quelque chose.** « Masque traditionnel bamileke »
   est une affirmation culturelle. Elle est donc typee : soit c'est une
   declaration de l'artisan, affichee comme telle, soit elle est rattachee a
   une fiche culturelle publiee, donc sourcee (SS3, SS20).

3. **Les commandes figent leurs libelles.** Le titre et le prix d'un produit
   sont recopies dans la ligne de commande : changer son tarif ne doit pas
   reecrire une commande passee.
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    ARRAY,
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
from sqlalchemy.dialects.postgresql import JSONB, UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, Timestamped, UUIDPrimaryKey
from app.shared.enums import (
    ApplicationStatus,
    CourierVehicle,
    CulturalClaimStatus,
    DeliveryStatus,
    MarketRoleRequest,
    OrderStatus,
    PaymentMode,
    ProductStatus,
    ShopStatus,
)


class MarketApplication(UUIDPrimaryKey, Timestamped, Base):
    """Dossier pour devenir artisan ou livreur (SS43).

    MBOA ne conserve **aucune piece d'identite**. La verification a lieu hors
    ligne ; ce dossier enregistre qu'elle a eu lieu, sur quelle base et par qui.
    Stocker des scans de documents officiels supposerait une declaration de
    traitement et un responsable juridique, dont le projet ne dispose pas
    encore : le champ `verification_basis` dit ce qui a ete presente, pas ce qui
    a ete copie.
    """

    __tablename__ = "role_applications"
    __table_args__ = (
        Index("ix_role_applications_status", "status"),
        {"schema": "market"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    requested_role: Mapped[MarketRoleRequest] = mapped_column(
        SAEnum(
            MarketRoleRequest, name="market_role_request", schema="shared", create_type=False
        ),
        nullable=False,
    )

    #: Ce que la personne fait, dans ses mots.
    activity_fr: Mapped[str] = mapped_column(Text, nullable=False)
    region_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.regions.id", ondelete="SET NULL"), nullable=True
    )
    city: Mapped[str | None] = mapped_column(String(120), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    #: Livreur seulement.
    vehicle: Mapped[CourierVehicle | None] = mapped_column(
        SAEnum(CourierVehicle, name="courier_vehicle", schema="shared", create_type=False),
        nullable=True,
    )

    status: Mapped[ApplicationStatus] = mapped_column(
        SAEnum(ApplicationStatus, name="application_status", schema="shared", create_type=False),
        default=ApplicationStatus.PENDING,
        server_default="PENDING",
        nullable=False,
    )
    #: Ce qui a ete presente lors de la verification, decrit en clair. Jamais
    #: un document, jamais un numero.
    verification_basis: Mapped[str | None] = mapped_column(Text, nullable=True)
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="SET NULL"), nullable=True
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    review_note: Mapped[str | None] = mapped_column(Text, nullable=True)


class Shop(UUIDPrimaryKey, Timestamped, Base):
    """La boutique d'un artisan."""

    __tablename__ = "shops"
    __table_args__ = (
        UniqueConstraint("owner_user_id", name="uq_shops_owner_user_id"),
        {"schema": "market"},
    )

    owner_user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description_fr: Mapped[str | None] = mapped_column(Text, nullable=True)
    region_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.regions.id", ondelete="SET NULL"), nullable=True
    )
    city: Mapped[str | None] = mapped_column(String(120), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)

    status: Mapped[ShopStatus] = mapped_column(
        SAEnum(ShopStatus, name="shop_status", schema="shared", create_type=False),
        default=ShopStatus.DRAFT,
        server_default="DRAFT",
        nullable=False,
        index=True,
    )
    #: Renseigne par l'administration lors de l'acceptation du dossier.
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    #: Boutique de demonstration, creee par `scripts.seed_market_demo`.
    #:
    #: Le catalogue ne comptait qu'une boutique et un objet : impossible de juger
    #: une grille de place de marche sur si peu. Des boutiques de demonstration
    #: donnent du volume — mais un artisan est une personne, et un objet
    #: artisanal porte souvent une affirmation culturelle. On ne les invente donc
    #: pas en silence : le drapeau suit la boutique jusqu'a l'ecran, et une
    #: commande les efface toutes.
    is_demo: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False, index=True
    )


class Product(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "products"
    __table_args__ = (
        CheckConstraint("price_xaf > 0", name="price_positive"),
        CheckConstraint("stock >= 0", name="stock_not_negative"),
        Index("ix_products_shop_status", "shop_id", "status"),
        {"schema": "market"},
    )

    shop_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("market.shops.id", ondelete="CASCADE"), nullable=False
    )
    title_fr: Mapped[str] = mapped_column(String(160), nullable=False)
    description_fr: Mapped[str | None] = mapped_column(Text, nullable=True)
    category: Mapped[str] = mapped_column(String(32), nullable=False)
    #: En francs CFA, en entier : cette monnaie n'a pas de subdivision d'usage.
    price_xaf: Mapped[int] = mapped_column(Integer, nullable=False)
    stock: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)
    image_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    # --- l'affirmation culturelle portee par l'objet (SS3) ----------------
    #: Ce que l'objet est dit etre : « masque de danse », « pagne ndop »...
    cultural_claim_fr: Mapped[str | None] = mapped_column(Text, nullable=True)
    cultural_claim_status: Mapped[CulturalClaimStatus] = mapped_column(
        SAEnum(
            CulturalClaimStatus, name="cultural_claim_status", schema="shared", create_type=False
        ),
        default=CulturalClaimStatus.NONE,
        server_default="NONE",
        nullable=False,
    )
    #: Fiche du Culture Hub qui documente cette affirmation, quand elle existe.
    cultural_content_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("culture.cultural_contents.id", ondelete="SET NULL"),
        nullable=True,
    )

    status: Mapped[ProductStatus] = mapped_column(
        SAEnum(ProductStatus, name="product_status", schema="shared", create_type=False),
        default=ProductStatus.DRAFT,
        server_default="DRAFT",
        nullable=False,
    )


class Order(UUIDPrimaryKey, Timestamped, Base):
    __tablename__ = "orders"
    __table_args__ = (
        CheckConstraint("total_xaf >= 0", name="total_not_negative"),
        Index("ix_orders_buyer", "buyer_user_id", "created_at"),
        {"schema": "market"},
    )

    #: Reference lisible, communiquee a l'acheteur : MBOA-C-2026-4K7QPX.
    reference: Mapped[str] = mapped_column(String(32), unique=True, nullable=False, index=True)
    buyer_user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="RESTRICT"), nullable=False
    )
    shop_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("market.shops.id", ondelete="RESTRICT"), nullable=False
    )

    status: Mapped[OrderStatus] = mapped_column(
        SAEnum(OrderStatus, name="order_status", schema="shared", create_type=False),
        default=OrderStatus.PENDING_CONFIRMATION,
        server_default="PENDING_CONFIRMATION",
        nullable=False,
        index=True,
    )
    total_xaf: Mapped[int] = mapped_column(Integer, nullable=False)
    #: CASH_ON_DELIVERY ou SIMULATION : dans les deux cas, l'argent ne passe pas
    #: par MBOA. Le premier est un vrai reglement, remis au livreur ; le second
    #: est une demonstration qui ne deplace rien.
    payment_mode: Mapped[PaymentMode] = mapped_column(
        SAEnum(PaymentMode, name="payment_mode", schema="shared", create_type=False),
        default=PaymentMode.CASH_ON_DELIVERY,
        server_default="CASH_ON_DELIVERY",
        nullable=False,
    )
    #: Horodate le passage a la caisse simulee. Un trigger interdit de le poser
    #: sur une commande reelle, et interdit de l'effacer une fois pose : une
    #: demonstration ne doit jamais pouvoir se faire passer pour une vente.
    simulated_paid_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # --- livraison --------------------------------------------------------
    delivery_region_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.regions.id", ondelete="SET NULL"), nullable=True
    )
    delivery_city: Mapped[str] = mapped_column(String(120), nullable=False)
    delivery_address_fr: Mapped[str] = mapped_column(Text, nullable=False)
    delivery_phone: Mapped[str] = mapped_column(String(32), nullable=False)
    buyer_note_fr: Mapped[str | None] = mapped_column(Text, nullable=True)

    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    cancel_reason_fr: Mapped[str | None] = mapped_column(Text, nullable=True)


class OrderItem(UUIDPrimaryKey, Timestamped, Base):
    """Ligne de commande. Les libelles sont figes : changer un tarif ne
    reecrit pas une commande deja passee."""

    __tablename__ = "order_items"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="quantity_positive"),
        {"schema": "market"},
    )

    order_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("market.orders.id", ondelete="CASCADE"), nullable=False
    )
    product_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("market.products.id", ondelete="SET NULL"), nullable=True
    )
    title_fr: Mapped[str] = mapped_column(String(160), nullable=False)
    unit_price_xaf: Mapped[int] = mapped_column(Integer, nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)


class CourierProfile(UUIDPrimaryKey, Timestamped, Base):
    """Le livreur : ses zones, son vehicule, sa disponibilite."""

    __tablename__ = "couriers"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_couriers_user_id"),
        {"schema": "market"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    display_name: Mapped[str] = mapped_column(String(120), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    vehicle: Mapped[CourierVehicle] = mapped_column(
        SAEnum(CourierVehicle, name="courier_vehicle", schema="shared", create_type=False),
        default=CourierVehicle.MOTORCYCLE,
        server_default="MOTORCYCLE",
        nullable=False,
    )
    #: Villes desservies, telles que le livreur les declare.
    cities: Mapped[list[str]] = mapped_column(
        ARRAY(Text), default=list, server_default="{}", nullable=False
    )
    is_available: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False
    )
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Delivery(UUIDPrimaryKey, Timestamped, Base):
    """Course de livraison rattachee a une commande.

    `timeline` conserve chaque changement d'etat avec son horodatage : le suivi
    affiche a l'acheteur est lu ici, pas reconstitue.
    """

    __tablename__ = "deliveries"
    __table_args__ = (
        UniqueConstraint("order_id", name="uq_deliveries_order_id"),
        Index("ix_deliveries_status", "status"),
        {"schema": "market"},
    )

    order_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("market.orders.id", ondelete="CASCADE"), nullable=False
    )
    courier_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("market.couriers.id", ondelete="SET NULL"), nullable=True
    )
    status: Mapped[DeliveryStatus] = mapped_column(
        SAEnum(DeliveryStatus, name="delivery_status", schema="shared", create_type=False),
        default=DeliveryStatus.UNASSIGNED,
        server_default="UNASSIGNED",
        nullable=False,
    )
    pickup_city: Mapped[str | None] = mapped_column(String(120), nullable=True)
    dropoff_city: Mapped[str] = mapped_column(String(120), nullable=False)
    #: [{"status": "...", "at": "...", "note": "..."}]
    timeline: Mapped[list] = mapped_column(
        JSONB, default=list, server_default="[]", nullable=False
    )
    assigned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    failure_reason_fr: Mapped[str | None] = mapped_column(Text, nullable=True)

    #: Ce que le livreur DECLARE avoir encaisse en especes a la remise.
    #: C'est une declaration consignee, pas un paiement enregistre : MBOA
    #: n'a rien recu et ne certifie rien sur ce point.
    cash_declared_xaf: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cash_declared_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class ProductImage(UUIDPrimaryKey, Timestamped, Base):
    """Les photos d'un produit.

    Une place de marche se regarde avant de se lire : sans photo, une grille de
    produits n'est qu'une liste de titres. D'ou une table dediee plutot que
    l'unique `image_url` d'origine, qui ne permettait ni plusieurs vues ni
    reordonnancement.

    Les fichiers sont deposes par l'artisan et servis depuis `media/products/`.
    Aucune image n'est fournie par MBOA : une photo d'illustration prise
    ailleurs laisserait croire que l'objet vendu ressemble a autre chose.
    """

    __tablename__ = "product_images"
    __table_args__ = (
        Index("ix_product_images_product", "product_id", "position"),
        {"schema": "market"},
    )

    product_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("market.products.id", ondelete="CASCADE"), nullable=False
    )
    #: Chemin relatif sous `media/`, par exemple `products/<produit>/<uuid>.jpg`.
    file_key: Mapped[str] = mapped_column(Text, nullable=False)
    caption: Mapped[str | None] = mapped_column(String(200), nullable=True)
    position: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)
