"""Tests des attestations de parcours (SS15).

Une attestation MBOA est un constat, pas un diplome. Ces tests verifient les
deux choses qui le garantissent :

  - elle ne peut pas affirmer un parcours qui n'a pas eu lieu, et la base le
    refuse aussi bien que l'API ;
  - elle dit ce qu'elle n'atteste pas, et reste verifiable par un tiers, y
    compris apres revocation.
"""

import uuid

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError

from tests.test_cms import _make_user, client  # noqa: F401

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def apprenant(client, session):  # noqa: F811
    headers = await _make_user(client, session, role="LEARNER")
    profil = (await client.get("/api/v1/auth/me", headers=headers)).json()
    return {"headers": headers, "id": uuid.UUID(profil["id"]), "nom": profil["display_name"]}


@pytest_asyncio.fixture
async def admin(client, session):  # noqa: F811
    return await _make_user(client, session, role="ADMIN")


@pytest_asyncio.fixture
async def section(session, fixture_ids):
    """Une section de deux lecons, publiee, sur la langue de test."""
    ids = {k: uuid.uuid4() for k in ("course", "section", "unit", "lesson_a", "lesson_b")}
    params = {**ids, "lang": fixture_ids["language"], "src": fixture_ids["source"]}

    await session.execute(
        text(
            """
            INSERT INTO learn.courses (id, language_id, level, title_fr, status, source_id)
            VALUES (:course, :lang, 'N0', 'Premiers pas en langue de test', 'DRAFT', :src)
            """
        ),
        params,
    )
    await session.execute(
        text(
            """
            INSERT INTO learn.sections (id, course_id, position, title_fr, status, source_id)
            VALUES (:section, :course, 0, 'Saluer et se presenter', 'DRAFT', :src)
            """
        ),
        params,
    )
    await session.execute(
        text(
            """
            INSERT INTO learn.units
                (id, section_id, position, title_fr, objective_fr, status, source_id)
            VALUES (:unit, :section, 0, 'Unite', 'Objectif', 'DRAFT', :src)
            """
        ),
        params,
    )
    for key, position in (("lesson_a", 0), ("lesson_b", 1)):
        await session.execute(
            text(
                """
                INSERT INTO learn.lessons
                    (id, unit_id, position, kind, title_fr, status, source_id)
                VALUES (:id, :unit, :pos, 'LESSON', 'Lecon', 'DRAFT', :src)
                """
            ),
            {"id": ids[key], "unit": ids["unit"], "pos": position, "src": params["src"]},
        )
    await session.commit()
    return ids


@pytest_asyncio.fixture
async def terminer(session, apprenant):
    """Marque une lecon comme terminee pour l'apprenant, avec un score donne."""

    async def _terminer(lesson_id: uuid.UUID, score: float = 0.9):
        await session.execute(
            text(
                """
                INSERT INTO progress.lesson_progress
                    (id, user_id, lesson_id, status, best_score, attempts,
                     first_completed_at, last_completed_at)
                VALUES (:id, :uid, :lid, 'COMPLETED', :score, 1, now(), now())
                ON CONFLICT (user_id, lesson_id)
                DO UPDATE SET status = 'COMPLETED', best_score = EXCLUDED.best_score
                """
            ),
            {
                "id": uuid.uuid4(),
                "uid": apprenant["id"],
                "lid": lesson_id,
                "score": score,
            },
        )
        await session.commit()

    return _terminer


# ---------------------------------------------------------------------------
# Emission
# ---------------------------------------------------------------------------
async def test_un_parcours_incomplet_ne_donne_pas_d_attestation(
    client, apprenant, section, terminer  # noqa: F811
):
    await terminer(section["lesson_a"])

    response = await client.post(
        "/api/v1/me/certificates",
        headers=apprenant["headers"],
        json={"section_id": str(section["section"])},
    )
    assert response.status_code == 409
    assert "1 lecon(s) terminee(s) sur 2" in response.json()["detail"]


