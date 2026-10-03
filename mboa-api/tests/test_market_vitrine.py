"""La boutique comme place de marche : photos, avis, caisse de demonstration.

Ces trois ajouts repondent a une demande explicite : une grille de produits
avec leurs photos, un paiement essayable, des avis. Chacun porte une limite que
ces tests fixent, parce qu'elle est facile a perdre de vue en cours de route :

  - **aucune photo n'est fournie par MBOA.** Un objet artisanal est unique ;
    une illustration generique ferait croire a l'acheteur qu'il achete autre
    chose. Un produit sans photo s'affiche sans photo.
  - **une simulation reste une simulation.** Le circuit d'achat va jusqu'au
    bout sans qu'un franc ne bouge, et la base refuse de laisser effacer la
    marque : un artisan ne doit jamais preparer un colis en croyant avoir ete
    paye.
  - **un avis n'est pas une source.** On note un objet vendu, jamais un fait de
    langue ou de culture.
"""

import uuid

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError

from tests.test_cms import client  # noqa: F401
from tests.test_culture import creer_fiche, rubrique  # noqa: F401
from tests.test_culture_regions import publier  # noqa: F401
from tests.test_market import (  # noqa: F401
    _commander,
    _make_user_plain,
    _produit,
    acheteur,
    admin,
    artisan,
)

pytestmark = pytest.mark.asyncio

#: Un PNG 1x1 valide : assez pour verifier que la signature est bien lue.
PNG_1x1 = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4"
    "890000000a49444154789c6300010000050001" "0d0a2db40000000049454e44ae426082"
)


@pytest_asyncio.fixture
async def produit_publie(client, artisan):  # noqa: F811
    return await _produit(client, artisan)


# ---------------------------------------------------------------------------
# Photos
# ---------------------------------------------------------------------------
async def test_une_photo_deposee_ressort_dans_le_catalogue(
    client, artisan, produit_publie  # noqa: F811
):
    depot = await client.post(
        f"/api/v1/shop/products/{produit_publie}/images",
        headers=artisan,
        files={"file": ("panier.png", PNG_1x1, "image/png")},
    )
    assert depot.status_code == 201, depot.text
    url = depot.json()["url"]

    catalogue = (await client.get("/api/v1/market/products")).json()
    produit = next(p for p in catalogue["items"] if p["id"] == produit_publie)
    assert [image["url"] for image in produit["images"]] == [url]

    # Et le fichier se sert vraiment.
    servi = await client.get(url)
    assert servi.status_code == 200
    assert servi.content == PNG_1x1


async def test_un_produit_sans_photo_n_en_recoit_pas_une_d_emprunt(
    client, produit_publie  # noqa: F811
):
    """MBOA ne bouche pas un trou avec une image generique."""
    catalogue = (await client.get("/api/v1/market/products")).json()
    produit = next(p for p in catalogue["items"] if p["id"] == produit_publie)
    assert produit["images"] == []
    assert produit["image_url"] is None


async def test_un_fichier_qui_n_est_pas_une_image_est_refuse(
    client, artisan, produit_publie  # noqa: F811
):
    """Le type est lu dans les octets, pas dans le nom ni dans l'en-tete."""
    reponse = await client.post(
        f"/api/v1/shop/products/{produit_publie}/images",
        headers=artisan,
        # Le nom et le content-type annoncent une image ; le contenu, non.
        files={"file": ("piege.png", b"#!/bin/sh\nrm -rf /\n", "image/png")},
    )
    assert reponse.status_code == 415


async def test_on_ne_depose_pas_de_photo_chez_un_autre(
    client, produit_publie  # noqa: F811
):
    intrus = await _make_user_plain(client)
    reponse = await client.post(
        f"/api/v1/shop/products/{produit_publie}/images",
        headers=intrus,
        files={"file": ("panier.png", PNG_1x1, "image/png")},
    )
    # Sans boutique, l'acces est refuse avant meme la question du produit.
    assert reponse.status_code in (403, 404)


async def test_une_photo_retiree_disparait_du_disque(
    client, artisan, produit_publie  # noqa: F811
):
    depot = await client.post(
        f"/api/v1/shop/products/{produit_publie}/images",
        headers=artisan,
        files={"file": ("panier.png", PNG_1x1, "image/png")},
    )
    image_id, url = depot.json()["id"], depot.json()["url"]

    suppression = await client.delete(
        f"/api/v1/shop/products/{produit_publie}/images/{image_id}", headers=artisan
    )
    assert suppression.status_code == 200
    assert (await client.get(url)).status_code == 404


