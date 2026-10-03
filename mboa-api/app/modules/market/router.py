"""Place de marche : catalogue public, candidatures, espace artisan (SS45, SS46).

Ce que fait la plateforme : mettre en relation, enregistrer une commande,
organiser une livraison, et tracer qui a fait quoi.

Ce qu'elle ne fait pas, et ne pretend pas faire : encaisser. Le reglement se
fait en especes, du client au livreur, a la remise. Aucun franc ne transite par
MBOA, et la base refuse tout etat qui laisserait croire le contraire.
"""

from __future__ import annotations

import secrets
import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.deps import get_current_user, require_roles
from app.modules.admin.router import record
from app.modules.iam.models import User
from app.shared.enums import (
    PRODUCT_CATEGORIES,
    ApplicationStatus,
    CourierVehicle,
    CulturalClaimStatus,
    MarketRoleRequest,
    ProductStatus,
    ShopStatus,
    UserRole,
)

public_router = APIRouter(prefix="/market", tags=["place de marche"])
application_router = APIRouter(prefix="/me/market-application", tags=["place de marche"])
shop_router = APIRouter(prefix="/me/shop", tags=["espace artisan"])
admin_router = APIRouter(prefix="/admin/market", tags=["place de marche"])

_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"

#: Affiche partout ou une commande est presentee. La plateforme ne laisse
#: jamais supposer qu'elle gere l'argent.
PAYMENT_NOTICE = (
    "Le règlement se fait en espèces, au livreur, à la remise. MBOA n'encaisse "
    "rien et ne conserve aucune donnée bancaire."
)

#: La phrase affichee quand la commande a ete reglee a la caisse de
#: demonstration. Elle est volontairement sans ambiguite : un artisan qui lit
#: « payé » sans lire « simulé » preparerait un colis contre rien.
SIMULATION_NOTICE = (
    "Paiement simulé : aucun argent n'a été échangé. Cette commande sert à "
    "montrer le parcours d'achat de bout en bout. Ne préparez pas d'envoi réel "
    "sur cette base."
)


def payment_notice(mode) -> str:
    """La mention a afficher pour un mode de reglement donne."""
    return SIMULATION_NOTICE if str(mode) == "SIMULATION" else PAYMENT_NOTICE

#: Repli des lettres accentuees, pour une recherche qui n'oblige pas a taper
#: les accents. `unaccent` serait plus propre, mais l'installer demande les
#: droits de superutilisateur sur la base — ce qu'un deploiement mutualise
#: n'accorde pas toujours.
_ACCENTS = "àáâãäåçèéêëìíîïñòóôõöùúûüýÿÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ"
_SANS_ACCENTS = "aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUY"


def _plie(expression: str) -> str:
    """Enveloppe une expression SQL pour la comparer sans accent ni casse."""
    return f"lower(translate({expression}, '{_ACCENTS}', '{_SANS_ACCENTS}'))"

_PRODUCT_COLUMNS = """
    p.id, p.title_fr, p.description_fr, p.category, p.price_xaf, p.stock,
    p.image_url, p.status::text AS status,
    p.cultural_claim_fr, p.cultural_claim_status::text AS cultural_claim_status,
    p.cultural_content_id,
    s.id AS shop_id, s.name AS shop_name, s.city AS shop_city,
    s.is_demo AS shop_is_demo,
    r.name AS region_name,
    (SELECT coalesce(json_agg(json_build_object(
                'id', pi.id,
                'url', '/api/v1/market/images/' || pi.file_key,
                'caption', pi.caption) ORDER BY pi.position), '[]'::json)
       FROM market.product_images pi WHERE pi.product_id = p.id) AS images,
    (SELECT avg(cm.rating)::numeric(3,2) FROM culture.comments cm
      WHERE cm.target_type = 'PRODUCT' AND cm.target_id = p.id
        AND cm.rating IS NOT NULL AND cm.hidden_at IS NULL) AS note_moyenne,
    (SELECT count(*) FROM culture.comments cm
      WHERE cm.target_type = 'PRODUCT' AND cm.target_id = p.id
        AND cm.hidden_at IS NULL) AS avis
"""