async def test_la_section_terminee_n_apparait_qu_une_fois_finie(
    client, apprenant, section, terminer  # noqa: F811
):
    """Le bouton d'attestation ne s'affiche pas avant que le parcours soit fait."""
    await terminer(section["lesson_a"])
    avant = (await client.get("/api/v1/me/certificates", headers=apprenant["headers"])).json()
    assert str(section["section"]) not in {d["section_id"] for d in avant["disponibles"]}

    await terminer(section["lesson_b"])
    apres = (await client.get("/api/v1/me/certificates", headers=apprenant["headers"])).json()
    disponible = next(
        d for d in apres["disponibles"] if d["section_id"] == str(section["section"])
    )
    assert disponible["lessons_completed"] == disponible["lessons_total"] == 2


async def test_l_attestation_reprend_les_chiffres_reels(
    client, apprenant, section, terminer  # noqa: F811
):
    await terminer(section["lesson_a"], score=1.0)
    await terminer(section["lesson_b"], score=0.8)

    response = await client.post(
        "/api/v1/me/certificates",
        headers=apprenant["headers"],
        json={"section_id": str(section["section"])},
    )
    assert response.status_code == 201
    body = response.json()

    assert body["lessons_completed"] == 2
    assert body["lessons_total"] == 2
    # Moyenne des meilleurs scores, sans arrondi flatteur.
    assert body["average_score"] == pytest.approx(0.9)
    assert body["learner_name"] == apprenant["nom"]
    assert body["section_title"] == "Saluer et se presenter"
    assert body["code"].startswith("MBOA-ZXX-")
    # Le code se lit au telephone : ni zero ni O, ni un ni I.
    assert not set(body["code"].split("-")[-1]) & set("01OIL")


async def test_reemettre_rend_la_meme_attestation(
    client, apprenant, section, terminer  # noqa: F811
):
    """Une attestation qui changerait de numero a chaque appel ne serait pas verifiable."""
    await terminer(section["lesson_a"])
    await terminer(section["lesson_b"])

    premier = await client.post(
        "/api/v1/me/certificates",
        headers=apprenant["headers"],
        json={"section_id": str(section["section"])},
    )
    second = await client.post(
        "/api/v1/me/certificates",
        headers=apprenant["headers"],
        json={"section_id": str(section["section"])},
    )
    assert premier.json()["code"] == second.json()["code"]
    assert premier.json()["id"] == second.json()["id"]


# ---------------------------------------------------------------------------
# La base, pas seulement l'API
# ---------------------------------------------------------------------------
async def test_la_base_refuse_une_attestation_sans_parcours(
    session, apprenant, section  # noqa: F811
):
    """Aucune lecon terminee : l'INSERT direct est rejete par le trigger."""
    with pytest.raises(DBAPIError) as erreur:
        await session.execute(
            text(
                """
                INSERT INTO progress.certificates
                    (id, user_id, section_id, code, learner_name, course_title,
                     section_title, language_name, language_iso, level,
                     lessons_completed, lessons_total, average_score, completed_at)
                VALUES (:id, :uid, :sid, :code, 'Faussaire', 'Cours', 'Section',
                        'Langue', 'zxx', 'N0', 2, 2, 1.0, now())
                """
            ),
            {
                "id": uuid.uuid4(),
                "uid": apprenant["id"],
                "sid": section["section"],
                "code": f"MBOA-ZXX-2026-{uuid.uuid4().hex[:6].upper()}",
            },
        )
    assert "MBOA[parcours_incomplet]" in str(erreur.value)
    await session.rollback()


