"""Tests de la configuration initiale (lot 3 des maquettes).

Deux points sont verifies au-dela de la simple persistance :

  - le temps quotidien annonce et l'objectif en XP du profil ne doivent pas
    raconter deux choses differentes ;
  - le test de positionnement ne doit pas etre propose quand le corpus publie
    ne permet pas de situer quoi que ce soit.
"""

import uuid

import pytest
import pytest_asyncio
from sqlalchemy import text

from tests.test_cms import _make_user, client  # noqa: F401

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def apprenant(client, session):  # noqa: F811
    return await _make_user(client, session, role="LEARNER")


async def test_la_configuration_part_vide(client, apprenant):  # noqa: F811
    body = (await client.get("/api/v1/me/preferences", headers=apprenant)).json()

    assert body["preferences"]["motivations"] == []
    assert body["preferences"]["interests"] == []
    assert body["preferences"]["daily_minutes"] is None
    assert body["preferences"]["completed_at"] is None
    # Les reglages de notification existent tous, a faux.
    assert set(body["preferences"]["notifications"]) == {
        "reminders",
        "new_content",
        "tips",
        "offers",
    }
    assert not any(body["preferences"]["notifications"].values())


async def test_les_choix_proposes_viennent_du_serveur(client, apprenant):  # noqa: F811
    """L'application ne recopie pas une liste en dur."""
    choix = (await client.get("/api/v1/me/preferences", headers=apprenant)).json()["choix"]

    assert "DISCOVER_CULTURE" in choix["motivations"]
    assert "TALES" in choix["interets"]
    assert choix["minutes"] == [5, 10, 15, 30]


async def test_chaque_etape_s_enregistre_sans_effacer_les_autres(
    client, apprenant  # noqa: F811
):
    """La configuration se remplit par etapes : un envoi partiel ne remet rien a zero."""
    await client.put(
        "/api/v1/me/preferences",
        headers=apprenant,
        json={"motivations": ["DISCOVER_CULTURE", "FAMILY"]},
    )
    await client.put(
        "/api/v1/me/preferences",
        headers=apprenant,
        json={"interests": ["TALES", "PROVERBS"]},
    )
    body = (
        await client.put(
            "/api/v1/me/preferences", headers=apprenant, json={"daily_minutes": 15}
        )
    ).json()

    assert body["preferences"]["motivations"] == ["DISCOVER_CULTURE", "FAMILY"]
    assert body["preferences"]["interests"] == ["TALES", "PROVERBS"]
    assert body["preferences"]["daily_minutes"] == 15


async def test_le_temps_annonce_fixe_l_objectif_du_profil(client, apprenant):  # noqa: F811
    """Les deux ne doivent pas se contredire d'un ecran a l'autre."""
    for minutes, xp in ((5, 10), (10, 20), (15, 30), (30, 50)):
        body = (
            await client.put(
                "/api/v1/me/preferences", headers=apprenant, json={"daily_minutes": minutes}
            )
        ).json()
        assert body["daily_goal_xp"] == xp

        profil = (await client.get("/api/v1/auth/me", headers=apprenant)).json()
        assert profil["daily_goal_xp"] == xp


async def test_une_duree_hors_liste_est_refusee(client, apprenant):  # noqa: F811
    response = await client.put(
        "/api/v1/me/preferences", headers=apprenant, json={"daily_minutes": 7}
    )
    assert response.status_code == 422
    assert "5, 10, 15, 30" in response.json()["detail"]


async def test_un_reglage_de_notification_inconnu_est_refuse(
    client, apprenant  # noqa: F811
):
    response = await client.put(
        "/api/v1/me/preferences",
        headers=apprenant,
        json={"notifications": {"publicite_ciblee": True}},
    )
    assert response.status_code == 422
    assert "publicite_ciblee" in response.json()["detail"]


async def test_les_notifications_se_cumulent(client, apprenant):  # noqa: F811
    await client.put(
        "/api/v1/me/preferences", headers=apprenant, json={"notifications": {"reminders": True}}
    )
    body = (
        await client.put(
            "/api/v1/me/preferences",
            headers=apprenant,
            json={"notifications": {"offers": False, "tips": True}},
        )
    ).json()

    assert body["preferences"]["notifications"] == {
        "reminders": True,
        "new_content": False,
        "tips": True,
        "offers": False,
    }


