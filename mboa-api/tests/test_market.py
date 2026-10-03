"""Tests de la place de marche : artisan, acheteur, livreur (SS45 a SS48).

Deux exigences dominent :

  - **l'argent ne passe pas par MBOA**, et la base le garantit : aucun statut
    « paye », aucun mode de reglement autre que l'espece a la remise ;
  - **un objet ne se reclame pas d'une culture qu'il n'a pas prouvee** : une
    affirmation culturelle sans fiche publiee derriere reste une declaration de
    l'artisan, affichee comme telle.
"""

import uuid

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError

from tests.test_cms import _make_user, client  # noqa: F401

pytestmark = pytest.mark.asyncio


async def _me(client, headers) -> dict:  # noqa: F811
    return (await client.get("/api/v1/auth/me", headers=headers)).json()


@pytest_asyncio.fixture
async def admin(client, session):  # noqa: F811
    return await _make_user(client, session, role="ADMIN")


@pytest_asyncio.fixture
async def acheteur(client, session):  # noqa: F811
    return await _make_user(client, session, role="LEARNER")


def _dossier(role: str, **overrides) -> dict:
    return {
        "requested_role": role,
        "activity_fr": "Je travaille le raphia depuis quinze ans et je vends sur le "
        "marche de ma ville.",
        "city": "Edea",
        "phone": "+237600000000",
        **overrides,
    }


async def _accepter(client, admin, application_id: str, **overrides):  # noqa: F811
    return await client.post(
        f"/api/v1/admin/market/applications/{application_id}/decision",
        headers=admin,
        json={
            "decision": "ACCEPT",
            "reason": "Rencontre sur place le 12 mars, atelier visite.",
            "verification_basis": "Carte nationale presentee en main propre, non conservee ; "
            "atelier visite en presence du president du GIC.",
            **overrides,
        },
    )


@pytest_asyncio.fixture
async def artisan(client, admin):  # noqa: F811
    """Un compte artisan, avec sa boutique ouverte."""
    headers = await _make_user_plain(client)
    depot = await client.post(
        "/api/v1/me/market-application", headers=headers, json=_dossier("ARTISAN")
    )
    await _accepter(client, admin, depot.json()["id"])
    await client.patch(
        "/api/v1/me/shop",
        headers=headers,
        json={
            "name": "Atelier de vannerie",
            "description_fr": "Paniers et nattes en raphia, tresses a la main.",
            "city": "Edea",
        },
    )
    await client.post("/api/v1/me/shop/open", headers=headers)
    return headers


@pytest_asyncio.fixture
async def livreur(client, admin):  # noqa: F811
    """Un compte livreur, disponible, qui dessert Edea."""
    headers = await _make_user_plain(client)
    depot = await client.post(
        "/api/v1/me/market-application",
        headers=headers,
        json=_dossier("COURIER", vehicle="MOTORCYCLE"),
    )
    await _accepter(client, admin, depot.json()["id"])
    await client.patch(
        "/api/v1/me/courier",
        headers=headers,
        json={"cities": ["Edea"], "is_available": True},
    )
    return headers


async def _make_user_plain(client):  # noqa: F811
    email = f"u-{uuid.uuid4().hex[:10]}@example.com"
    tokens = (
        await client.post(
            "/api/v1/auth/register",
            json={"email": email, "password": "motdepasse-solide", "display_name": "Test"},
        )
    ).json()
    return {"Authorization": f"Bearer {tokens['access_token']}"}


async def _produit(client, artisan, **overrides) -> str:  # noqa: F811
    created = await client.post(
        "/api/v1/me/shop/products",
        headers=artisan,
        json={
            "title_fr": "Panier en raphia",
            "description_fr": "Panier tresse a la main, environ 30 cm de diametre.",
            "category": "VANNERIE",
            "price_xaf": 12000,
            "stock": 3,
            **overrides,
        },
    )
    product_id = created.json()["id"]
    await client.post(f"/api/v1/me/shop/products/{product_id}/publish", headers=artisan)
    return product_id


