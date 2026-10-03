"""Tests de la console d'administration (SS43, SS44).

Deux exigences guident ces tests :

  - un acte d'administration laisse une trace motivee, et rien ne permet de
    l'effacer ;
  - habiliter quelqu'un a valider une langue est une decision documentee, pas
    un interrupteur.
"""

import uuid

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from app.main import app
from tests.test_cms import _make_user, client  # noqa: F401

pytestmark = pytest.mark.asyncio


async def _me(client, headers) -> dict:  # noqa: F811
    return (await client.get("/api/v1/auth/me", headers=headers)).json()


@pytest_asyncio.fixture
async def admin(client, session):  # noqa: F811
    return await _make_user(client, session, role="ADMIN")


@pytest_asyncio.fixture
async def apprenant(client, session):  # noqa: F811
    return await _make_user(client, session, role="LEARNER")


def _candidature(language_id: uuid.UUID, **overrides) -> dict:
    return {
        "language_id": str(language_id),
        "claimed_role": "NATIVE_SPEAKER",
        "relationship_fr": "Langue maternelle, parlee quotidiennement en famille depuis "
        "l'enfance dans la region du Littoral.",
        "referees_fr": "Association culturelle locale, presidente joignable sur demande.",
        "requested_scope": ["LEXICON"],
        **overrides,
    }


# ---------------------------------------------------------------------------
# Acces
# ---------------------------------------------------------------------------
async def test_la_console_est_fermee_aux_apprenants(client, apprenant):  # noqa: F811
    response = await client.get("/api/v1/admin/dashboard", headers=apprenant)
    assert response.status_code == 403


async def test_la_console_est_fermee_aux_anonymes(client):  # noqa: F811
    assert (await client.get("/api/v1/admin/dashboard")).status_code == 401


# ---------------------------------------------------------------------------
# Tableau de bord
# ---------------------------------------------------------------------------
async def test_le_tableau_de_bord_rapporte_l_integrite(client, admin):  # noqa: F811
    """Les controles d'integrite portent sur tout ce que la base contient.

    Ils doivent valoir zero : c'est la verification de bout en bout que les
    triggers de provenance n'ont ete contournes nulle part.
    """
    body = (await client.get("/api/v1/admin/dashboard", headers=admin)).json()

    assert body["integrite"]["anomalies_totales"] == 0
    assert body["integrite"]["conforme"] is True
    assert {c["code"] for c in body["integrite"]["controles"]} >= {
        "lexique_publie_sans_source",
        "lexique_auto_valide",
        "fiches_publiees_sans_source",
    }
    assert body["comptes"]["total"] >= 1


async def test_le_tableau_de_bord_annonce_ce_qui_n_est_pas_fait(client, admin):  # noqa: F811
    """La console ne pretend pas administrer ce qui n'existe pas encore."""
    body = (await client.get("/api/v1/admin/dashboard", headers=admin)).json()
    domaines = {c["domaine"] for c in body["chantiers_ouverts"]}
    assert "Paiements et abonnements" in domaines
    for chantier in body["chantiers_ouverts"]:
        assert chantier["raison"], "un chantier ouvert sans raison n'apprend rien"


async def test_les_langues_sans_corpus_n_apparaissent_pas(client, admin, fixture_ids):  # noqa: F811, E501
    """Le tableau des langues ne liste que celles qui ont vraiment du contenu.

    La fixture cree une langue sans corpus : elle ne doit pas apparaitre.
    """
    body = (await client.get("/api/v1/admin/dashboard", headers=admin)).json()
    for ligne in body["corpus"]["par_langue"]:
        assert ligne["total"] > 0


# ---------------------------------------------------------------------------
# Comptes
# ---------------------------------------------------------------------------
async def test_changer_un_role_exige_un_motif(client, admin, apprenant):  # noqa: F811
    cible = await _me(client, apprenant)
    response = await client.post(
        f"/api/v1/admin/users/{cible['id']}/role",
        headers=admin,
        json={"role": "CULTURAL_SPECIALIST", "reason": "."},
    )
    assert response.status_code == 422


