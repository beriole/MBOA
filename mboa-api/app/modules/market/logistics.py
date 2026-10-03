"""Commandes et livraisons (SS47, SS48).

La chaine complete : un acheteur commande, l'artisan confirme et prepare, un
livreur prend en charge et remet. Le reglement se fait en especes a la remise,
hors plateforme.

Ce que MBOA enregistre du paiement est donc une **declaration** du livreur : le
montant qu'il dit avoir recu. Ce n'est pas un encaissement, et l'API ne le
presente jamais comme tel. Quand la somme declaree differe du total, un motif
est exige : une difference silencieuse serait un litige que personne ne verrait.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.deps import get_current_user, require_roles
from app.modules.iam.models import User
from app.modules.market.router import (
    PAYMENT_NOTICE,
    get_shop,
    new_reference,
    payment_notice,
)
from app.shared.enums import (
    CourierVehicle,
    DeliveryStatus,
    OrderStatus,
    PaymentMode,
    UserRole,
)

#: Les seuls reglements ouverts. Ni l'un ni l'autre ne fait transiter d'argent
#: par MBOA : le premier se remet au livreur, le second ne deplace rien.
OPEN_PAYMENT_MODES = frozenset({PaymentMode.CASH_ON_DELIVERY, PaymentMode.SIMULATION})

order_router = APIRouter(prefix="/me/orders", tags=["commandes"])
shop_orders_router = APIRouter(prefix="/me/shop/orders", tags=["espace artisan"])
courier_router = APIRouter(prefix="/me/courier", tags=["espace livreur"])

#: Etats a partir desquels l'acheteur peut encore annuler sans discussion :
#: rien n'est parti.
CANCELLABLE = (OrderStatus.PENDING_CONFIRMATION, OrderStatus.CONFIRMED)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
class OrderIn(BaseModel):
    product_id: uuid.UUID
    quantity: int = Field(default=1, ge=1, le=50)
    delivery_region_id: uuid.UUID | None = None
    delivery_city: str = Field(min_length=2, max_length=120)
    delivery_address_fr: str = Field(min_length=5, max_length=500)
    delivery_phone: str = Field(min_length=6, max_length=32)
    buyer_note_fr: str | None = Field(default=None, max_length=500)
    #: CASH_ON_DELIVERY (reel, remis au livreur) ou SIMULATION (demonstration).
    #: Aucun des deux ne fait transiter d'argent par MBOA.
    payment_mode: PaymentMode = PaymentMode.CASH_ON_DELIVERY


class Motivated(BaseModel):
    reason: str = Field(min_length=5, max_length=500)


class CourierEdit(BaseModel):
    vehicle: CourierVehicle | None = None
    cities: list[str] | None = None
    is_available: bool | None = None
    phone: str | None = Field(default=None, max_length=32)


class DeliveryUpdate(BaseModel):
    status: DeliveryStatus
    note_fr: str | None = Field(default=None, max_length=500)
    #: Obligatoire a la remise : ce que le livreur declare avoir encaisse.
    cash_declared_xaf: int | None = Field(default=None, ge=0, le=100_000_000)


async def _order_or_404(db: AsyncSession, order_id: uuid.UUID, **owner):
    field, value = next(iter(owner.items()))
    row = (
        await db.execute(
            text(
                f"""
                SELECT o.*, s.name AS shop_name, s.city AS shop_city
                FROM market.orders o
                JOIN market.shops s ON s.id = o.shop_id
                WHERE o.id = :id AND o.{field} = :owner
                """
            ),
            {"id": order_id, "owner": value},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Commande introuvable.")
    return row


async def _timeline_push(
    db: AsyncSession, delivery_id: uuid.UUID, status_value: str, note: str | None
) -> None:
    """Ajoute une etape au suivi. Le suivi est lu, jamais reconstitue."""
    import json

    await db.execute(
        text(
            """
            UPDATE market.deliveries
            SET timeline = timeline || CAST(:step AS jsonb)
            WHERE id = :id
            """
        ),
        {
            "id": delivery_id,
            "step": json.dumps(
                [{"status": status_value, "at": datetime.now(UTC).isoformat(), "note": note}]
            ),
        },
    )


# ---------------------------------------------------------------------------
# Acheteur
# ---------------------------------------------------------------------------
@order_router.post("", status_code=status.HTTP_201_CREATED)
async def place_order(
    payload: OrderIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Passe une commande.

    Le stock est decremente ici, pas a la confirmation : deux acheteurs ne
    doivent pas pouvoir reserver le meme objet unique. Une annulation le rend.
    """
    product = (
        await db.execute(
            text(
                """
                SELECT p.id, p.title_fr, p.price_xaf, p.stock, p.shop_id,
                       s.status::text AS shop_status, s.city AS shop_city,
                       s.owner_user_id
                FROM market.products p
                JOIN market.shops s ON s.id = p.shop_id
                WHERE p.id = :id AND p.status = 'PUBLISHED'
                """
            ),
            {"id": payload.product_id},
        )
    ).one_or_none()
    if product is None:
        raise HTTPException(status_code=404, detail="Produit introuvable ou retire de la vente.")
    if product.shop_status != "OPEN":
        raise HTTPException(status_code=409, detail="Cette boutique est fermee.")
    if product.owner_user_id == user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="On ne commande pas dans sa propre boutique.",
        )
    if payload.payment_mode not in OPEN_PAYMENT_MODES:
        raise HTTPException(
            status_code=422,
            detail=f"Le mode « {payload.payment_mode.value} » n'est pas raccordé. "
            "Deux règlements sont ouverts : les espèces remises au livreur, et le "
            "paiement simulé, qui sert à essayer le parcours sans rien payer.",
        )
    if product.stock < payload.quantity:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Stock insuffisant : il reste {product.stock} piece(s).",
        )

    order_id = uuid.uuid4()
    total = product.price_xaf * payload.quantity
    await db.execute(
        text(
            """
            INSERT INTO market.orders
                (id, reference, buyer_user_id, shop_id, status, total_xaf, payment_mode,
                 simulated_paid_at,
                 delivery_region_id, delivery_city, delivery_address_fr, delivery_phone,
                 buyer_note_fr)
            VALUES (:id, :ref, :uid, :sid, 'PENDING_CONFIRMATION', :total,
                    CAST(:mode AS shared.payment_mode), :simule,
                    :region, :city, :address, :phone, :note)
            """
        ),
        {
            "mode": payload.payment_mode.value,
            # La caisse simulee est horodatee a la commande : il n'y a rien a
            # encaisser ensuite, et un trigger interdit d'effacer la marque.
            "simule": (
                datetime.now(UTC)
                if payload.payment_mode is PaymentMode.SIMULATION
                else None
            ),
            "id": order_id,
            "ref": new_reference(),
            "uid": user.id,
            "sid": product.shop_id,
            "total": total,
            "region": payload.delivery_region_id,
            "city": payload.delivery_city,
            "address": payload.delivery_address_fr,
            "phone": payload.delivery_phone,
            "note": payload.buyer_note_fr,
        },
    )
    await db.execute(
        text(
            """
            INSERT INTO market.order_items
                (id, order_id, product_id, title_fr, unit_price_xaf, quantity)
            VALUES (:id, :oid, :pid, :title, :price, :qty)
            """
        ),
        {
            "id": uuid.uuid4(),
            "oid": order_id,
            "pid": product.id,
            "title": product.title_fr,
            "price": product.price_xaf,
            "qty": payload.quantity,
        },
    )
    await db.execute(
        text("UPDATE market.products SET stock = stock - :qty WHERE id = :id"),
        {"qty": payload.quantity, "id": product.id},
    )
    await db.execute(
        text(
            """
            INSERT INTO market.deliveries
                (id, order_id, status, pickup_city, dropoff_city, timeline)
            VALUES (:id, :oid, 'UNASSIGNED', :pickup, :dropoff, '[]'::jsonb)
            """
        ),
        {
            "id": uuid.uuid4(),
            "oid": order_id,
            "pickup": product.shop_city,
            "dropoff": payload.delivery_city,
        },
    )

    created = (
        await db.execute(
            text("SELECT reference, total_xaf FROM market.orders WHERE id = :id"),
            {"id": order_id},
        )
    ).one()
    return {
        "id": str(order_id),
        "reference": created.reference,
        "total_xaf": created.total_xaf,
        "status": OrderStatus.PENDING_CONFIRMATION.value,
        "payment_mode": payload.payment_mode.value,
        "reglement": payment_notice(payload.payment_mode),
    }