async def _commander(client, acheteur, product_id, quantity=1) -> dict:  # noqa: F811
    response = await client.post(
        "/api/v1/me/orders",
        headers=acheteur,
        json={
            "product_id": product_id,
            "quantity": quantity,
            "delivery_city": "Edea",
            "delivery_address_fr": "Quartier Bilalang, face au marche.",
            "delivery_phone": "+237611111111",
        },
    )
    return response.json()


# ---------------------------------------------------------------------------
# Candidature et verification
# ---------------------------------------------------------------------------
async def test_le_dossier_ouvre_la_boutique(client, admin):  # noqa: F811
    headers = await _make_user_plain(client)

    # Avant toute decision, l'espace artisan est ferme.
    assert (await client.get("/api/v1/me/shop", headers=headers)).status_code == 403

    depot = await client.post(
        "/api/v1/me/market-application", headers=headers, json=_dossier("ARTISAN")
    )
    assert depot.status_code == 201
    reponse = await _accepter(client, admin, depot.json()["id"])
    assert reponse.status_code == 200
    assert "boutique" in reponse.json()["cree"]

    assert (await _me(client, headers))["role"] == "ARTISAN"
    espace = await client.get("/api/v1/me/shop", headers=headers)
    assert espace.status_code == 200
    assert espace.json()["boutique"]["status"] == "DRAFT"


async def test_accepter_exige_de_dire_ce_qui_a_ete_verifie(client, admin):  # noqa: F811
    """Une habilitation sans base verifiable n'en est pas une."""
    headers = await _make_user_plain(client)
    depot = await client.post(
        "/api/v1/me/market-application", headers=headers, json=_dossier("ARTISAN")
    )
    response = await client.post(
        f"/api/v1/admin/market/applications/{depot.json()['id']}/decision",
        headers=admin,
        json={"decision": "ACCEPT", "reason": "Dossier correct, rien a signaler."},
    )
    assert response.status_code == 422
    assert "verifie" in response.json()["detail"]


async def test_la_verification_est_consignee_au_journal(client, admin):  # noqa: F811
    headers = await _make_user_plain(client)
    depot = await client.post(
        "/api/v1/me/market-application",
        headers=headers,
        json=_dossier("COURIER", vehicle="BICYCLE"),
    )
    application_id = depot.json()["id"]
    await _accepter(client, admin, application_id)

    # On cible ce dossier : la base de test est partagee entre les tests.
    journal = (
        await client.get(f"/api/v1/admin/audit?target_id={application_id}", headers=admin)
    ).json()
    assert journal[0]["action"] == "MARKET_APPLICATION_ACCEPTED"
    assert "COURIER" in journal[0]["target_label"]
    assert "non conservee" in journal[0]["details"]["verification"]


async def test_un_dossier_de_livreur_precise_le_vehicule(client):  # noqa: F811
    headers = await _make_user_plain(client)
    response = await client.post(
        "/api/v1/me/market-application", headers=headers, json=_dossier("COURIER")
    )
    assert response.status_code == 422


async def test_deux_dossiers_simultanes_sont_refuses(client):  # noqa: F811
    headers = await _make_user_plain(client)
    assert (
        await client.post(
            "/api/v1/me/market-application", headers=headers, json=_dossier("ARTISAN")
        )
    ).status_code == 201
    assert (
        await client.post(
            "/api/v1/me/market-application", headers=headers, json=_dossier("ARTISAN")
        )
    ).status_code == 409


# ---------------------------------------------------------------------------
# Boutique et produits
# ---------------------------------------------------------------------------
async def test_une_boutique_sans_description_ne_s_ouvre_pas(client, admin):  # noqa: F811
    """Un acheteur doit savoir qui il a en face et d'ou part le colis."""
    headers = await _make_user_plain(client)
    depot = await client.post(
        "/api/v1/me/market-application", headers=headers, json=_dossier("ARTISAN")
    )
    await _accepter(client, admin, depot.json()["id"])

    response = await client.post("/api/v1/me/shop/open", headers=headers)
    assert response.status_code == 409
    assert "description" in response.json()["detail"]