_PRODUCT_JOINS = """
    FROM market.products p
    JOIN market.shops s ON s.id = p.shop_id
    LEFT JOIN ref.regions r ON r.id = s.region_id
"""


def new_reference() -> str:
    suffix = "".join(secrets.choice(_ALPHABET) for _ in range(6))
    return f"MBOA-C-{datetime.now(UTC).year}-{suffix}"


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
class MarketApplicationIn(BaseModel):
    requested_role: MarketRoleRequest
    activity_fr: str = Field(min_length=20, max_length=1000)
    region_id: uuid.UUID | None = None
    city: str = Field(min_length=2, max_length=120)
    phone: str = Field(min_length=6, max_length=32)
    vehicle: CourierVehicle | None = None


class MarketDecision(BaseModel):
    decision: str = Field(pattern="^(ACCEPT|REJECT|NEEDS_INFO)$")
    reason: str = Field(min_length=5, max_length=500)
    #: Obligatoire a l'acceptation : ce qui a ete presente et verifie.
    verification_basis: str | None = Field(default=None, max_length=500)


class ShopEdit(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    description_fr: str | None = Field(default=None, max_length=2000)
    region_id: uuid.UUID | None = None
    city: str | None = Field(default=None, max_length=120)
    phone: str | None = Field(default=None, max_length=32)


class ProductIn(BaseModel):
    title_fr: str = Field(min_length=3, max_length=160)
    description_fr: str | None = Field(default=None, max_length=2000)
    category: str
    price_xaf: int = Field(gt=0, le=100_000_000)
    stock: int = Field(ge=0, le=10_000)
    image_url: str | None = Field(default=None, max_length=500)
    #: Ce que l'objet est dit etre, quand l'artisan l'affirme.
    cultural_claim_fr: str | None = Field(default=None, max_length=500)
    #: Fiche du Culture Hub qui documente l'affirmation, si elle existe.
    cultural_content_id: uuid.UUID | None = None


class ProductEdit(ProductIn):
    title_fr: str | None = Field(default=None, min_length=3, max_length=160)
    category: str | None = None
    price_xaf: int | None = Field(default=None, gt=0, le=100_000_000)
    stock: int | None = Field(default=None, ge=0, le=10_000)


def _check_category(category: str) -> str:
    if category not in PRODUCT_CATEGORIES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Categorie inconnue. Valeurs acceptees : {', '.join(PRODUCT_CATEGORIES)}.",
        )
    return category