@order_router.get("")
async def my_orders(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_session)
) -> dict:
    rows = await db.execute(
        text(
            """
            SELECT o.id, o.reference, o.status::text AS status, o.total_xaf,
                   o.payment_mode::text AS payment_mode, o.simulated_paid_at,
                   o.delivery_city, o.delivery_address_fr, o.created_at,
                   o.cancel_reason_fr,
                   s.name AS shop_name,
                   d.status::text AS delivery_status, d.timeline,
                   c.display_name AS courier_name, c.phone AS courier_phone
            FROM market.orders o
            JOIN market.shops s ON s.id = o.shop_id
            LEFT JOIN market.deliveries d ON d.order_id = o.id
            LEFT JOIN market.couriers c ON c.id = d.courier_id
            WHERE o.buyer_user_id = :uid
            ORDER BY o.created_at DESC
            """
        ),
        {"uid": user.id},
    )
    orders = [dict(r._mapping) for r in rows]

    for order in orders:
        items = await db.execute(
            text(
                """
                SELECT title_fr, unit_price_xaf, quantity FROM market.order_items
                WHERE order_id = :oid
                """
            ),
            {"oid": order["id"]},
        )
        order["lignes"] = [dict(i._mapping) for i in items]
        order["reglement"] = payment_notice(order["payment_mode"])

    return {"items": orders, "reglement": PAYMENT_NOTICE}