async def test_un_produit_sans_stock_ne_se_publie_pas(client, artisan):  # noqa: F811
    created = await client.post(
        "/api/v1/me/shop/products",
        headers=artisan,
        json={
            "title_fr": "Natte en raphia",
            "description_fr": "Natte tressee, deux metres.",
            "category": "VANNERIE",
            "price_xaf": 25000,
            "stock": 0,
        },
    )
    response = await client.post(
        f"/api/v1/me/shop/products/{created.json()['id']}/publish", headers=artisan
    )
    assert response.status_code == 409
    assert "stock" in response.json()["detail"]


async def test_une_affirmation_culturelle_sans_source_reste_une_declaration(
    client, artisan  # noqa: F811
):
    """Le coeur du sujet : MBOA n'endosse pas l'affirmation de l'artisan."""
    created = await client.post(
        "/api/v1/me/shop/products",
        headers=artisan,
        json={
            "title_fr": "Masque de danse",
            "description_fr": "Masque sculpte dans du bois d'iroko.",
            "category": "SCULPTURE",
            "price_xaf": 45000,
            "stock": 1,
            "cultural_claim_fr": "Masque utilise lors des ceremonies d'initiation.",
        },
    )
    assert created.status_code == 201
    assert created.json()["cultural_claim_status"] == "ARTISAN_DECLARATION"


async def test_une_fiche_non_publiee_ne_peut_pas_servir_de_caution(
    client, session, artisan, fixture_ids  # noqa: F811
):
    """Se reclamer d'une fiche en brouillon reviendrait a fabriquer une source."""
    category_id = (
        await session.execute(
            text("SELECT id FROM culture.cultural_categories LIMIT 1")
        )
    ).scalar_one_or_none()
    if category_id is None:
        category_id = uuid.uuid4()
        await session.execute(
            text(
                """
                INSERT INTO culture.cultural_categories (id, code, name_fr, position)
                VALUES (:id, 'CRAFTS', 'Artisanat', 9)
                """
            ),
            {"id": category_id},
        )
    content_id = uuid.uuid4()
    await session.execute(
        text(
            """
            INSERT INTO culture.cultural_contents
                (id, category_id, title_fr, summary_fr, status, source_id, created_by)
            VALUES (:id, :cat, 'Fiche en brouillon', 'Resume', 'DRAFT', :src, :by)
            """
        ),
        {
            "id": content_id,
            "cat": category_id,
            "src": fixture_ids["source"],
            "by": fixture_ids["author"],
        },
    )
    await session.commit()

    response = await client.post(
        "/api/v1/me/shop/products",
        headers=artisan,
        json={
            "title_fr": "Statuette",
            "description_fr": "Statuette sculptee.",
            "category": "SCULPTURE",
            "price_xaf": 30000,
            "stock": 1,
            "cultural_claim_fr": "Objet rituel decrit dans nos fiches.",
            "cultural_content_id": str(content_id),
        },
    )
    assert response.status_code == 409
    assert "pas publiee" in response.json()["detail"]


async def test_la_base_refuse_un_rattachement_force(
    client, session, artisan  # noqa: F811
):
    """Meme en contournant l'API, le trigger tient."""
    shop_id = (
        await session.execute(
            text(
                """
                SELECT s.id FROM market.shops s
                JOIN market.products p ON p.shop_id = s.id LIMIT 1
                """
            )
        )
    ).scalar_one_or_none()
    if shop_id is None:
        await _produit(client, artisan)
        shop_id = (
            await session.execute(text("SELECT id FROM market.shops LIMIT 1"))
        ).scalar_one()

    with pytest.raises(DBAPIError) as erreur:
        await session.execute(
            text(
                """
                INSERT INTO market.products
                    (id, shop_id, title_fr, category, price_xaf, stock,
                     cultural_claim_fr, cultural_claim_status, cultural_content_id)
                VALUES (:id, :sid, 'Objet', 'AUTRE', 1000, 1,
                        'Piece ceremonielle attestee', 'LINKED_TO_SOURCE', NULL)
                """
            ),
            {"id": uuid.uuid4(), "sid": shop_id},
        )
    assert "MBOA[rattachement_absent]" in str(erreur.value)
    await session.rollback()