async def test_la_base_refuse_des_chiffres_inventes(
    session, apprenant, section, terminer  # noqa: F811
):
    """Le parcours est fait, mais l'attestation en annonce davantage."""
    await terminer(section["lesson_a"])
    await terminer(section["lesson_b"])

    with pytest.raises(DBAPIError) as erreur:
        await session.execute(
            text(
                """
                INSERT INTO progress.certificates
                    (id, user_id, section_id, code, learner_name, course_title,
                     section_title, language_name, language_iso, level,
                     lessons_completed, lessons_total, average_score, completed_at)
                VALUES (:id, :uid, :sid, :code, 'Optimiste', 'Cours', 'Section',
                        'Langue', 'zxx', 'N0', 40, 40, 1.0, now())
                """
            ),
            {
                "id": uuid.uuid4(),
                "uid": apprenant["id"],
                "sid": section["section"],
                "code": f"MBOA-ZXX-2026-{uuid.uuid4().hex[:6].upper()}",
            },
        )
    assert "MBOA[chiffres_incoherents]" in str(erreur.value)
    await session.rollback()


# ---------------------------------------------------------------------------
# PDF
# ---------------------------------------------------------------------------
async def test_le_pdf_est_un_vrai_pdf_et_porte_son_code(
    client, apprenant, section, terminer  # noqa: F811
):
    await terminer(section["lesson_a"])
    await terminer(section["lesson_b"])
    certificat = (
        await client.post(
            "/api/v1/me/certificates",
            headers=apprenant["headers"],
            json={"section_id": str(section["section"])},
        )
    ).json()

    response = await client.get(
        f"/api/v1/me/certificates/{certificat['id']}/pdf", headers=apprenant["headers"]
    )
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert certificat["code"] in response.headers["content-disposition"]
    assert response.content.startswith(b"%PDF")
    assert len(response.content) > 2000


async def test_on_ne_telecharge_pas_l_attestation_d_un_autre(
    client, session, apprenant, section, terminer  # noqa: F811
):
    await terminer(section["lesson_a"])
    await terminer(section["lesson_b"])
    certificat = (
        await client.post(
            "/api/v1/me/certificates",
            headers=apprenant["headers"],
            json={"section_id": str(section["section"])},
        )
    ).json()

    autre = await _make_user(client, session, role="LEARNER")
    response = await client.get(
        f"/api/v1/me/certificates/{certificat['id']}/pdf", headers=autre
    )
    assert response.status_code == 404


async def test_le_pdf_enonce_ce_qu_il_n_atteste_pas():
    """La phrase qui empeche l'attestation de dire plus qu'elle ne sait."""
    from app.modules.certificates import pdf

    assert "ne constitue pas une certification de niveau de langue" in pdf.DISCLAIMER
    assert "n’évalue pas la production orale" in pdf.DISCLAIMER


async def test_le_pdf_sait_ecrire_l_alphabet_des_langues():
    """Une attestation qui imprimerait des carres vides serait inutilisable."""
    from fontTools.ttLib import TTFont

    from app.modules.certificates import pdf

    cmap = TTFont(pdf.FONT_PATH).getBestCmap()
    manquants = [c for c in "ɓɛɔŋǝáà" if ord(c) not in cmap]
    assert manquants == []


# ---------------------------------------------------------------------------
# Verification par un tiers
# ---------------------------------------------------------------------------
async def test_la_verification_est_publique(
    client, apprenant, section, terminer  # noqa: F811
):
    """Une attestation qu'un employeur ne peut pas verifier ne vaut rien."""
    await terminer(section["lesson_a"])
    await terminer(section["lesson_b"])
    certificat = (
        await client.post(
            "/api/v1/me/certificates",
            headers=apprenant["headers"],
            json={"section_id": str(section["section"])},
        )
    ).json()

    # Sans aucun en-tete d'authentification.
    response = await client.get(f"/api/v1/certificates/verify/{certificat['code']}")
    assert response.status_code == 200
    body = response.json()
    assert body["valide"] is True
    assert body["titulaire"] == apprenant["nom"]
    assert body["lecons_terminees"] == 2
    # La portee est rappelee a celui qui verifie, pas seulement au titulaire.
    assert "ne constitue pas une certification de niveau" in body["portee"]


async def test_un_code_inconnu_repond_clairement(client):  # noqa: F811
    """C'est un tiers qui interroge : il merite une phrase, pas un 404 muet."""
    response = await client.get("/api/v1/certificates/verify/MBOA-ZXX-2026-ZZZZZZ")
    assert response.status_code == 200
    assert response.json()["valide"] is False
    assert "Aucune attestation" in response.json()["motif"]