@order_router.post("/{order_id}/cancel")
async def cancel_order(
    order_id: uuid.UUID,
    payload: Motivated,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Annule sa commande, tant que rien n'est parti."""
    order = await _order_or_404(db, order_id, buyer_user_id=user.id)
    if order.status not in {s.value for s in CANCELLABLE}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "Cette commande est deja en preparation ou en route : contactez la "
                "boutique ou le livreur."
            ),
        )
    await _release(db, order_id, payload.reason)
    return {"reference": order.reference, "status": OrderStatus.CANCELLED.value}


async def _release(db: AsyncSession, order_id: uuid.UUID, reason: str) -> None:
    """Annule une commande et rend le stock immobilise."""
    await db.execute(
        text(
            """
            UPDATE market.products p
            SET stock = p.stock + i.quantity
            FROM market.order_items i
            WHERE i.order_id = :oid AND i.product_id = p.id
            """
        ),
        {"oid": order_id},
    )
    await db.execute(
        text(
            """
            UPDATE market.orders
            SET status = 'CANCELLED', cancelled_at = now(), cancel_reason_fr = :reason
            WHERE id = :id
            """
        ),
        {"reason": reason, "id": order_id},
    )
    await db.execute(
        text(
            """
            UPDATE market.deliveries SET status = 'FAILED', failure_reason_fr = :reason
            WHERE order_id = :oid AND status <> 'DELIVERED'
            """
        ),
        {"reason": f"Commande annulee : {reason}", "oid": order_id},
    )


# ---------------------------------------------------------------------------
# Espace artisan : les commandes recues
# ---------------------------------------------------------------------------
@shop_orders_router.get("")
async def shop_orders(shop=Depends(get_shop), db: AsyncSession = Depends(get_session)) -> dict:
    rows = await db.execute(
        text(
            """
            SELECT o.id, o.reference, o.status::text AS status, o.total_xaf,
                   o.payment_mode::text AS payment_mode, o.simulated_paid_at,
                   o.delivery_city, o.delivery_address_fr, o.delivery_phone,
                   o.buyer_note_fr, o.created_at,
                   u.display_name AS buyer_name,
                   d.status::text AS delivery_status,
                   c.display_name AS courier_name
            FROM market.orders o
            JOIN iam.users u ON u.id = o.buyer_user_id
            LEFT JOIN market.deliveries d ON d.order_id = o.id
            LEFT JOIN market.couriers c ON c.id = d.courier_id
            WHERE o.shop_id = :sid
            ORDER BY (o.status = 'PENDING_CONFIRMATION') DESC, o.created_at DESC
            """
        ),
        {"sid": shop.id},
    )
    orders = [dict(r._mapping) for r in rows]
    for order in orders:
        items = await db.execute(
            text(
                """
                SELECT title_fr, unit_price_xaf, quantity FROM market.order_items
                WHERE order_id = :oid
                """
            ),
            {"oid": order["id"]},
        )
        order["lignes"] = [dict(i._mapping) for i in items]
        # L'artisan est le premier a devoir voir qu'une commande est une
        # demonstration : c'est lui qui prepare le colis.
        order["reglement"] = payment_notice(order["payment_mode"])
    return {"items": orders, "reglement": PAYMENT_NOTICE}