async def test_le_catalogue_ne_montre_que_les_boutiques_ouvertes(
    client, artisan, acheteur  # noqa: F811
):
    product_id = await _produit(client, artisan)
    catalogue = (await client.get("/api/v1/market/products")).json()
    assert product_id in {p["id"] for p in catalogue["items"]}
    assert "espèces" in catalogue["reglement"]

    await client.post("/api/v1/me/shop/close", headers=artisan)
    apres = (await client.get("/api/v1/market/products")).json()
    assert product_id not in {p["id"] for p in apres["items"]}


# ---------------------------------------------------------------------------
# L'argent ne passe pas par MBOA
# ---------------------------------------------------------------------------
async def test_la_base_refuse_de_declarer_une_commande_payee(
    client, session, artisan, acheteur  # noqa: F811
):
    product_id = await _produit(client, artisan)
    commande = await _commander(client, acheteur, product_id)

    with pytest.raises(DBAPIError) as erreur:
        await session.execute(
            text("UPDATE market.orders SET status = 'PAID' WHERE id = :id"),
            {"id": commande["id"]},
        )
    assert "MBOA[encaissement_absent]" in str(erreur.value)
    await session.rollback()


async def test_la_base_refuse_un_mode_de_paiement_non_branche(
    client, session, artisan, acheteur  # noqa: F811
):
    """Un bouton « mobile money » qui ne debiterait rien ferait perdre de l'argent."""
    product_id = await _produit(client, artisan)
    commande = await _commander(client, acheteur, product_id)

    with pytest.raises(DBAPIError) as erreur:
        await session.execute(
            text("UPDATE market.orders SET payment_mode = 'MOBILE_MONEY' WHERE id = :id"),
            {"id": commande["id"]},
        )
    assert "MBOA[mode_de_paiement_non_branche]" in str(erreur.value)
    await session.rollback()


async def test_le_reglement_est_annonce_a_chaque_etape(
    client, artisan, acheteur  # noqa: F811
):
    product_id = await _produit(client, artisan)
    assert "espèces" in (await client.get("/api/v1/market/products")).json()["reglement"]
    assert "espèces" in (
        await client.get(f"/api/v1/market/products/{product_id}")
    ).json()["reglement"]
    commande = await _commander(client, acheteur, product_id)
    assert "n'encaisse rien" in commande["reglement"]


# ---------------------------------------------------------------------------
# Commande
# ---------------------------------------------------------------------------
async def test_commander_immobilise_le_stock(client, artisan, acheteur):  # noqa: F811
    product_id = await _produit(client, artisan)
    await _commander(client, acheteur, product_id, quantity=2)

    produits = (await client.get("/api/v1/me/shop/products", headers=artisan)).json()
    restant = next(p for p in produits if p["id"] == product_id)
    assert restant["stock"] == 1


async def test_un_stock_insuffisant_est_refuse(client, artisan, acheteur):  # noqa: F811
    product_id = await _produit(client, artisan)
    response = await client.post(
        "/api/v1/me/orders",
        headers=acheteur,
        json={
            "product_id": product_id,
            "quantity": 9,
            "delivery_city": "Edea",
            "delivery_address_fr": "Quartier Bilalang.",
            "delivery_phone": "+237611111111",
        },
    )
    assert response.status_code == 409
    assert "il reste 3" in response.json()["detail"]


async def test_annuler_rend_le_stock(client, artisan, acheteur):  # noqa: F811
    product_id = await _produit(client, artisan)
    commande = await _commander(client, acheteur, product_id, quantity=2)

    annulation = await client.post(
        f"/api/v1/me/orders/{commande['id']}/cancel",
        headers=acheteur,
        json={"reason": "Je me suis trompe de taille."},
    )
    assert annulation.status_code == 200

    produits = (await client.get("/api/v1/me/shop/products", headers=artisan)).json()
    assert next(p for p in produits if p["id"] == product_id)["stock"] == 3


async def test_on_ne_commande_pas_dans_sa_propre_boutique(client, artisan):  # noqa: F811
    product_id = await _produit(client, artisan)
    response = await client.post(
        "/api/v1/me/orders",
        headers=artisan,
        json={
            "product_id": product_id,
            "quantity": 1,
            "delivery_city": "Edea",
            "delivery_address_fr": "Chez moi.",
            "delivery_phone": "+237611111111",
        },
    )
    assert response.status_code == 400