# ---------------------------------------------------------------------------
# Test de positionnement
# ---------------------------------------------------------------------------
async def test_le_positionnement_se_declare_indisponible_sans_corpus(
    client, apprenant, fixture_ids  # noqa: F811
):
    """Un test tire de trop peu d'exercices ne mesurerait rien."""
    response = await client.get(
        f"/api/v1/me/preferences/placement?language_id={fixture_ids['language']}",
        headers=apprenant,
    )
    assert response.status_code == 200
    body = response.json()

    assert body["disponible"] is False
    assert body["exercices_publies"] < body["minimum_requis"]
    assert "pas assez de questions" in body["explication"]


async def test_la_disponibilite_exige_le_nombre_ET_la_variete(
    client, apprenant  # noqa: F811
):
    """Le nombre ne suffit pas : un test monotype mesure une seule competence.

    On verifie l'invariant sur le corpus reellement present, sans le fabriquer :
    la regle doit tenir quel que soit l'etat de la base.
    """
    body = (await client.get("/api/v1/me/preferences/placement", headers=apprenant)).json()

    assez_de_questions = body["exercices_publies"] >= body["minimum_requis"]
    assez_varie = body["types_publies"] >= body["types_requis"]
    assert body["disponible"] is (assez_de_questions and assez_varie)

    if not body["disponible"]:
        motif = (
            "pas assez de questions" if not assez_de_questions
            else "un seul type d'exercice"
        )
        assert motif in body["explication"]


async def test_le_refus_du_test_est_conserve(client, apprenant):  # noqa: F811
    body = (
        await client.put(
            "/api/v1/me/preferences",
            headers=apprenant,
            json={"placement_test_accepted": False},
        )
    ).json()

    assert body["preferences"]["placement_test_offered"] is True
    assert body["preferences"]["placement_test_accepted"] is False


# ---------------------------------------------------------------------------
# Recapitulatif
# ---------------------------------------------------------------------------
async def test_le_recapitulatif_nomme_les_rubriques_choisies(
    client, session, apprenant  # noqa: F811
):
    existe = (
        await session.execute(
            text("SELECT 1 FROM culture.cultural_categories WHERE code = 'TALES'")
        )
    ).first()
    if not existe:
        await session.execute(
            text(
                """
                INSERT INTO culture.cultural_categories (id, code, name_fr, position)
                VALUES (:id, 'TALES', 'Contes', 3)
                """
            ),
            {"id": uuid.uuid4()},
        )
        await session.commit()

    await client.put(
        "/api/v1/me/preferences",
        headers=apprenant,
        json={
            "motivations": ["FAMILY"],
            "interests": ["TALES"],
            "daily_minutes": 10,
            "notifications": {"reminders": True},
            "completed": True,
        },
    )
    recap = (await client.get("/api/v1/me/preferences/summary", headers=apprenant)).json()

    assert recap["motivations"] == ["FAMILY"]
    # La rubrique est nommee, pas affichee sous son code technique.
    assert recap["interets"] == ["Contes"]
    assert recap["minutes"] == 10
    assert recap["daily_goal_xp"] == 20
    assert recap["notifications_actives"] == ["reminders"]
    assert recap["termine"] is True


async def test_un_recapitulatif_vide_reste_vide(client, apprenant):  # noqa: F811
    """Aucune valeur par defaut n'est presentee comme un choix de l'apprenant."""
    recap = (await client.get("/api/v1/me/preferences/summary", headers=apprenant)).json()

    assert recap["motivations"] == []
    assert recap["interets"] == []
    assert recap["minutes"] is None
    assert recap["notifications_actives"] == []
    assert recap["termine"] is False


async def test_la_configuration_est_privee(client):  # noqa: F811
    assert (await client.get("/api/v1/me/preferences")).status_code == 401
    assert (await client.put("/api/v1/me/preferences", json={})).status_code == 401