@shop_orders_router.post("/{order_id}/confirm")
async def confirm_order(
    order_id: uuid.UUID, shop=Depends(get_shop), db: AsyncSession = Depends(get_session)
) -> dict:
    """L'artisan accepte la commande et s'engage a la preparer."""
    order = await _order_or_404(db, order_id, shop_id=shop.id)
    if order.status != OrderStatus.PENDING_CONFIRMATION.value:
        raise HTTPException(status_code=409, detail="Cette commande n'attend pas de confirmation.")

    await db.execute(
        text("UPDATE market.orders SET status = 'CONFIRMED' WHERE id = :id"), {"id": order_id}
    )
    return {"reference": order.reference, "status": OrderStatus.CONFIRMED.value}


@shop_orders_router.post("/{order_id}/ready")
async def order_ready(
    order_id: uuid.UUID, shop=Depends(get_shop), db: AsyncSession = Depends(get_session)
) -> dict:
    """Le colis est pret : la course devient visible pour les livreurs."""
    order = await _order_or_404(db, order_id, shop_id=shop.id)
    if order.status not in (OrderStatus.CONFIRMED.value, OrderStatus.PREPARING.value):
        raise HTTPException(
            status_code=409,
            detail="Confirmez d'abord la commande.",
        )

    await db.execute(
        text("UPDATE market.orders SET status = 'READY_FOR_PICKUP' WHERE id = :id"),
        {"id": order_id},
    )
    return {"reference": order.reference, "status": OrderStatus.READY_FOR_PICKUP.value}