async def test_la_ligne_de_commande_fige_le_prix(
    client, artisan, acheteur  # noqa: F811
):
    """Changer son tarif ne reecrit pas une commande passee."""
    product_id = await _produit(client, artisan)
    await _commander(client, acheteur, product_id)

    await client.patch(
        f"/api/v1/me/shop/products/{product_id}",
        headers=artisan,
        json={"price_xaf": 99000},
    )
    commandes = (await client.get("/api/v1/me/orders", headers=acheteur)).json()["items"]
    assert commandes[0]["lignes"][0]["unit_price_xaf"] == 12000
    assert commandes[0]["total_xaf"] == 12000


# ---------------------------------------------------------------------------
# Livraison
# ---------------------------------------------------------------------------
async def test_le_circuit_complet_jusqu_a_la_remise(
    client, artisan, acheteur, livreur  # noqa: F811
):
    """De la commande a la remise, sans qu'un franc passe par MBOA."""
    product_id = await _produit(client, artisan)
    commande = await _commander(client, acheteur, product_id)

    # La course n'est pas encore visible : le colis n'est pas pret.
    assert (await client.get("/api/v1/me/courier/available", headers=livreur)).json()[
        "items"
    ] == []

    assert (
        await client.post(
            f"/api/v1/me/shop/orders/{commande['id']}/confirm", headers=artisan
        )
    ).status_code == 200
    assert (
        await client.post(f"/api/v1/me/shop/orders/{commande['id']}/ready", headers=artisan)
    ).status_code == 200

    courses = (await client.get("/api/v1/me/courier/available", headers=livreur)).json()
    course = next(c for c in courses["items"] if c["reference"] == commande["reference"])

    assert (
        await client.post(
            f"/api/v1/me/courier/deliveries/{course['id']}/accept", headers=livreur
        )
    ).status_code == 200

    for etape in ("PICKED_UP", "IN_TRANSIT"):
        assert (
            await client.post(
                f"/api/v1/me/courier/deliveries/{course['id']}/status",
                headers=livreur,
                json={"status": etape},
            )
        ).status_code == 200

    remise = await client.post(
        f"/api/v1/me/courier/deliveries/{course['id']}/status",
        headers=livreur,
        json={"status": "DELIVERED", "cash_declared_xaf": 12000},
    )
    assert remise.status_code == 200
    assert remise.json()["ecart_xaf"] == 0
    assert "n'a rien encaissé" in remise.json()["note"]

    suivi = (await client.get("/api/v1/me/orders", headers=acheteur)).json()["items"][0]
    assert suivi["status"] == "DELIVERED"
    assert suivi["delivery_status"] == "DELIVERED"
    # Le suivi est lu, pas reconstitue.
    assert [e["status"] for e in suivi["timeline"]] == [
        "ASSIGNED",
        "PICKED_UP",
        "IN_TRANSIT",
        "DELIVERED",
    ]


async def test_une_remise_sans_somme_declaree_est_refusee(
    client, artisan, acheteur, livreur  # noqa: F811
):
    course = await _course_prete(client, artisan, acheteur, livreur)
    for etape in ("PICKED_UP", "IN_TRANSIT"):
        await client.post(
            f"/api/v1/me/courier/deliveries/{course['id']}/status",
            headers=livreur,
            json={"status": etape},
        )
    response = await client.post(
        f"/api/v1/me/courier/deliveries/{course['id']}/status",
        headers=livreur,
        json={"status": "DELIVERED"},
    )
    assert response.status_code == 422
    assert "somme recue" in response.json()["detail"]


async def test_un_ecart_de_caisse_doit_etre_explique(
    client, artisan, acheteur, livreur  # noqa: F811
):
    """Une difference silencieuse serait un litige que personne ne verrait."""
    course = await _course_prete(client, artisan, acheteur, livreur)
    for etape in ("PICKED_UP", "IN_TRANSIT"):
        await client.post(
            f"/api/v1/me/courier/deliveries/{course['id']}/status",
            headers=livreur,
            json={"status": etape},
        )

    sans_motif = await client.post(
        f"/api/v1/me/courier/deliveries/{course['id']}/status",
        headers=livreur,
        json={"status": "DELIVERED", "cash_declared_xaf": 10000},
    )
    assert sans_motif.status_code == 422
    assert "-2000" in sans_motif.json()["detail"]

    avec_motif = await client.post(
        f"/api/v1/me/courier/deliveries/{course['id']}/status",
        headers=livreur,
        json={
            "status": "DELIVERED",
            "cash_declared_xaf": 10000,
            "note_fr": "Le client n'avait pas l'appoint ; solde convenu avec l'artisan.",
        },
    )
    assert avec_motif.status_code == 200
    assert avec_motif.json()["ecart_xaf"] == -2000