async def test_changer_un_role_est_journalise(client, admin, apprenant):  # noqa: F811
    cible = await _me(client, apprenant)
    response = await client.post(
        f"/api/v1/admin/users/{cible['id']}/role",
        headers=admin,
        json={
            "role": "CULTURAL_SPECIALIST",
            "reason": "Candidature acceptee en reunion du 12 mars, dossier joint.",
        },
    )
    assert response.status_code == 200

    journal = (
        await client.get(
            f"/api/v1/admin/audit?target_id={cible['id']}", headers=admin
        )
    ).json()
    assert journal[0]["action"] == "USER_ROLE_CHANGED"
    assert "reunion du 12 mars" in journal[0]["reason"]
    # L'etat precedent est conserve : le journal se lit sans recoupement.
    assert journal[0]["details"] == {"avant": "LEARNER", "apres": "CULTURAL_SPECIALIST"}


async def test_un_administrateur_ne_change_pas_son_propre_role(client, admin):  # noqa: F811
    moi = await _me(client, admin)
    response = await client.post(
        f"/api/v1/admin/users/{moi['id']}/role",
        headers=admin,
        json={"role": "LEARNER", "reason": "Je n'ai plus besoin de ces droits."},
    )
    assert response.status_code == 400
    assert "autre administrateur" in response.json()["detail"]


async def test_un_administrateur_ne_se_desactive_pas(client, admin):  # noqa: F811
    moi = await _me(client, admin)
    response = await client.post(
        f"/api/v1/admin/users/{moi['id']}/status",
        headers=admin,
        json={"is_active": False, "reason": "Depart de l'organisation."},
    )
    assert response.status_code == 400


async def test_desactiver_un_compte_coupe_ses_sessions(client, session, admin):  # noqa: F811
    """Une session ouverte sur un telephone ne survit pas a la desactivation."""
    email = f"u-{uuid.uuid4().hex[:10]}@example.com"
    tokens = (
        await client.post(
            "/api/v1/auth/register",
            json={"email": email, "password": "motdepasse-solide", "display_name": "Test"},
        )
    ).json()
    user_id = (
        await session.execute(text("SELECT id FROM iam.users WHERE email = :e"), {"e": email})
    ).scalar_one()

    response = await client.post(
        f"/api/v1/admin/users/{user_id}/status",
        headers=admin,
        json={"is_active": False, "reason": "Compte de test cree par erreur en production."},
    )
    assert response.status_code == 200

    refreshed = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert refreshed.status_code == 401
    acces = await client.get(
        "/api/v1/auth/me", headers={"Authorization": f"Bearer {tokens['access_token']}"}
    )
    assert acces.status_code == 401


async def test_habiliter_un_apprenant_est_refuse(client, admin, apprenant, fixture_ids):  # noqa: F811, E501
    """Le droit de valider une langue ne s'accorde pas a un compte apprenant."""
    cible = await _me(client, apprenant)
    response = await client.post(
        f"/api/v1/admin/users/{cible['id']}/habilitations",
        headers=admin,
        json={
            "language_id": str(fixture_ids["language"]),
            "scope": ["LEXICON"],
            "reason": "Locuteur reconnu par sa communaute.",
        },
    )
    assert response.status_code == 409
    assert "role" in response.json()["detail"]


async def test_un_perimetre_inconnu_est_refuse(client, admin, apprenant, fixture_ids):  # noqa: F811, E501
    cible = await _me(client, apprenant)
    response = await client.post(
        f"/api/v1/admin/users/{cible['id']}/habilitations",
        headers=admin,
        json={
            "language_id": str(fixture_ids["language"]),
            "scope": ["TOUT"],
            "reason": "Habilitation generale demandee par le porteur.",
        },
    )
    assert response.status_code == 422
    assert "TOUT" in response.json()["detail"]


