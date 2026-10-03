"""Deroule la place de marche de bout en bout, par l'API.

Un artisan ouvre boutique, un acheteur commande, un livreur remet le colis. Le
script montre surtout ce que la plateforme REFUSE : declarer une commande payee,
accepter un mode de reglement non branche, et endosser une affirmation
culturelle que rien ne documente.

Prerequis : l'API tourne sur http://127.0.0.1:8010

Usage :
    python -m scripts.demo_marche
"""

from __future__ import annotations

import asyncio
import sys
import uuid

import httpx

BASE = "http://127.0.0.1:8010/api/v1"
PASSWORD = "motdepasse-solide"


def titre(text: str) -> None:
    print(f"\n{text}")
    print("-" * len(text))


async def register(client: httpx.AsyncClient, display_name: str) -> tuple[str, dict]:
    email = f"demo-{uuid.uuid4().hex[:8]}@example.org"
    response = await client.post(
        "/auth/register",
        json={"email": email, "password": PASSWORD, "display_name": display_name},
    )
    response.raise_for_status()
    return email, {"Authorization": f"Bearer {response.json()['access_token']}"}


async def main() -> int:
    async with httpx.AsyncClient(base_url=BASE, timeout=20) as client:
        try:
            await client.get("/market/categories")
        except httpx.ConnectError:
            print("[erreur] l'API ne repond pas sur http://127.0.0.1:8010")
            return 1

        # ------------------------------------------------------- les comptes
        titre("1. Quatre comptes ordinaires")
        admin_email, admin = await register(client, "Administratrice")
        artisan_email, artisan = await register(client, "Ngo Bassong")
        acheteur_email, acheteur = await register(client, "Ama")
        livreur_email, livreur = await register(client, "Moussa")

        from sqlalchemy import text

        from app.core.db import SessionLocal

        # Le premier administrateur se designe hors API, comme en production
        # (cf. scripts.grant_admin).
        async with SessionLocal() as db:
            await db.execute(
                text("UPDATE iam.users SET role = 'ADMIN' WHERE email = :e"),
                {"e": admin_email},
            )
            await db.commit()
        print(f"   artisan  : {artisan_email}")
        print(f"   acheteur : {acheteur_email}")
        print(f"   livreur  : {livreur_email}")

        # --------------------------------------------------- les habilitations
        titre("2. Deux dossiers, verifies hors ligne")
        dossiers = {}
        for role, headers, extra in (
            ("ARTISAN", artisan, {}),
            ("COURIER", livreur, {"vehicle": "MOTORCYCLE"}),
        ):
            depot = await client.post(
                "/me/market-application",
                headers=headers,
                json={
                    "requested_role": role,
                    "activity_fr": "Activite declaree pour la demonstration, avec "
                    "assez de detail pour etre examinee.",
                    "city": "Edea",
                    "phone": "+237600000000",
                    **extra,
                },
            )
            depot.raise_for_status()
            dossiers[role] = depot.json()["id"]

        sans_base = await client.post(
            f"/admin/market/applications/{dossiers['ARTISAN']}/decision",
            headers=admin,
            json={"decision": "ACCEPT", "reason": "Dossier correct."},
        )
        print(f"   acceptation sans base verifiable -> {sans_base.status_code} (refuse)")

        for role in ("ARTISAN", "COURIER"):
            decision = await client.post(
                f"/admin/market/applications/{dossiers[role]}/decision",
                headers=admin,
                json={
                    "decision": "ACCEPT",
                    "reason": "Rencontre sur place, activite constatee.",
                    "verification_basis": "Piece d'identite presentee en main propre, "
                    "non conservee ; atelier visite.",
                },
            )
            decision.raise_for_status()
            print(f"   {role:<8} habilite -> {decision.json()['cree']}")

        # -------------------------------------------------------- la boutique
        titre("3. La boutique ouvre")
        await client.patch(
            "/me/shop",
            headers=artisan,
            json={
                "name": "Atelier de vannerie",
                "description_fr": "Paniers et nattes en raphia, tresses a la main.",
                "city": "Edea",
            },
        )
        ouverture = await client.post("/me/shop/open", headers=artisan)
        print(f"   POST /me/shop/open -> {ouverture.status_code}")

        # ------------------------------------- l'affirmation culturelle (SS3)
        titre("4. Un objet qui affirme quelque chose")
        produit = await client.post(
            "/me/shop/products",
            headers=artisan,
            json={
                "title_fr": "Panier en raphia",
                "description_fr": "Panier tresse a la main, environ 30 cm.",
                "category": "VANNERIE",
                "price_xaf": 12000,
                "stock": 3,
                "cultural_claim_fr": "Panier utilise pour le transport des recoltes.",
            },
        )
        produit.raise_for_status()
        product_id = produit.json()["id"]
        print(f"   statut de l'affirmation : {produit.json()['cultural_claim_status']}")
        print("   -> MBOA l'affiche comme une declaration du vendeur, pas comme un fait.")
        await client.post(f"/me/shop/products/{product_id}/publish", headers=artisan)

        # -------------------------------------------------------- la commande
        titre("5. La commande")
        commande = await client.post(
            "/me/orders",
            headers=acheteur,
            json={
                "product_id": product_id,
                "quantity": 1,
                "delivery_city": "Edea",
                "delivery_address_fr": "Quartier Bilalang, face au marche.",
                "delivery_phone": "+237611111111",
            },
        )
        commande.raise_for_status()
        order = commande.json()
        print(f"   {order['reference']} — {order['total_xaf']} FCFA")
        print(f"   {order['reglement']}")

        async with SessionLocal() as db:
            for champ, valeur, attendu in (
                ("status", "PAID", "MBOA[encaissement_absent]"),
                ("payment_mode", "MOBILE_MONEY", "MBOA[mode_de_paiement_non_branche]"),
            ):
                try:
                    await db.execute(
                        text(
                            f"UPDATE market.orders SET {champ} = "
                            f"CAST(:v AS shared.{'order_status' if champ == 'status' else 'payment_mode'}) "
                            "WHERE id = :id"
                        ),
                        {"v": valeur, "id": order["id"]},
                    )
                    print(f"   [!] {champ} = {valeur} a ete accepte : anomalie")
                except Exception as exc:  # noqa: BLE001
                    marque = attendu in str(exc)
                    print(f"   {champ} = {valeur:<14} -> refuse par la base ({attendu})"
                          if marque else f"   [!] refus inattendu : {exc}")
                    await db.rollback()

        # ------------------------------------------------------- la livraison
        titre("6. De l'atelier au client")
        await client.post(f"/me/shop/orders/{order['id']}/confirm", headers=artisan)
        await client.post(f"/me/shop/orders/{order['id']}/ready", headers=artisan)
        await client.patch(
            "/me/courier", headers=livreur, json={"cities": ["Edea"], "is_available": True}
        )

        courses = (await client.get("/me/courier/available", headers=livreur)).json()
        course = next(c for c in courses["items"] if c["reference"] == order["reference"])
        await client.post(f"/me/courier/deliveries/{course['id']}/accept", headers=livreur)
        for etape in ("PICKED_UP", "IN_TRANSIT"):
            await client.post(
                f"/me/courier/deliveries/{course['id']}/status",
                headers=livreur,
                json={"status": etape},
            )

        ecart = await client.post(
            f"/me/courier/deliveries/{course['id']}/status",
            headers=livreur,
            json={"status": "DELIVERED", "cash_declared_xaf": 10000},
        )
        print(f"   remise avec 2 000 FCFA manquants et sans explication -> "
              f"{ecart.status_code} (refuse)")

        remise = await client.post(
            f"/me/courier/deliveries/{course['id']}/status",
            headers=livreur,
            json={"status": "DELIVERED", "cash_declared_xaf": 12000},
        )
        remise.raise_for_status()
        print(f"   remise confirmee — ecart : {remise.json()['ecart_xaf']} FCFA")
        print(f"   {remise.json()['note']}")

        # ---------------------------------------------------------- le suivi
        titre("7. Ce que l'acheteur voit")
        suivi = (await client.get("/me/orders", headers=acheteur)).json()["items"][0]
        print(f"   {suivi['reference']} — {suivi['status']}")
        for etape in suivi["timeline"]:
            print(f"     {etape['at'][:16].replace('T', ' ')}  {etape['status']}")

    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