async def get_shop(
    user: User = Depends(require_roles(UserRole.ARTISAN, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_session),
):
    """La boutique du compte connecte.

    Le role seul ne suffit pas : c'est l'acceptation du dossier qui cree la
    boutique. Un compte promu ARTISAN a la main, sans dossier, n'a rien a gerer.
    """
    row = (
        await db.execute(
            text(
                """
                SELECT id, name, description_fr, region_id, city, phone,
                       status::text AS status, verified_at
                FROM market.shops WHERE owner_user_id = :uid
                """
            ),
            {"uid": user.id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Aucune boutique n'est rattachee a ce compte. Une boutique est creee "
                "lorsque le dossier d'artisan est accepte."
            ),
        )
    return row


# ---------------------------------------------------------------------------
# Candidature artisan / livreur
# ---------------------------------------------------------------------------
@application_router.post("", status_code=status.HTTP_201_CREATED)
async def apply(
    payload: MarketApplicationIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Deposer un dossier d'artisan ou de livreur.

    MBOA ne demande aucune piece d'identite en ligne : elle n'a pas de
    responsable de traitement a qui confier des documents officiels. La
    verification se fait de vive voix, et c'est ce qui aura ete presente qui
    sera consigne au dossier.
    """
    if payload.requested_role is MarketRoleRequest.COURIER and payload.vehicle is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Un dossier de livreur precise le moyen de deplacement.",
        )

    expected = {
        MarketRoleRequest.ARTISAN: UserRole.ARTISAN,
        MarketRoleRequest.COURIER: UserRole.COURIER,
    }[payload.requested_role]
    if user.role is expected:
        raise HTTPException(status_code=409, detail="Ce compte a deja ce role.")

    pending = (
        await db.execute(
            text(
                """
                SELECT 1 FROM market.role_applications
                WHERE user_id = :uid AND requested_role = CAST(:role AS shared.market_role_request)
                  AND status IN ('PENDING','NEEDS_INFO')
                """
            ),
            {"uid": user.id, "role": payload.requested_role.value},
        )
    ).first()
    if pending:
        raise HTTPException(status_code=409, detail="Un dossier est deja en cours.")

    application_id = uuid.uuid4()
    await db.execute(
        text(
            """
            INSERT INTO market.role_applications
                (id, user_id, requested_role, activity_fr, region_id, city, phone,
                 vehicle, status)
            VALUES (:id, :uid, CAST(:role AS shared.market_role_request), :activity,
                    :region, :city, :phone,
                    CAST(:vehicle AS shared.courier_vehicle), 'PENDING')
            """
        ),
        {
            "id": application_id,
            "uid": user.id,
            "role": payload.requested_role.value,
            "activity": payload.activity_fr,
            "region": payload.region_id,
            "city": payload.city,
            "phone": payload.phone,
            "vehicle": payload.vehicle.value if payload.vehicle else None,
        },
    )
    return {"id": str(application_id), "status": "PENDING"}


@application_router.get("")
async def my_applications(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_session)
) -> list[dict]:
    rows = await db.execute(
        text(
            """
            SELECT id, requested_role::text AS requested_role, status::text AS status,
                   city, review_note, created_at, reviewed_at
            FROM market.role_applications
            WHERE user_id = :uid ORDER BY created_at DESC
            """
        ),
        {"uid": user.id},
    )
    return [dict(r._mapping) for r in rows]


@admin_router.get("/applications")
async def list_applications(
    application_status: ApplicationStatus | None = Query(default=None, alias="status"),
    _: User = Depends(require_roles(UserRole.ADMIN)),
    db: AsyncSession = Depends(get_session),
) -> list[dict]:
    conditions = ["true"]
    params: dict = {}
    if application_status is not None:
        conditions.append("a.status = CAST(:st AS shared.application_status)")
        params["st"] = application_status.value

    rows = await db.execute(
        text(
            f"""
            SELECT a.id, a.requested_role::text AS requested_role, a.activity_fr,
                   a.city, a.phone, a.vehicle::text AS vehicle,
                   a.status::text AS status, a.verification_basis, a.review_note,
                   a.created_at, a.reviewed_at,
                   u.id AS user_id, u.email, u.display_name,
                   r.name AS region_name
            FROM market.role_applications a
            JOIN iam.users u ON u.id = a.user_id
            LEFT JOIN ref.regions r ON r.id = a.region_id
            WHERE {' AND '.join(conditions)}
            ORDER BY (a.status = 'PENDING') DESC, a.created_at
            """
        ),
        params,
    )
    return [dict(r._mapping) for r in rows]


@admin_router.post("/applications/{application_id}/decision")
async def decide(
    application_id: uuid.UUID,
    payload: MarketDecision,
    admin: User = Depends(require_roles(UserRole.ADMIN)),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Statuer sur un dossier d'artisan ou de livreur.

    Accepter exige de dire **sur quelle base** : quel entretien, quelle
    rencontre, quel document a ete presente. MBOA ne conserve pas le document ;
    elle conserve la trace de la verification et le nom de qui l'a faite.
    """
    row = (
        await db.execute(
            text(
                """
                SELECT a.*, u.email, u.display_name, u.role::text AS user_role
                FROM market.role_applications a
                JOIN iam.users u ON u.id = a.user_id
                WHERE a.id = :id
                """
            ),
            {"id": application_id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Dossier introuvable.")
    if row.status == ApplicationStatus.ACCEPTED.value:
        raise HTTPException(status_code=409, detail="Ce dossier est deja accepte.")
    if row.user_id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="On ne statue pas sur son propre dossier.",
        )
    if payload.decision == "ACCEPT" and not (payload.verification_basis or "").strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                "Precisez ce qui a ete verifie et comment. Une habilitation sans base "
                "verifiable n'en est pas une."
            ),
        )

    new_status = {
        "ACCEPT": ApplicationStatus.ACCEPTED,
        "REJECT": ApplicationStatus.REJECTED,
        "NEEDS_INFO": ApplicationStatus.NEEDS_INFO,
    }[payload.decision]
    created: str | None = None

    if payload.decision == "ACCEPT":
        is_artisan = row.requested_role == MarketRoleRequest.ARTISAN.value
        await db.execute(
            text("UPDATE iam.users SET role = CAST(:r AS shared.user_role) WHERE id = :id"),
            {
                "r": UserRole.ARTISAN.value if is_artisan else UserRole.COURIER.value,
                "id": row.user_id,
            },
        )
        if is_artisan:
            existing = (
                await db.execute(
                    text("SELECT id FROM market.shops WHERE owner_user_id = :uid"),
                    {"uid": row.user_id},
                )
            ).scalar_one_or_none()
            if existing is None:
                shop_id = uuid.uuid4()
                await db.execute(
                    text(
                        """
                        INSERT INTO market.shops
                            (id, owner_user_id, name, region_id, city, phone,
                             status, verified_at)
                        VALUES (:id, :uid, :name, :region, :city, :phone, 'DRAFT', now())
                        """
                    ),
                    {
                        "id": shop_id,
                        "uid": row.user_id,
                        "name": f"Boutique de {row.display_name}",
                        "region": row.region_id,
                        "city": row.city,
                        "phone": row.phone,
                    },
                )
                created = f"boutique {shop_id}"
        else:
            existing = (
                await db.execute(
                    text("SELECT id FROM market.couriers WHERE user_id = :uid"),
                    {"uid": row.user_id},
                )
            ).scalar_one_or_none()
            if existing is None:
                courier_id = uuid.uuid4()
                await db.execute(
                    text(
                        """
                        INSERT INTO market.couriers
                            (id, user_id, display_name, phone, vehicle, cities,
                             is_available, verified_at)
                        VALUES (:id, :uid, :name, :phone,
                                CAST(:vehicle AS shared.courier_vehicle),
                                :cities, false, now())
                        """
                    ),
                    {
                        "id": courier_id,
                        "uid": row.user_id,
                        "name": row.display_name,
                        "phone": row.phone,
                        "vehicle": row.vehicle or CourierVehicle.MOTORCYCLE.value,
                        "cities": [row.city] if row.city else [],
                    },
                )
                created = f"livreur {courier_id}"

    await db.execute(
        text(
            """
            UPDATE market.role_applications
            SET status = CAST(:st AS shared.application_status),
                reviewed_by = :by, reviewed_at = :at, review_note = :note,
                verification_basis = COALESCE(:basis, verification_basis)
            WHERE id = :id
            """
        ),
        {
            "st": new_status.value,
            "by": admin.id,
            "at": datetime.now(UTC),
            "note": payload.reason,
            "basis": payload.verification_basis,
            "id": application_id,
        },
    )
    await record(
        db,
        actor=admin,
        action=f"MARKET_APPLICATION_{new_status.value}",
        target_type="MARKET_APPLICATION",
        target_id=application_id,
        target_label=f"{row.email} / {row.requested_role}",
        reason=payload.reason,
        details={"verification": payload.verification_basis} if payload.verification_basis else None,
    )
    return {"id": str(application_id), "status": new_status.value, "cree": created}


# ---------------------------------------------------------------------------
# Catalogue public
# ---------------------------------------------------------------------------
@public_router.get("/categories")
async def categories(db: AsyncSession = Depends(get_session)) -> list[dict]:
    rows = await db.execute(
        text(
            """
            SELECT p.category, count(*) AS produits
            FROM market.products p
            JOIN market.shops s ON s.id = p.shop_id
            WHERE p.status = 'PUBLISHED' AND s.status = 'OPEN'
            GROUP BY p.category
            """
        )
    )
    counts = {r.category: r.produits for r in rows}
    return [{"code": code, "produits": counts.get(code, 0)} for code in PRODUCT_CATEGORIES]


@public_router.get("/products")
async def list_products(
    category: str | None = None,
    city: str | None = None,
    q: str | None = Query(default=None, max_length=120),
    min_price: int | None = Query(default=None, ge=0),
    max_price: int | None = Query(default=None, ge=0),
    sort: str = Query(default="RECENT", pattern="^(RECENT|PRICE_ASC|PRICE_DESC|RATING)$"),
    limit: int = Query(default=48, le=100),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Le catalogue, avec recherche, filtres et tri.

    Ne sortent que les produits publies de boutiques ouvertes et encore en stock.

    La recherche porte sur le titre, la description et le nom de la boutique. Elle
    est **insensible aux accents** : quelqu'un qui tape « raphia » doit trouver ce
    qu'il cherche sans se demander ou sont les accents, et « edea » doit trouver
    Edea. `unaccent` n'etant pas installe, on replie a la main les lettres
    concernees — c'est moins elegant qu'une extension, mais cela ne demande aucun
    droit de superutilisateur sur la base.
    """
    conditions = ["p.status = 'PUBLISHED'", "s.status = 'OPEN'", "p.stock > 0"]
    params: dict = {"limit": limit}

    if category:
        conditions.append("p.category = :category")
        params["category"] = _check_category(category)
    if city:
        conditions.append("s.city ILIKE :city")
        params["city"] = city
    if q and q.strip():
        champs = (
            "coalesce(p.title_fr, '') || ' ' || coalesce(p.description_fr, '')"
            " || ' ' || coalesce(s.name, '') || ' ' || coalesce(s.city, '')"
        )
        conditions.append(f"{_plie(champs)} LIKE {_plie(':q')}")
        params["q"] = f"%{q.strip()}%"
    if min_price is not None:
        conditions.append("p.price_xaf >= :min_price")
        params["min_price"] = min_price
    if max_price is not None:
        conditions.append("p.price_xaf <= :max_price")
        params["max_price"] = max_price

    ordre = {
        "RECENT": "p.created_at DESC",
        "PRICE_ASC": "p.price_xaf ASC",
        "PRICE_DESC": "p.price_xaf DESC",
        # Les objets sans avis passent apres ceux qui en ont : une absence de
        # note n'est pas une mauvaise note, mais elle n'est pas un argument.
        "RATING": "note_moyenne DESC NULLS LAST, p.created_at DESC",
    }[sort]

    rows = await db.execute(
        text(
            f"""
            SELECT {_PRODUCT_COLUMNS}
            {_PRODUCT_JOINS}
            WHERE {' AND '.join(conditions)}
            ORDER BY {ordre}
            LIMIT :limit
            """
        ),
        params,
    )
    items = [dict(r._mapping) for r in rows]

    # Les bornes du catalogue entier : elles servent a regler le filtre de prix
    # sans qu'un ecran ait a les deviner.
    bornes = (
        await db.execute(
            text(
                """
                SELECT min(p.price_xaf) AS mini, max(p.price_xaf) AS maxi,
                       count(*) AS total
                FROM market.products p
                JOIN market.shops s ON s.id = p.shop_id
                WHERE p.status = 'PUBLISHED' AND s.status = 'OPEN' AND p.stock > 0
                """
            )
        )
    ).one()

    return {
        "items": items,
        "total": len(items),
        "catalogue": {
            "total": bornes.total,
            "prix_min": bornes.mini,
            "prix_max": bornes.maxi,
        },
        "reglement": PAYMENT_NOTICE,
    }


@public_router.get("/products/{product_id}")
async def product_detail(
    product_id: uuid.UUID, db: AsyncSession = Depends(get_session)
) -> dict:
    row = (
        await db.execute(
            text(
                f"""
                SELECT {_PRODUCT_COLUMNS}, s.description_fr AS shop_description
                {_PRODUCT_JOINS}
                WHERE p.id = :id AND p.status = 'PUBLISHED' AND s.status = 'OPEN'
                """
            ),
            {"id": product_id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Produit introuvable.")

    data = dict(row._mapping)

    # L'affirmation culturelle est presentee avec son statut, jamais nue.
    fiche = None
    if data["cultural_content_id"]:
        fiche = (
            await db.execute(
                text(
                    """
                    SELECT c.id, c.title_fr, c.summary_fr, src.title AS source_title
                    FROM culture.cultural_contents c
                    LEFT JOIN prov.sources src ON src.id = c.source_id
                    WHERE c.id = :id AND c.status = 'PUBLISHED'
                    """
                ),
                {"id": data["cultural_content_id"]},
            )
        ).one_or_none()

    data["fiche_culturelle"] = dict(fiche._mapping) if fiche else None
    data["reglement"] = PAYMENT_NOTICE
    return data


@public_router.get("/shops/{shop_id}")
async def shop_detail(shop_id: uuid.UUID, db: AsyncSession = Depends(get_session)) -> dict:
    row = (
        await db.execute(
            text(
                """
                SELECT s.id, s.name, s.description_fr, s.city, s.phone,
                       r.name AS region_name, s.verified_at
                FROM market.shops s
                LEFT JOIN ref.regions r ON r.id = s.region_id
                WHERE s.id = :id AND s.status = 'OPEN'
                """
            ),
            {"id": shop_id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Boutique introuvable.")

    products = await db.execute(
        text(
            f"""
            SELECT {_PRODUCT_COLUMNS}
            {_PRODUCT_JOINS}
            WHERE p.shop_id = :id AND p.status = 'PUBLISHED'
            ORDER BY p.created_at DESC
            """
        ),
        {"id": shop_id},
    )
    return {
        "boutique": dict(row._mapping),
        "produits": [dict(r._mapping) for r in products],
    }


# ---------------------------------------------------------------------------
# Espace artisan
# ---------------------------------------------------------------------------
@shop_router.get("")
async def my_shop(shop=Depends(get_shop), db: AsyncSession = Depends(get_session)) -> dict:
    counts = (
        await db.execute(
            text(
                """
                SELECT
                    (SELECT count(*) FROM market.products
                      WHERE shop_id = :sid) AS produits,
                    (SELECT count(*) FROM market.products
                      WHERE shop_id = :sid AND status = 'PUBLISHED') AS produits_publies,
                    (SELECT count(*) FROM market.orders
                      WHERE shop_id = :sid) AS commandes,
                    (SELECT count(*) FROM market.orders
                      WHERE shop_id = :sid
                        AND status = 'PENDING_CONFIRMATION') AS commandes_a_traiter
                """
            ),
            {"sid": shop.id},
        )
    ).one()
    return {
        "boutique": dict(shop._mapping),
        "chiffres": dict(counts._mapping),
        "reglement": PAYMENT_NOTICE,
    }


@shop_router.patch("")
async def edit_shop(
    payload: ShopEdit, shop=Depends(get_shop), db: AsyncSession = Depends(get_session)
) -> dict:
    changes = payload.model_dump(exclude_none=True)
    if not changes:
        return dict(shop._mapping)

    assignments = ", ".join(f"{field} = :{field}" for field in changes)
    await db.execute(
        text(f"UPDATE market.shops SET {assignments} WHERE id = :id"),
        {**changes, "id": shop.id},
    )
    updated = (
        await db.execute(
            text(
                """
                SELECT id, name, description_fr, region_id, city, phone,
                       status::text AS status, verified_at
                FROM market.shops WHERE id = :id
                """
            ),
            {"id": shop.id},
        )
    ).one()
    return dict(updated._mapping)


@shop_router.post("/open")
async def open_shop(shop=Depends(get_shop), db: AsyncSession = Depends(get_session)) -> dict:
    """Ouvre la boutique au public.

    On exige une description et une ville : un acheteur doit savoir qui il a en
    face et d'ou part le colis.
    """
    row = (
        await db.execute(
            text("SELECT description_fr, city FROM market.shops WHERE id = :id"),
            {"id": shop.id},
        )
    ).one()
    manquants = [
        label
        for label, value in (("une description", row.description_fr), ("une ville", row.city))
        if not (value or "").strip()
    ]
    if manquants:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Avant d'ouvrir, renseignez {' et '.join(manquants)}.",
        )

    await db.execute(
        text("UPDATE market.shops SET status = 'OPEN' WHERE id = :id"), {"id": shop.id}
    )
    return {"status": ShopStatus.OPEN.value}


@shop_router.post("/close")
async def close_shop(shop=Depends(get_shop), db: AsyncSession = Depends(get_session)) -> dict:
    """Ferme la boutique. Les commandes en cours poursuivent leur chemin."""
    await db.execute(
        text("UPDATE market.shops SET status = 'CLOSED' WHERE id = :id"), {"id": shop.id}
    )
    return {"status": ShopStatus.CLOSED.value}


@shop_router.get("/products")
async def my_products(shop=Depends(get_shop), db: AsyncSession = Depends(get_session)) -> list[dict]:
    rows = await db.execute(
        text(
            """
            SELECT p.id, p.title_fr, p.description_fr, p.category, p.price_xaf,
                   p.stock, p.image_url,
                   p.status::text AS status, p.cultural_claim_fr,
                   p.cultural_claim_status::text AS cultural_claim_status,
                   p.cultural_content_id, p.created_at,
                   (SELECT coalesce(json_agg(json_build_object(
                               'id', pi.id,
                               'url', '/api/v1/market/images/' || pi.file_key,
                               'caption', pi.caption) ORDER BY pi.position), '[]'::json)
                      FROM market.product_images pi
                     WHERE pi.product_id = p.id) AS images
            FROM market.products p WHERE p.shop_id = :sid ORDER BY p.created_at DESC
            """
        ),
        {"sid": shop.id},
    )
    return [dict(r._mapping) for r in rows]


async def _claim_status(
    db: AsyncSession, claim: str | None, content_id: uuid.UUID | None
) -> tuple[CulturalClaimStatus, uuid.UUID | None]:
    """Qualifie l'affirmation culturelle d'une fiche produit (SS3).

    Sans affirmation, rien a qualifier. Avec une affirmation mais sans fiche
    publiee derriere, c'est une declaration de l'artisan - affichee comme telle,
    jamais comme un fait etabli.
    """
    if not (claim or "").strip():
        return CulturalClaimStatus.NONE, None
    if content_id is None:
        return CulturalClaimStatus.ARTISAN_DECLARATION, None

    published = (
        await db.execute(
            text(
                "SELECT 1 FROM culture.cultural_contents "
                "WHERE id = :id AND status = 'PUBLISHED'"
            ),
            {"id": content_id},
        )
    ).first()
    if published is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "Cette fiche culturelle n'est pas publiee : elle ne peut pas servir de "
                "caution a une affirmation commerciale."
            ),
        )
    return CulturalClaimStatus.LINKED_TO_SOURCE, content_id


@shop_router.post("/products", status_code=status.HTTP_201_CREATED)
async def create_product(
    payload: ProductIn, shop=Depends(get_shop), db: AsyncSession = Depends(get_session)
) -> dict:
    _check_category(payload.category)
    claim_status, content_id = await _claim_status(
        db, payload.cultural_claim_fr, payload.cultural_content_id
    )

    product_id = uuid.uuid4()
    await db.execute(
        text(
            """
            INSERT INTO market.products
                (id, shop_id, title_fr, description_fr, category, price_xaf, stock,
                 image_url, cultural_claim_fr, cultural_claim_status,
                 cultural_content_id, status)
            VALUES (:id, :sid, :title, :description, :category, :price, :stock,
                    :image, :claim, CAST(:claim_status AS shared.cultural_claim_status),
                    :content, 'DRAFT')
            """
        ),
        {
            "id": product_id,
            "sid": shop.id,
            "title": payload.title_fr,
            "description": payload.description_fr,
            "category": payload.category,
            "price": payload.price_xaf,
            "stock": payload.stock,
            "image": payload.image_url,
            "claim": payload.cultural_claim_fr,
            "claim_status": claim_status.value,
            "content": content_id,
        },
    )
    return {
        "id": str(product_id),
        "status": ProductStatus.DRAFT.value,
        "cultural_claim_status": claim_status.value,
    }


@shop_router.patch("/products/{product_id}")
async def edit_product(
    product_id: uuid.UUID,
    payload: ProductEdit,
    shop=Depends(get_shop),
    db: AsyncSession = Depends(get_session),
) -> dict:
    current = (
        await db.execute(
            text(
                """
                SELECT cultural_claim_fr, cultural_content_id
                FROM market.products WHERE id = :id AND shop_id = :sid
                """
            ),
            {"id": product_id, "sid": shop.id},
        )
    ).one_or_none()
    if current is None:
        raise HTTPException(status_code=404, detail="Produit introuvable dans cette boutique.")

    changes = payload.model_dump(exclude_none=True)
    if "category" in changes:
        _check_category(changes["category"])

    claim = changes.get("cultural_claim_fr", current.cultural_claim_fr)
    content_id = changes.get("cultural_content_id", current.cultural_content_id)
    claim_status, content_id = await _claim_status(db, claim, content_id)
    changes["cultural_claim_status"] = claim_status.value
    changes["cultural_content_id"] = content_id

    assignments = ", ".join(
        "cultural_claim_status = CAST(:cultural_claim_status AS shared.cultural_claim_status)"
        if field == "cultural_claim_status"
        else f"{field} = :{field}"
        for field in changes
    )
    await db.execute(
        text(f"UPDATE market.products SET {assignments} WHERE id = :id"),
        {**changes, "id": product_id},
    )
    return {"id": str(product_id), "cultural_claim_status": claim_status.value}


@shop_router.post("/products/{product_id}/publish")
async def publish_product(
    product_id: uuid.UUID, shop=Depends(get_shop), db: AsyncSession = Depends(get_session)
) -> dict:
    row = (
        await db.execute(
            text(
                """
                SELECT stock, description_fr FROM market.products
                WHERE id = :id AND shop_id = :sid
                """
            ),
            {"id": product_id, "sid": shop.id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Produit introuvable dans cette boutique.")
    if shop.status != ShopStatus.OPEN.value:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ouvrez d'abord la boutique : un produit seul n'est pas visible.",
        )
    if row.stock <= 0:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un produit sans stock ne se met pas en vente.",
        )
    if not (row.description_fr or "").strip():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Decrivez l'objet avant de le mettre en vente.",
        )

    try:
        await db.execute(
            text("UPDATE market.products SET status = 'PUBLISHED' WHERE id = :id"),
            {"id": product_id},
        )
    except DBAPIError as exc:
        if "MBOA[" in str(exc.orig):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="La base a refuse la publication : l'affirmation culturelle est invalide.",
            ) from exc
        raise
    return {"id": str(product_id), "status": ProductStatus.PUBLISHED.value}


@shop_router.post("/products/{product_id}/withdraw")
async def withdraw_product(
    product_id: uuid.UUID, shop=Depends(get_shop), db: AsyncSession = Depends(get_session)
) -> dict:
    updated = await db.execute(
        text(
            """
            UPDATE market.products SET status = 'WITHDRAWN'
            WHERE id = :id AND shop_id = :sid RETURNING id
            """
        ),
        {"id": product_id, "sid": shop.id},
    )
    if updated.first() is None:
        raise HTTPException(status_code=404, detail="Produit introuvable dans cette boutique.")
    return {"id": str(product_id), "status": ProductStatus.WITHDRAWN.value}
