"""Tests de l'exploration par region et du quiz culturel (lot 9).

Le quiz est le point sensible : une question de culture generale est une
affirmation. Ces tests verifient qu'aucune ne sort d'ailleurs que d'une fiche
publiee, que la bonne reponse ne voyage jamais jusqu'au client, et que la
correction cite la fiche et sa source.
"""

import uuid

import pytest
import pytest_asyncio
from sqlalchemy import text

from tests.test_cms import _make_user, client  # noqa: F401
from tests.test_culture import _publish, creer_fiche, rubrique  # noqa: F401

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def publier(session, fixture_ids):
    """Fait passer une fiche par tout le circuit jusqu'a PUBLISHED."""

    async def _publier(content_id):
        await _publish(session, fixture_ids, content_id)

    return _publier


@pytest_asyncio.fixture
async def region(session):
    """Le referentiel des dix regions, et celle du Littoral pour les tests.

    On reutilise la liste du seed : ce sont les regions administratives reelles
    du Cameroun, pas des valeurs de test.
    """
    from app.seed.seed_culture import REGIONS

    for code, nom in REGIONS:
        await session.execute(
            text(
                """
                INSERT INTO ref.regions (id, code, name) VALUES (:id, :code, :name)
                ON CONFLICT (code) DO NOTHING
                """
            ),
            {"id": uuid.uuid4(), "code": code, "name": nom},
        )
    await session.commit()
    return (
        await session.execute(text("SELECT id FROM ref.regions WHERE code = 'LT'"))
    ).scalar_one()


# ---------------------------------------------------------------------------
# Regions
# ---------------------------------------------------------------------------
async def test_les_regions_sans_fiche_restent_listees(client, region):  # noqa: F811
    """Montrer ce qui reste a documenter fait partie du propos."""
    regions = (await client.get("/api/v1/culture/regions")).json()

    assert len(regions) >= 10, "les dix regions du Cameroun sont au referentiel"
    vides = [r for r in regions if r["fiches"] == 0]
    assert vides, "des regions sans fiche doivent apparaitre telles quelles"
    assert all("name" in r and "code" in r for r in regions)


async def test_la_region_compte_ses_fiches_publiees(
    client, session, region, creer_fiche, publier  # noqa: F811
):
    avant = next(
        r for r in (await client.get("/api/v1/culture/regions")).json() if r["id"] == str(region)
    )["fiches"]

    content_id = await creer_fiche("DRAFT")
    await session.execute(
        text("UPDATE culture.cultural_contents SET region_id = :r WHERE id = :id"),
        {"r": region, "id": content_id},
    )
    await session.commit()
    await publier(content_id)

    detail = (await client.get(f"/api/v1/culture/regions/{region}")).json()
    assert detail["chiffres"]["fiches"] == avant + 1
    assert content_id_present(detail["fiches"], content_id)
    # Les rubriques affichees sont celles qui existent dans la region.
    assert detail["rubriques"], "une region documentee expose ses rubriques"


def content_id_present(fiches, content_id) -> bool:
    return str(content_id) in {f["id"] for f in fiches}


async def test_une_fiche_non_publiee_ne_compte_pas(
    client, session, region, creer_fiche  # noqa: F811
):
    avant = (await client.get(f"/api/v1/culture/regions/{region}")).json()["chiffres"]["fiches"]

    brouillon = await creer_fiche("DRAFT")
    await session.execute(
        text("UPDATE culture.cultural_contents SET region_id = :r WHERE id = :id"),
        {"r": region, "id": brouillon},
    )
    await session.commit()

    apres = (await client.get(f"/api/v1/culture/regions/{region}")).json()
    assert apres["chiffres"]["fiches"] == avant
    assert not content_id_present(apres["fiches"], brouillon)


async def test_une_region_inconnue_repond_404(client):  # noqa: F811
    assert (
        await client.get(f"/api/v1/culture/regions/{uuid.uuid4()}")
    ).status_code == 404


async def test_les_regions_ne_sont_pas_prises_pour_une_fiche(client):  # noqa: F811
    """`/culture/regions` ne doit pas tomber dans `/culture/{id}`."""
    response = await client.get("/api/v1/culture/regions")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


# ---------------------------------------------------------------------------
# Quiz
# ---------------------------------------------------------------------------
async def test_le_quiz_ne_livre_jamais_la_reponse(
    client, region, creer_fiche, publier  # noqa: F811
):
    for _ in range(4):
        await publier(await creer_fiche("DRAFT"))

    body = (await client.get("/api/v1/culture/quiz?limit=10")).json()
    assert body["questions"], "des fiches publiees permettent des questions"

    for question in body["questions"]:
        assert set(question) == {"id", "type", "prompt_fr", "choices", "audio_url"}
        # Trois propositions au minimum : en deca, la question ne teste plus rien.
        assert 3 <= len(question["choices"]) <= 4
        # Aucun champ ne designe la bonne reponse. Les questions d'ecoute
        # portent une adresse de piste en plus, jamais un indice de justesse.
        for choix in question["choices"]:
            assert set(choix) <= {"id", "label", "audio_url"}
            assert {"id", "label"} <= set(choix)