async def test_retirer_une_habilitation_la_desactive_sans_l_effacer(
    client, session, admin, apprenant, fixture_ids  # noqa: F811
):
    cible = await _me(client, apprenant)
    await client.post(
        f"/api/v1/admin/users/{cible['id']}/role",
        headers=admin,
        json={"role": "CULTURAL_SPECIALIST", "reason": "Dossier valide par le comite."},
    )
    await client.post(
        f"/api/v1/admin/users/{cible['id']}/habilitations",
        headers=admin,
        json={
            "language_id": str(fixture_ids["language"]),
            "scope": ["LEXICON", "CULTURE"],
            "reason": "Locutrice native, references verifiees aupres de l'association.",
        },
    )

    retrait = await client.delete(
        f"/api/v1/admin/users/{cible['id']}/habilitations/{fixture_ids['language']}"
        "?reason=Fin de la mission de relecture, a la demande de l'interessee.",
        headers=admin,
    )
    assert retrait.status_code == 200

    ligne = (
        await session.execute(
            text(
                """
                SELECT a.is_active, a.scope FROM prov.validation_assignments a
                JOIN prov.contributors c ON c.id = a.contributor_id
                WHERE c.user_id = :uid AND a.language_id = :lang
                """
            ),
            {"uid": cible["id"], "lang": fixture_ids["language"]},
        )
    ).one()
    # La ligne existe toujours : les contenus deja valides gardent leur autorite.
    assert ligne.is_active is False
    assert set(ligne.scope) == {"LEXICON", "CULTURE"}

    assert (await client.delete(
        f"/api/v1/admin/users/{cible['id']}/habilitations/{fixture_ids['language']}"
        "?reason=Nouvelle tentative de retrait sur une habilitation deja retiree.",
        headers=admin,
    )).status_code == 404


# ---------------------------------------------------------------------------
# Demandes d'habilitation
# ---------------------------------------------------------------------------
async def test_une_candidature_ouvre_l_acces_a_l_espace_contributeur(
    client, session, admin, apprenant, fixture_ids  # noqa: F811
):
    """Le parcours complet : candidature, decision, puis acces reel.

    C'est le test qui compte : il verifie qu'accepter une demande ne se contente
    pas de changer un statut, mais ouvre effectivement le droit de travailler
    sur la langue demandee.
    """
    # Avant toute decision, l'espace contributeur est ferme.
    assert (
        await client.get(
            f"/api/v1/cms/queue?language_id={fixture_ids['language']}", headers=apprenant
        )
    ).status_code == 403

    depot = await client.post(
        "/api/v1/me/specialist-application",
        headers=apprenant,
        json=_candidature(fixture_ids["language"], requested_scope=["LEXICON", "AUDIO"]),
    )
    assert depot.status_code == 201
    application_id = depot.json()["id"]

    en_attente = (
        await client.get("/api/v1/admin/applications?status=PENDING", headers=admin)
    ).json()
    assert application_id in {a["id"] for a in en_attente}

    decision = await client.post(
        f"/api/v1/admin/applications/{application_id}/decision",
        headers=admin,
        json={
            "decision": "ACCEPT",
            "reason": "Entretien mene le 3 avril ; deux references confirment la "
            "pratique quotidienne de la langue.",
            "granted_scope": ["LEXICON"],
        },
    )
    assert decision.status_code == 200
    # Le perimetre accorde peut etre plus etroit que celui demande.
    assert decision.json()["scope"] == ["LEXICON"]

    profil = await _me(client, apprenant)
    assert profil["role"] == "CULTURAL_SPECIALIST"

    # Et l'espace contributeur s'ouvre, avec le meme jeton qu'au depart.
    queue = await client.get(
        f"/api/v1/cms/queue?language_id={fixture_ids['language']}", headers=apprenant
    )
    assert queue.status_code == 200

    suivi = (
        await client.get("/api/v1/me/specialist-application", headers=apprenant)
    ).json()
    assert suivi[0]["status"] == "ACCEPTED"
    assert "3 avril" in suivi[0]["review_note"]


async def test_deux_demandes_simultanees_pour_la_meme_langue_sont_refusees(
    client, apprenant, fixture_ids  # noqa: F811
):
    first = await client.post(
        "/api/v1/me/specialist-application",
        headers=apprenant,
        json=_candidature(fixture_ids["language"]),
    )
    assert first.status_code == 201
    second = await client.post(
        "/api/v1/me/specialist-application",
        headers=apprenant,
        json=_candidature(fixture_ids["language"]),
    )
    assert second.status_code == 409


async def test_une_candidature_sans_rapport_declare_est_refusee(
    client, apprenant, fixture_ids  # noqa: F811
):
    """Le formulaire n'accepte pas une justification vide de sens."""
    response = await client.post(
        "/api/v1/me/specialist-application",
        headers=apprenant,
        json=_candidature(fixture_ids["language"], relationship_fr="je connais"),
    )
    assert response.status_code == 422