# ---------------------------------------------------------------------------
# Revocation
# ---------------------------------------------------------------------------
async def test_une_attestation_revoquee_continue_de_repondre(
    client, admin, apprenant, section, terminer  # noqa: F811
):
    """On ne l'efface pas : le tiers qui la detient doit obtenir une reponse."""
    await terminer(section["lesson_a"])
    await terminer(section["lesson_b"])
    certificat = (
        await client.post(
            "/api/v1/me/certificates",
            headers=apprenant["headers"],
            json={"section_id": str(section["section"])},
        )
    ).json()

    revocation = await client.post(
        f"/api/v1/admin/certificates/{certificat['id']}/revoke",
        headers=admin,
        json={"reason": "Parcours effectue avec un compte de test, a la demande du titulaire."},
    )
    assert revocation.status_code == 200

    verification = (
        await client.get(f"/api/v1/certificates/verify/{certificat['code']}")
    ).json()
    assert verification["valide"] is False
    assert "revoquee" in verification["motif"]

    # Le PDF, lui, n'est plus telechargeable.
    pdf_response = await client.get(
        f"/api/v1/me/certificates/{certificat['id']}/pdf", headers=apprenant["headers"]
    )
    assert pdf_response.status_code == 410

    # Et l'acte figure au journal d'administration, avec son motif.
    journal = (
        await client.get("/api/v1/admin/audit?action=CERTIFICATE_REVOKED", headers=admin)
    ).json()
    assert certificat["code"] in journal[0]["target_label"]
    assert "compte de test" in journal[0]["reason"]


async def test_revoquer_deux_fois_est_refuse(
    client, admin, apprenant, section, terminer  # noqa: F811
):
    await terminer(section["lesson_a"])
    await terminer(section["lesson_b"])
    certificat = (
        await client.post(
            "/api/v1/me/certificates",
            headers=apprenant["headers"],
            json={"section_id": str(section["section"])},
        )
    ).json()
    motif = {"reason": "Attestation emise par erreur lors d'une demonstration."}

    assert (
        await client.post(
            f"/api/v1/admin/certificates/{certificat['id']}/revoke", headers=admin, json=motif
        )
    ).status_code == 200
    assert (
        await client.post(
            f"/api/v1/admin/certificates/{certificat['id']}/revoke", headers=admin, json=motif
        )
    ).status_code == 409


async def test_seul_un_administrateur_revoque(
    client, apprenant, section, terminer  # noqa: F811
):
    await terminer(section["lesson_a"])
    await terminer(section["lesson_b"])
    certificat = (
        await client.post(
            "/api/v1/me/certificates",
            headers=apprenant["headers"],
            json={"section_id": str(section["section"])},
        )
    ).json()

    response = await client.post(
        f"/api/v1/admin/certificates/{certificat['id']}/revoke",
        headers=apprenant["headers"],
        json={"reason": "Je prefere la retirer moi-meme."},
    )
    assert response.status_code == 403


# ---------------------------------------------------------------------------
# Lien avec le profil
# ---------------------------------------------------------------------------
async def test_renommer_son_profil_ne_reecrit_pas_une_attestation(
    client, apprenant, section, terminer  # noqa: F811
):
    """Le nom porte par l'attestation est celui sous lequel elle a ete emise."""
    await terminer(section["lesson_a"])
    await terminer(section["lesson_b"])
    certificat = (
        await client.post(
            "/api/v1/me/certificates",
            headers=apprenant["headers"],
            json={"section_id": str(section["section"])},
        )
    ).json()

    await client.patch(
        "/api/v1/auth/me",
        headers=apprenant["headers"],
        json={"display_name": "Nouveau nom"},
    )
    verification = (
        await client.get(f"/api/v1/certificates/verify/{certificat['code']}")
    ).json()
    assert verification["titulaire"] == apprenant["nom"]
