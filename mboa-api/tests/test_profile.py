"""Tests de la modification du profil (SS15).

Ce que l'apprenant peut changer lui-meme, et ce qu'il ne peut pas : son role et
son e-mail ne se choisissent pas depuis le profil, et changer de mot de passe
suppose de connaitre l'ancien.
"""

import uuid

import pytest
import pytest_asyncio
from sqlalchemy import text

from tests.test_cms import _make_user, client  # noqa: F401

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def compte(client):  # noqa: F811
    """Un compte dont on garde le mot de passe pour tester les changements."""
    email = f"u-{uuid.uuid4().hex[:10]}@example.com"
    tokens = (
        await client.post(
            "/api/v1/auth/register",
            json={"email": email, "password": "motdepasse-solide", "display_name": "Ama"},
        )
    ).json()
    return {
        "email": email,
        "password": "motdepasse-solide",
        "headers": {"Authorization": f"Bearer {tokens['access_token']}"},
        "refresh": tokens["refresh_token"],
    }


# ---------------------------------------------------------------------------
# Profil
# ---------------------------------------------------------------------------
async def test_modifier_son_nom_et_son_objectif(client, compte):  # noqa: F811
    response = await client.patch(
        "/api/v1/auth/me",
        headers=compte["headers"],
        json={"display_name": "Ama Ndongo", "daily_goal_xp": 30, "locale": "en"},
    )
    assert response.status_code == 200
    assert response.json()["display_name"] == "Ama Ndongo"
    assert response.json()["daily_goal_xp"] == 30
    assert response.json()["locale"] == "en"

    relu = (await client.get("/api/v1/auth/me", headers=compte["headers"])).json()
    assert relu["display_name"] == "Ama Ndongo"


async def test_une_requete_vide_ne_change_rien(client, compte):  # noqa: F811
    avant = (await client.get("/api/v1/auth/me", headers=compte["headers"])).json()
    apres = (
        await client.patch("/api/v1/auth/me", headers=compte["headers"], json={})
    ).json()
    assert apres == avant


async def test_le_role_ne_se_choisit_pas_depuis_le_profil(client, compte):  # noqa: F811
    """Le champ est ignore : l'elevation de privilege passe par l'administration."""
    await client.patch(
        "/api/v1/auth/me",
        headers=compte["headers"],
        json={"display_name": "Ama", "role": "ADMIN", "email": "autre@example.com"},
    )
    profil = (await client.get("/api/v1/auth/me", headers=compte["headers"])).json()
    assert profil["role"] == "LEARNER"
    assert profil["email"] == compte["email"]


async def test_un_objectif_hors_bornes_est_refuse(client, compte):  # noqa: F811
    """Les bornes sont celles de l'inscription : entre 10 et 50 XP par jour."""
    response = await client.patch(
        "/api/v1/auth/me", headers=compte["headers"], json={"daily_goal_xp": 500}
    )
    assert response.status_code == 422


async def test_une_langue_d_interface_inconnue_est_refusee(client, compte):  # noqa: F811
    response = await client.patch(
        "/api/v1/auth/me", headers=compte["headers"], json={"locale": "de"}
    )
    assert response.status_code == 422


async def test_renommer_met_a_jour_la_fiche_de_contributeur(
    client, session, fixture_ids  # noqa: F811
):
    """Les deux identites doivent rester celles d'une meme personne.

    Sinon le journal de validation cite un nom que plus rien ne relie au compte.
    """
    headers = await _make_user(
        client,
        session,
        role="CULTURAL_SPECIALIST",
        contributor_id=fixture_ids["author"],
        language_id=fixture_ids["language"],
    )
    await client.patch(
        "/api/v1/auth/me", headers=headers, json={"display_name": "Ngo Bassong"}
    )

    nom = (
        await session.execute(
            text("SELECT display_name FROM prov.contributors WHERE id = :id"),
            {"id": fixture_ids["author"]},
        )
    ).scalar_one()
    assert nom == "Ngo Bassong"


# ---------------------------------------------------------------------------
# Mot de passe
# ---------------------------------------------------------------------------
async def test_changer_de_mot_de_passe_exige_l_ancien(client, compte):  # noqa: F811
    """Un telephone laisse deverrouille ne suffit pas a verrouiller un compte."""
    response = await client.post(
        "/api/v1/auth/me/password",
        headers=compte["headers"],
        json={"current_password": "je-ne-le-connais-pas", "new_password": "un-autre-mdp-solide"},
    )
    assert response.status_code == 403


async def test_le_nouveau_mot_de_passe_doit_differer(client, compte):  # noqa: F811
    response = await client.post(
        "/api/v1/auth/me/password",
        headers=compte["headers"],
        json={"current_password": compte["password"], "new_password": compte["password"]},
    )
    assert response.status_code == 422


async def test_un_mot_de_passe_trop_court_est_refuse(client, compte):  # noqa: F811
    response = await client.post(
        "/api/v1/auth/me/password",
        headers=compte["headers"],
        json={"current_password": compte["password"], "new_password": "court"},
    )
    assert response.status_code == 422


async def test_changer_de_mot_de_passe_coupe_les_autres_sessions(client, compte):  # noqa: F811
    response = await client.post(
        "/api/v1/auth/me/password",
        headers=compte["headers"],
        json={"current_password": compte["password"], "new_password": "nouveau-mdp-solide"},
    )
    assert response.status_code == 204

    # L'ancien mot de passe ne fonctionne plus...
    ancien = await client.post(
        "/api/v1/auth/login",
        json={"email": compte["email"], "password": compte["password"]},
    )
    assert ancien.status_code == 401

    # ... le nouveau fonctionne...
    nouveau = await client.post(
        "/api/v1/auth/login",
        json={"email": compte["email"], "password": "nouveau-mdp-solide"},
    )
    assert nouveau.status_code == 200

    # ... et la session ouverte ailleurs ne peut plus se renouveler.
    refresh = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": compte["refresh"]}
    )
    assert refresh.status_code == 401