async def test_un_administrateur_ne_statue_pas_sur_sa_propre_demande(
    client, session, admin, fixture_ids  # noqa: F811
):
    depot = await client.post(
        "/api/v1/me/specialist-application",
        headers=admin,
        json=_candidature(fixture_ids["language"]),
    )
    assert depot.status_code == 201
    response = await client.post(
        f"/api/v1/admin/applications/{depot.json()['id']}/decision",
        headers=admin,
        json={"decision": "ACCEPT", "reason": "Je connais bien cette langue."},
    )
    assert response.status_code == 400


async def test_une_demande_rejetee_n_habilite_personne(
    client, session, admin, apprenant, fixture_ids  # noqa: F811
):
    depot = await client.post(
        "/api/v1/me/specialist-application",
        headers=apprenant,
        json=_candidature(fixture_ids["language"]),
    )
    await client.post(
        f"/api/v1/admin/applications/{depot.json()['id']}/decision",
        headers=admin,
        json={
            "decision": "REJECT",
            "reason": "Les references fournies n'ont pas pu etre jointes en deux mois.",
        },
    )
    profil = await _me(client, apprenant)
    assert profil["role"] == "LEARNER"
    habilitations = (
        await session.execute(
            text(
                """
                SELECT count(*) FROM prov.validation_assignments a
                JOIN prov.contributors c ON c.id = a.contributor_id
                WHERE c.user_id = :uid
                """
            ),
            {"uid": profil["id"]},
        )
    ).scalar_one()
    assert habilitations == 0


# ---------------------------------------------------------------------------
# Parametres
# ---------------------------------------------------------------------------
async def test_le_parametre_de_relecture_ne_se_desactive_pas(client, admin):  # noqa: F811
    """La regle centrale du cahier des charges n'est pas un interrupteur.

    Elle est appliquee par la base ; la console l'affiche pour memoire et
    refuse de la modifier.
    """
    reglages = (await client.get("/api/v1/admin/settings", headers=admin)).json()
    verrouille = next(
        s for s in reglages if s["key"] == "review_required_before_publish"
    )
    assert verrouille["is_editable"] is False

    response = await client.put(
        "/api/v1/admin/settings/review_required_before_publish",
        headers=admin,
        json={"value": False, "reason": "Accelerer la mise en ligne avant la demonstration."},
    )
    assert response.status_code == 409


async def test_modifier_un_parametre_conserve_l_avant_et_l_apres(client, admin):  # noqa: F811
    response = await client.put(
        "/api/v1/admin/settings/default_daily_goal_xp",
        headers=admin,
        json={"value": 30, "reason": "Objectif releve apres les retours des testeurs."},
    )
    assert response.status_code == 200

    journal = (
        await client.get("/api/v1/admin/audit?action=SETTING_CHANGED", headers=admin)
    ).json()
    assert journal[0]["target_label"] == "default_daily_goal_xp"
    assert journal[0]["details"] == {"avant": 20, "apres": 30}


async def test_un_parametre_change_de_valeur_pas_de_nature(client, admin):  # noqa: F811
    response = await client.put(
        "/api/v1/admin/settings/default_daily_goal_xp",
        headers=admin,
        json={"value": "beaucoup", "reason": "Saisie libre demandee par un testeur."},
    )
    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Journal
# ---------------------------------------------------------------------------
async def test_aucune_route_ne_supprime_le_journal():
    """Le journal est une piece du dossier, pas une note de travail."""
    for route in app.routes:
        chemin = getattr(route, "path", "")
        if "/admin/audit" in chemin:
            assert set(getattr(route, "methods", set())) <= {"GET", "HEAD"}


async def test_la_base_refuse_une_entree_de_journal_sans_motif(session, admin):  # noqa: F811
    """La regle ne tient pas qu'au code applicatif."""
    with pytest.raises(IntegrityError):
        await session.execute(
            text(
                """
                INSERT INTO admin.audit_log
                    (id, actor_label, action, target_type, reason)
                VALUES (:id, 'test', 'USER_ROLE_CHANGED', 'USER', '   ')
                """
            ),
            {"id": uuid.uuid4()},
        )
        await session.commit()