@shop_orders_router.post("/{order_id}/cancel")
async def shop_cancel(
    order_id: uuid.UUID,
    payload: Motivated,
    shop=Depends(get_shop),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """L'artisan annule, avec un motif que l'acheteur verra."""
    order = await _order_or_404(db, order_id, shop_id=shop.id)
    if order.status in (OrderStatus.DELIVERED.value, OrderStatus.CANCELLED.value):
        raise HTTPException(status_code=409, detail="Cette commande est deja close.")

    await _release(db, order_id, payload.reason)
    return {"reference": order.reference, "status": OrderStatus.CANCELLED.value}


# ---------------------------------------------------------------------------
# Espace livreur
# ---------------------------------------------------------------------------
async def get_courier(
    user: User = Depends(require_roles(UserRole.COURIER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_session),
):
    row = (
        await db.execute(
            text(
                """
                SELECT id, display_name, phone, vehicle::text AS vehicle, cities,
                       is_available, verified_at
                FROM market.couriers WHERE user_id = :uid
                """
            ),
            {"uid": user.id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Aucune fiche de livreur n'est rattachee a ce compte. Elle est creee "
                "lorsque le dossier est accepte."
            ),
        )
    return row


@courier_router.get("")
async def my_courier_profile(
    courier=Depends(get_courier), db: AsyncSession = Depends(get_session)
) -> dict:
    counts = (
        await db.execute(
            text(
                """
                SELECT
                    count(*) FILTER (WHERE status = 'DELIVERED') AS livrees,
                    count(*) FILTER (WHERE status IN ('ASSIGNED','PICKED_UP','IN_TRANSIT'))
                        AS en_cours,
                    count(*) FILTER (WHERE status = 'FAILED') AS echouees,
                    COALESCE(sum(cash_declared_xaf) FILTER (WHERE status = 'DELIVERED'), 0)
                        AS especes_declarees
                FROM market.deliveries WHERE courier_id = :cid
                """
            ),
            {"cid": courier.id},
        )
    ).one()
    return {
        "livreur": dict(courier._mapping),
        "chiffres": dict(counts._mapping),
        "note": (
            "Les espèces déclarées sont ce que vous avez saisi avoir reçu. MBOA "
            "n'encaisse rien et ne certifie pas ces montants."
        ),
    }


@courier_router.patch("")
async def edit_courier(
    payload: CourierEdit,
    courier=Depends(get_courier),
    db: AsyncSession = Depends(get_session),
) -> dict:
    changes = payload.model_dump(exclude_none=True)
    if not changes:
        return dict(courier._mapping)
    if "cities" in changes and not changes["cities"]:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Declarez au moins une ville desservie.",
        )

    assignments = ", ".join(
        "vehicle = CAST(:vehicle AS shared.courier_vehicle)"
        if field == "vehicle"
        else f"{field} = :{field}"
        for field in changes
    )
    if "vehicle" in changes:
        changes["vehicle"] = changes["vehicle"].value

    await db.execute(
        text(f"UPDATE market.couriers SET {assignments} WHERE id = :id"),
        {**changes, "id": courier.id},
    )
    updated = (
        await db.execute(
            text(
                """
                SELECT id, display_name, phone, vehicle::text AS vehicle, cities,
                       is_available, verified_at
                FROM market.couriers WHERE id = :id
                """
            ),
            {"id": courier.id},
        )
    ).one()
    return dict(updated._mapping)


@courier_router.get("/available")
async def available_deliveries(
    limit: int = Query(default=30, le=100),
    courier=Depends(get_courier),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Les courses a prendre.

    Seules celles dont la ville de retrait ou de remise figure dans les villes
    declarees : proposer une course a 400 km ferait perdre du temps a tout le
    monde.
    """
    if not courier.is_available:
        return {
            "items": [],
            "message": "Vous êtes indisponible. Passez-vous disponible pour voir les courses.",
        }

    rows = await db.execute(
        text(
            """
            SELECT d.id, d.pickup_city, d.dropoff_city,
                   o.reference, o.total_xaf, o.delivery_address_fr,
                   s.name AS shop_name, s.city AS shop_city, s.phone AS shop_phone
            FROM market.deliveries d
            JOIN market.orders o ON o.id = d.order_id
            JOIN market.shops s ON s.id = o.shop_id
            WHERE d.status = 'UNASSIGNED'
              AND o.status = 'READY_FOR_PICKUP'
              AND (d.dropoff_city = ANY(:cities) OR d.pickup_city = ANY(:cities))
            ORDER BY o.created_at
            LIMIT :limit
            """
        ),
        {"cities": list(courier.cities), "limit": limit},
    )
    return {
        "items": [dict(r._mapping) for r in rows],
        "message": (
            "Le client règle en espèces à la remise. Vous déclarez ensuite le "
            "montant reçu ; MBOA n'encaisse rien."
        ),
    }


@courier_router.post("/deliveries/{delivery_id}/accept")
async def accept_delivery(
    delivery_id: uuid.UUID,
    courier=Depends(get_courier),
    db: AsyncSession = Depends(get_session),
) -> dict:
    if not courier.is_available:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Passez-vous disponible avant de prendre une course.",
        )

    row = (
        await db.execute(
            text(
                """
                SELECT d.id, d.status::text AS status, d.pickup_city, d.dropoff_city,
                       o.status::text AS order_status, o.reference
                FROM market.deliveries d
                JOIN market.orders o ON o.id = d.order_id
                WHERE d.id = :id
                """
            ),
            {"id": delivery_id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Course introuvable.")
    if row.status != DeliveryStatus.UNASSIGNED.value:
        raise HTTPException(status_code=409, detail="Cette course est deja prise.")
    if row.order_status != OrderStatus.READY_FOR_PICKUP.value:
        raise HTTPException(status_code=409, detail="Le colis n'est pas encore pret.")

    villes = set(courier.cities)
    if row.dropoff_city not in villes and row.pickup_city not in villes:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cette course n'est dans aucune des villes que vous desservez.",
        )

    await db.execute(
        text(
            """
            UPDATE market.deliveries
            SET status = 'ASSIGNED', courier_id = :cid, assigned_at = now()
            WHERE id = :id AND status = 'UNASSIGNED'
            """
        ),
        {"cid": courier.id, "id": delivery_id},
    )
    await _timeline_push(db, delivery_id, DeliveryStatus.ASSIGNED.value, courier.display_name)
    return {"id": str(delivery_id), "status": DeliveryStatus.ASSIGNED.value}


@courier_router.get("/deliveries")
async def my_deliveries(
    courier=Depends(get_courier), db: AsyncSession = Depends(get_session)
) -> list[dict]:
    rows = await db.execute(
        text(
            """
            SELECT d.id, d.status::text AS status, d.pickup_city, d.dropoff_city,
                   d.timeline, d.cash_declared_xaf, d.delivered_at,
                   o.reference, o.total_xaf, o.delivery_address_fr, o.delivery_phone,
                   s.name AS shop_name, s.phone AS shop_phone
            FROM market.deliveries d
            JOIN market.orders o ON o.id = d.order_id
            JOIN market.shops s ON s.id = o.shop_id
            WHERE d.courier_id = :cid
            ORDER BY d.assigned_at DESC NULLS LAST
            """
        ),
        {"cid": courier.id},
    )
    return [dict(r._mapping) for r in rows]


#: Enchainement autorise des etats d'une course.
_NEXT = {
    DeliveryStatus.ASSIGNED: {DeliveryStatus.PICKED_UP, DeliveryStatus.FAILED},
    DeliveryStatus.PICKED_UP: {DeliveryStatus.IN_TRANSIT, DeliveryStatus.FAILED},
    DeliveryStatus.IN_TRANSIT: {DeliveryStatus.DELIVERED, DeliveryStatus.FAILED},
}

#: Etat de la commande entraine par l'etat de la course.
_ORDER_FROM_DELIVERY = {
    DeliveryStatus.PICKED_UP: OrderStatus.IN_DELIVERY,
    DeliveryStatus.DELIVERED: OrderStatus.DELIVERED,
}


@courier_router.post("/deliveries/{delivery_id}/status")
async def update_delivery(
    delivery_id: uuid.UUID,
    payload: DeliveryUpdate,
    courier=Depends(get_courier),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Fait avancer une course.

    A la remise, le livreur declare la somme recue. Si elle differe du total, un
    motif est exige : une difference silencieuse serait un litige que personne
    ne verrait passer.
    """
    row = (
        await db.execute(
            text(
                """
                SELECT d.id, d.status::text AS status, d.order_id,
                       o.reference, o.total_xaf
                FROM market.deliveries d
                JOIN market.orders o ON o.id = d.order_id
                WHERE d.id = :id AND d.courier_id = :cid
                """
            ),
            {"id": delivery_id, "cid": courier.id},
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Course introuvable ou non attribuee.")

    current = DeliveryStatus(row.status)
    if payload.status not in _NEXT.get(current, set()):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Passage impossible de {current.value} a {payload.status.value}.",
        )
    if payload.status is DeliveryStatus.FAILED and not (payload.note_fr or "").strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Une course non aboutie s'explique : indiquez ce qui s'est passe.",
        )

    ecart = None
    if payload.status is DeliveryStatus.DELIVERED:
        if payload.cash_declared_xaf is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Declarez la somme recue a la remise.",
            )
        ecart = payload.cash_declared_xaf - row.total_xaf
        if ecart != 0 and not (payload.note_fr or "").strip():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    f"La somme declaree s'ecarte de {ecart:+d} FCFA du total. "
                    "Expliquez cet ecart."
                ),
            )

    assignments = ["status = CAST(:st AS shared.delivery_status)"]
    params: dict = {"st": payload.status.value, "id": delivery_id}
    if payload.status is DeliveryStatus.DELIVERED:
        assignments += [
            "delivered_at = now()",
            "cash_declared_xaf = :cash",
            "cash_declared_at = now()",
        ]
        params["cash"] = payload.cash_declared_xaf
    if payload.status is DeliveryStatus.FAILED:
        assignments.append("failure_reason_fr = :note")
        params["note"] = payload.note_fr

    await db.execute(
        text(f"UPDATE market.deliveries SET {', '.join(assignments)} WHERE id = :id"), params
    )
    await _timeline_push(db, delivery_id, payload.status.value, payload.note_fr)

    order_status = _ORDER_FROM_DELIVERY.get(payload.status)
    if order_status is not None:
        await db.execute(
            text("UPDATE market.orders SET status = CAST(:st AS shared.order_status) WHERE id = :id"),
            {"st": order_status.value, "id": row.order_id},
        )

    return {
        "id": str(delivery_id),
        "status": payload.status.value,
        "reference": row.reference,
        "ecart_xaf": ecart,
        "note": (
            "Somme déclarée par le livreur. MBOA n'a rien encaissé et ne certifie "
            "pas ce montant."
        )
        if payload.status is DeliveryStatus.DELIVERED
        else None,
    }