# ---------------------------------------------------------------------------
# Caisse de demonstration
# ---------------------------------------------------------------------------
async def test_le_paiement_simule_va_au_bout_sans_deplacer_d_argent(
    client, acheteur, produit_publie, session  # noqa: F811
):
    reponse = await client.post(
        "/api/v1/me/orders",
        headers=acheteur,
        json={
            "product_id": produit_publie,
            "quantity": 1,
            "delivery_city": "Edea",
            "delivery_address_fr": "Quartier Bilalang, face au marche.",
            "delivery_phone": "+237611111111",
            "payment_mode": "SIMULATION",
        },
    )
    assert reponse.status_code == 201, reponse.text
    commande = reponse.json()
    assert commande["payment_mode"] == "SIMULATION"
    # La mention doit etre sans ambiguite, cote acheteur comme cote artisan.
    assert "simulé" in commande["reglement"].lower()
    assert "aucun argent" in commande["reglement"].lower()

    # Le statut reste celui d'une commande a confirmer : simuler un reglement
    # ne dispense pas l'artisan d'accepter.
    assert commande["status"] == "PENDING_CONFIRMATION"

    horodatage = (
        await session.execute(
            text("SELECT simulated_paid_at FROM market.orders WHERE id = :id"),
            {"id": uuid.UUID(commande["id"])},
        )
    ).scalar_one()
    assert horodatage is not None


async def test_l_artisan_voit_qu_une_commande_est_une_demonstration(
    client, acheteur, artisan, produit_publie  # noqa: F811
):
    """C'est lui qui prepare le colis : il doit le savoir avant."""
    await client.post(
        "/api/v1/me/orders",
        headers=acheteur,
        json={
            "product_id": produit_publie,
            "quantity": 1,
            "delivery_city": "Edea",
            "delivery_address_fr": "Quartier Bilalang, face au marche.",
            "delivery_phone": "+237611111111",
            "payment_mode": "SIMULATION",
        },
    )
    recues = (await client.get("/api/v1/me/shop/orders", headers=artisan)).json()
    commande = recues["items"][0]
    assert commande["payment_mode"] == "SIMULATION"
    assert "Ne préparez pas d'envoi réel" in commande["reglement"]


async def test_une_commande_reelle_garde_la_mention_especes(
    client, acheteur, produit_publie  # noqa: F811
):
    commande = await _commander(client, acheteur, produit_publie)
    assert commande["payment_mode"] == "CASH_ON_DELIVERY"
    assert "espèces" in commande["reglement"]
    assert "simulé" not in commande["reglement"].lower()


async def test_une_simulation_ne_peut_pas_se_faire_passer_pour_une_vente(
    client, acheteur, produit_publie, session  # noqa: F811
):
    """La marque est indelebile, et la base le fait respecter."""
    reponse = await client.post(
        "/api/v1/me/orders",
        headers=acheteur,
        json={
            "product_id": produit_publie,
            "quantity": 1,
            "delivery_city": "Edea",
            "delivery_address_fr": "Quartier Bilalang, face au marche.",
            "delivery_phone": "+237611111111",
            "payment_mode": "SIMULATION",
        },
    )
    order_id = uuid.UUID(reponse.json()["id"])

    with pytest.raises(DBAPIError) as leve:
        await session.execute(
            text("UPDATE market.orders SET simulated_paid_at = NULL WHERE id = :id"),
            {"id": order_id},
        )
    assert "MBOA[simulation_indelebile]" in str(leve.value)
    await session.rollback()


async def test_un_mode_de_paiement_non_branche_reste_refuse(
    client, acheteur, produit_publie  # noqa: F811
):
    """Ouvrir la simulation n'ouvre pas le mobile money."""
    reponse = await client.post(
        "/api/v1/me/orders",
        headers=acheteur,
        json={
            "product_id": produit_publie,
            "quantity": 1,
            "delivery_city": "Edea",
            "delivery_address_fr": "Quartier Bilalang, face au marche.",
            "delivery_phone": "+237611111111",
            "payment_mode": "MOBILE_MONEY",
        },
    )
    assert reponse.status_code == 422