async def test_un_livreur_ne_prend_pas_une_course_hors_de_ses_villes(
    client, artisan, acheteur, livreur  # noqa: F811
):
    course = await _course_prete(client, artisan, acheteur, livreur)
    await client.patch(
        "/api/v1/me/courier", headers=livreur, json={"cities": ["Garoua"]}
    )
    # Une course deja prise n'est plus reprenable ; on en cree une autre.
    product_id = await _produit(client, artisan)
    commande = await _commander(client, acheteur, product_id)
    await client.post(f"/api/v1/me/shop/orders/{commande['id']}/confirm", headers=artisan)
    await client.post(f"/api/v1/me/shop/orders/{commande['id']}/ready", headers=artisan)

    delivery_id = (
        await client.get("/api/v1/me/courier/deliveries", headers=livreur)
    ).json()
    assert course["id"] in {d["id"] for d in delivery_id}

    disponibles = (await client.get("/api/v1/me/courier/available", headers=livreur)).json()
    assert disponibles["items"] == []


async def test_un_livreur_indisponible_ne_voit_aucune_course(
    client, artisan, acheteur, livreur  # noqa: F811
):
    await _course_prete(client, artisan, acheteur, livreur, accepter=False)
    await client.patch("/api/v1/me/courier", headers=livreur, json={"is_available": False})

    reponse = (await client.get("/api/v1/me/courier/available", headers=livreur)).json()
    assert reponse["items"] == []
    assert "indisponible" in reponse["message"]


async def test_les_etapes_ne_se_sautent_pas(
    client, artisan, acheteur, livreur  # noqa: F811
):
    course = await _course_prete(client, artisan, acheteur, livreur)
    response = await client.post(
        f"/api/v1/me/courier/deliveries/{course['id']}/status",
        headers=livreur,
        json={"status": "DELIVERED", "cash_declared_xaf": 12000},
    )
    assert response.status_code == 409
    assert "ASSIGNED" in response.json()["detail"]


async def test_une_course_echouee_s_explique(
    client, artisan, acheteur, livreur  # noqa: F811
):
    course = await _course_prete(client, artisan, acheteur, livreur)
    sans_motif = await client.post(
        f"/api/v1/me/courier/deliveries/{course['id']}/status",
        headers=livreur,
        json={"status": "FAILED"},
    )
    assert sans_motif.status_code == 422

    avec_motif = await client.post(
        f"/api/v1/me/courier/deliveries/{course['id']}/status",
        headers=livreur,
        json={"status": "FAILED", "note_fr": "Adresse introuvable, client injoignable."},
    )
    assert avec_motif.status_code == 200


async def test_l_espace_livreur_est_ferme_aux_autres(client, acheteur):  # noqa: F811
    assert (await client.get("/api/v1/me/courier", headers=acheteur)).status_code == 403


async def _course_prete(client, artisan, acheteur, livreur, accepter=True):  # noqa: F811
    """Commande confirmee, colis pret, course eventuellement acceptee."""
    product_id = await _produit(client, artisan)
    commande = await _commander(client, acheteur, product_id)
    await client.post(f"/api/v1/me/shop/orders/{commande['id']}/confirm", headers=artisan)
    await client.post(f"/api/v1/me/shop/orders/{commande['id']}/ready", headers=artisan)

    courses = (await client.get("/api/v1/me/courier/available", headers=livreur)).json()
    course = next(c for c in courses["items"] if c["reference"] == commande["reference"])
    if accepter:
        await client.post(
            f"/api/v1/me/courier/deliveries/{course['id']}/accept", headers=livreur
        )
    return course