async def test_chaque_question_vient_d_un_contenu_verifie(
    client, session, creer_fiche, publier  # noqa: F811
):
    """Le quiz puise dans deux gisements, tous deux valides.

    Il a longtemps tire ses questions des seules fiches culturelles, qui sont
    trop peu nombreuses pour faire un quiz. Il puise desormais aussi dans les
    enregistrements du vocabulaire, dont l'auteur et la licence sont connus.
    L'exigence n'a pas bouge : aucune question ne peut naitre d'autre chose que
    d'un contenu publie et sourcé.
    """
    for _ in range(4):
        await publier(await creer_fiche("DRAFT"))

    body = (await client.get("/api/v1/culture/quiz?limit=40")).json()
    identifiants = {q["id"].split(":")[0] for q in body["questions"]}

    autorises = {
        str(r[0])
        for r in await session.execute(
            text("SELECT id FROM culture.cultural_contents WHERE status = 'PUBLISHED'")
        )
    } | {
        str(r[0])
        for r in await session.execute(
            text(
                """
                SELECT v.id FROM corpus.vocabulary_items v
                JOIN audio.audio_assets a
                  ON a.target_id = v.id AND a.target_type = 'VOCAB'
                WHERE v.status = 'PUBLISHED'
                """
            )
        )
    }
    assert identifiants <= autorises


async def test_la_correction_cite_ce_qui_l_etablit(
    client, creer_fiche, publier  # noqa: F811
):
    """Une affirmation de quiz doit pouvoir etre verifiee.

    Une question de fiche renvoie la fiche et sa source ; une question d'ecoute
    renvoie l'attribution de l'enregistrement. Dans les deux cas, quelque chose
    d'exterieur a MBOA repond de la bonne reponse.
    """
    for _ in range(4):
        await publier(await creer_fiche("DRAFT"))

    body = (await client.get("/api/v1/culture/quiz?limit=40")).json()
    types_vus = set()

    for question in body["questions"]:
        resultats = []
        for choix in question["choices"]:
            reponse = await client.post(
                "/api/v1/culture/quiz/answer",
                json={"question_id": question["id"], "choice_id": choix["id"]},
            )
            assert reponse.status_code == 200
            resultats.append(reponse.json())

        # Une seule proposition est juste.
        assert sum(r["is_correct"] for r in resultats) == 1
        juste = next(r for r in resultats if r["is_correct"])
        assert juste["explication_fr"]
        assert juste["source"] is not None and juste["source"]["title"]

        if question["type"] in ("CATEGORY", "REGION", "SUMMARY"):
            assert juste["fiche"]["id"] == question["id"].split(":")[0]
        else:
            # Une question d'ecoute n'a pas de fiche : c'est l'attribution de
            # l'enregistrement qui repond de la reponse.
            assert juste["fiche"] is None
            assert juste["audio_url"]
        types_vus.add(question["type"])

    assert types_vus, "le quiz doit poser au moins une question"


async def test_un_quiz_sans_fiche_le_dit(client, session):  # noqa: F811
    """On n'invente pas des questions pour remplir l'ecran."""
    # On interroge le compteur renvoye par l'API plutot que de vider la base,
    # qui est partagee entre les tests.
    body = (await client.get("/api/v1/culture/quiz")).json()
    assert "fiches_publiees" in body
    assert body["message"]
    if body["fiches_publiees"] == 0:
        assert body["questions"] == []
        assert "Aucune fiche" in body["message"]


async def test_une_question_inventee_est_refusee(client):  # noqa: F811
    reponses = [
        await client.post(
            "/api/v1/culture/quiz/answer",
            json={"question_id": "pas-un-identifiant", "choice_id": str(uuid.uuid4())},
        ),
        await client.post(
            "/api/v1/culture/quiz/answer",
            json={"question_id": f"{uuid.uuid4()}:INVENTE", "choice_id": str(uuid.uuid4())},
        ),
        await client.post(
            "/api/v1/culture/quiz/answer",
            json={"question_id": f"{uuid.uuid4()}:CATEGORY", "choice_id": str(uuid.uuid4())},
        ),
    ]
    assert [r.status_code for r in reponses] == [422, 422, 404]


async def test_le_quiz_est_ouvert_sans_compte(client):  # noqa: F811
    """Le patrimoine se consulte sans se connecter (SS20)."""
    assert (await client.get("/api/v1/culture/quiz")).status_code == 200