# ---------------------------------------------------------------------------
# Avis
# ---------------------------------------------------------------------------
async def test_un_avis_note_un_objet_et_ressort_dans_le_catalogue(
    client, acheteur, produit_publie  # noqa: F811
):
    depot = await client.post(
        f"/api/v1/social/PRODUCT/{produit_publie}/comments",
        headers=acheteur,
        json={"body_fr": "Le tressage est serré, le panier tient bien.", "rating": 4},
    )
    assert depot.status_code == 201, depot.text
    assert depot.json()["rating"] == 4

    lus = (await client.get(f"/api/v1/social/PRODUCT/{produit_publie}/comments")).json()
    assert lus["note_moyenne"] == 4.0
    assert lus["votants"] == 1
    assert lus["notable"] is True
    # L'avertissement voyage avec les avis : il ne doit pas dependre de l'ecran.
    assert "ni vérifiés" in lus["avertissement"]

    catalogue = (await client.get("/api/v1/market/products")).json()
    produit = next(p for p in catalogue["items"] if p["id"] == produit_publie)
    assert float(produit["note_moyenne"]) == 4.0
    assert produit["avis"] == 1


async def test_on_ne_note_pas_un_fait_culturel(
    client, acheteur, creer_fiche, publier  # noqa: F811
):
    """Une note mesure une appreciation, pas l'exactitude de ce qui est etabli."""
    fiche = await creer_fiche("DRAFT")
    await publier(fiche)

    notee = await client.post(
        f"/api/v1/social/CULTURAL_CONTENT/{fiche}/comments",
        headers=acheteur,
        json={"body_fr": "Fiche très claire, merci.", "rating": 5},
    )
    assert notee.status_code == 422
    assert "exactitude" in notee.json()["detail"]

    # Le commentaire seul, lui, est accepte.
    simple = await client.post(
        f"/api/v1/social/CULTURAL_CONTENT/{fiche}/comments",
        headers=acheteur,
        json={"body_fr": "Fiche très claire, merci."},
    )
    assert simple.status_code == 201
    assert simple.json()["rating"] is None


async def test_on_ne_commente_pas_ce_qui_n_est_pas_publie(
    client, acheteur, artisan  # noqa: F811
):
    brouillon = (
        await client.post(
            "/api/v1/me/shop/products",
            headers=artisan,
            json={
                "title_fr": "Natte non publiee",
                "category": "VANNERIE",
                "price_xaf": 5000,
                "stock": 1,
            },
        )
    ).json()["id"]

    reponse = await client.post(
        f"/api/v1/social/PRODUCT/{brouillon}/comments",
        headers=acheteur,
        json={"body_fr": "Un commentaire sur un brouillon."},
    )
    assert reponse.status_code == 404


async def test_un_commentaire_signale_est_masque_sans_etre_efface(
    client, acheteur, produit_publie, session  # noqa: F811
):
    """L'administration doit pouvoir lire ce qui a ete signale pour trancher."""
    commentaire = (
        await client.post(
            f"/api/v1/social/PRODUCT/{produit_publie}/comments",
            headers=acheteur,
            json={"body_fr": "Un propos que quelqu'un jugera deplace."},
        )
    ).json()["id"]

    autre = await _make_user_plain(client)
    signalement = await client.post(
        f"/api/v1/social/comments/{commentaire}/report",
        headers=autre,
        json={"reason": "Propos insultants envers l'artisan."},
    )
    assert signalement.status_code == 202

    visibles = (
        await client.get(f"/api/v1/social/PRODUCT/{produit_publie}/comments")
    ).json()
    assert commentaire not in {c["id"] for c in visibles["commentaires"]}

    # Mais il est toujours la, avec son motif de masquage.
    reste = (
        await session.execute(
            text("SELECT hidden_at, hidden_reason FROM culture.comments WHERE id = :id"),
            {"id": uuid.UUID(commentaire)},
        )
    ).one()
    assert reste.hidden_at is not None
    assert reste.hidden_reason


async def test_on_ne_supprime_que_ses_propres_commentaires(
    client, acheteur, produit_publie  # noqa: F811
):
    commentaire = (
        await client.post(
            f"/api/v1/social/PRODUCT/{produit_publie}/comments",
            headers=acheteur,
            json={"body_fr": "Commande reçue en trois jours."},
        )
    ).json()["id"]

    intrus = await _make_user_plain(client)
    assert (
        await client.delete(f"/api/v1/social/comments/{commentaire}", headers=intrus)
    ).status_code == 404
    assert (
        await client.delete(f"/api/v1/social/comments/{commentaire}", headers=acheteur)
    ).status_code == 200


async def test_un_commentaire_demande_une_connexion(client, produit_publie):  # noqa: F811
    reponse = await client.post(
        f"/api/v1/social/PRODUCT/{produit_publie}/comments",
        json={"body_fr": "Anonyme et non authentifie."},
    )
    assert reponse.status_code in (401, 403)
