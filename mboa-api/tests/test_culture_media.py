"""Tests de la mediatheque par region et des favoris (lot 9).

Le point sensible est la **provenance du rattachement** : MBOA ne decrete pas
quelles langues se parlent dans quelle region. Ce lien vient d'une fiche
publiee, donc sourcee, et ces tests verifient qu'il ne s'etablit pas autrement.
"""

import uuid

import pytest
import pytest_asyncio
from sqlalchemy import text

from tests.test_cms import _make_user, client  # noqa: F401
from tests.test_culture import _publish, creer_fiche, rubrique  # noqa: F401
from tests.test_culture_regions import publier, region  # noqa: F401

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def apprenant(client, session):  # noqa: F811
    return await _make_user(client, session, role="LEARNER")


@pytest_asyncio.fixture
async def enregistrement(session, fixture_ids):
    """Un mot publie et son enregistrement, avec attribution et licence."""
    item_id, asset_id = uuid.uuid4(), uuid.uuid4()
    await session.execute(
        text(
            """
            INSERT INTO corpus.vocabulary_items
                (id, language_id, lemma, lemma_toneless, grammatical_category,
                 meaning_fr, status, source_id, created_by, validated_by)
            VALUES (:id, :lang, :lemma, :lemma, 'NOUN', 'sens de test', 'DRAFT',
                    :src, :by, NULL)
            """
        ),
        {
            "id": item_id,
            "lang": fixture_ids["language"],
            "lemma": f"lemme-audio-{item_id.hex[:6]}",
            "src": fixture_ids["source"],
            "by": fixture_ids["author"],
        },
    )
    # Passage par le circuit complet : un mot ne s'auto-publie pas.
    for etape in ("TO_VERIFY", "HUMAN_REVIEW"):
        await session.execute(
            text(
                "UPDATE corpus.vocabulary_items "
                "SET status = CAST(:s AS shared.content_status) WHERE id = :id"
            ),
            {"s": etape, "id": item_id},
        )
    await session.execute(
        text(
            """
            INSERT INTO prov.content_validations
                (id, target_type, target_id, validator_contributor_id, decision, decided_at)
            VALUES (:id, 'vocabulary_items', :target, :v, 'ACCEPT', now())
            """
        ),
        {"id": uuid.uuid4(), "target": item_id, "v": fixture_ids["validator"]},
    )
    await session.execute(
        text(
            "UPDATE corpus.vocabulary_items SET status='VALIDATED', validated_by=:v "
            "WHERE id = :id"
        ),
        {"v": fixture_ids["validator"], "id": item_id},
    )
    await session.execute(
        text("UPDATE corpus.vocabulary_items SET status='PUBLISHED' WHERE id = :id"),
        {"id": item_id},
    )
    await session.execute(
        text(
            """
            INSERT INTO audio.audio_assets
                (id, language_id, file_key, target_type, target_id, license,
                 source_id, attribution)
            VALUES (:id, :lang, 'https://example.org/test.wav', 'VOCAB', :target,
                    'CC_BY_SA', :src, 'Locuteur de test (Lingua Libre) - CC BY-SA 4.0')
            """
        ),
        {
            "id": asset_id,
            "lang": fixture_ids["language"],
            "target": item_id,
            "src": fixture_ids["source"],
        },
    )
    await session.commit()
    return {"asset": asset_id, "item": item_id}


@pytest_asyncio.fixture
async def region_documentee(session, region, creer_fiche, publier):  # noqa: F811
    """Une region a laquelle une fiche publiee rattache la langue de test."""
    content_id = await creer_fiche("DRAFT")
    await session.execute(
        text("UPDATE culture.cultural_contents SET region_id = :r WHERE id = :id"),
        {"r": region, "id": content_id},
    )
    await session.commit()
    await publier(content_id)
    return {"region": region, "fiche": content_id}


# ---------------------------------------------------------------------------
# Mediatheque
# ---------------------------------------------------------------------------
async def test_le_rattachement_vient_d_une_fiche_publiee(
    client, region_documentee, enregistrement  # noqa: F811
):
    """MBOA ne decrete pas quelles langues se parlent ou : une fiche l'etablit."""
    body = (
        await client.get(f"/api/v1/culture/regions/{region_documentee['region']}/media")
    ).json()

    assert body["langues"], "la fiche publiee rattache une langue a la region"
    langue = body["langues"][0]
    assert langue["fiche_id"] == str(region_documentee["fiche"])
    assert langue["fiche_titre"]
    assert "fiche publiée" in body["provenance"]


async def test_les_enregistrements_portent_leur_attribution(
    client, region_documentee, enregistrement  # noqa: F811
):
    """CC BY-SA exige le credit : il voyage avec chaque piste."""
    body = (
        await client.get(f"/api/v1/culture/regions/{region_documentee['region']}/media")
    ).json()

    piste = next(
        p for p in body["enregistrements"] if p["id"] == str(enregistrement["asset"])
    )
    assert piste["attribution"]
    assert piste["license"] == "CC_BY_SA"
    assert piste["lemma"]


async def test_une_region_sans_fiche_n_a_pas_d_enregistrement(
    client, session, region  # noqa: F811
):
    """Sans fiche pour l'etablir, aucun rattachement n'est suppose."""
    vide = (
        await session.execute(text("SELECT id FROM ref.regions WHERE code = 'AD'"))
    ).scalar_one()

    body = (await client.get(f"/api/v1/culture/regions/{vide}/media")).json()
    assert body["langues"] == []
    assert body["enregistrements"] == []
    assert "Aucune fiche publiée" in body["provenance"]


async def test_l_absence_de_video_est_annoncee(
    client, region_documentee  # noqa: F811
):
    """On n'affiche pas de vignette de remplissage : on dit qu'il n'y a rien."""
    body = (
        await client.get(f"/api/v1/culture/regions/{region_documentee['region']}/media")
    ).json()

    assert body["compteurs"]["videos"] == 0
    assert "licence établie" in body["video"]


async def test_une_region_inconnue_repond_404(client):  # noqa: F811
    assert (
        await client.get(f"/api/v1/culture/regions/{uuid.uuid4()}/media")
    ).status_code == 404


# ---------------------------------------------------------------------------
# Favoris
# ---------------------------------------------------------------------------
async def test_mettre_de_cote_une_fiche_et_un_enregistrement(
    client, apprenant, region_documentee, enregistrement  # noqa: F811
):
    fiche = region_documentee["fiche"]
    assert (
        await client.put(
            f"/api/v1/me/favorites/CULTURAL_CONTENT/{fiche}", headers=apprenant
        )
    ).status_code == 201
    assert (
        await client.put(
            f"/api/v1/me/favorites/AUDIO/{enregistrement['asset']}", headers=apprenant
        )
    ).status_code == 201

    body = (await client.get("/api/v1/me/favorites", headers=apprenant)).json()
    assert str(fiche) in {f["id"] for f in body["fiches"]}
    assert str(enregistrement["asset"]) in {e["id"] for e in body["enregistrements"]}
    assert body["total"] == 2


async def test_mettre_deux_fois_de_cote_ne_duplique_pas(
    client, apprenant, region_documentee  # noqa: F811
):
    fiche = region_documentee["fiche"]
    for _ in range(3):
        await client.put(
            f"/api/v1/me/favorites/CULTURAL_CONTENT/{fiche}", headers=apprenant
        )

    body = (await client.get("/api/v1/me/favorites", headers=apprenant)).json()
    assert len([f for f in body["fiches"] if f["id"] == str(fiche)]) == 1


async def test_retirer_un_favori(client, apprenant, region_documentee):  # noqa: F811
    fiche = region_documentee["fiche"]
    await client.put(f"/api/v1/me/favorites/CULTURAL_CONTENT/{fiche}", headers=apprenant)

    etat = (
        await client.get(f"/api/v1/me/favorites/CULTURAL_CONTENT/{fiche}", headers=apprenant)
    ).json()
    assert etat["favori"] is True

    await client.delete(f"/api/v1/me/favorites/CULTURAL_CONTENT/{fiche}", headers=apprenant)
    apres = (
        await client.get(f"/api/v1/me/favorites/CULTURAL_CONTENT/{fiche}", headers=apprenant)
    ).json()
    assert apres["favori"] is False


async def test_un_contenu_non_publie_ne_se_met_pas_de_cote(
    client, apprenant, creer_fiche  # noqa: F811
):
    brouillon = await creer_fiche("DRAFT")
    response = await client.put(
        f"/api/v1/me/favorites/CULTURAL_CONTENT/{brouillon}", headers=apprenant
    )
    assert response.status_code == 404
    assert "pas publié" in response.json()["detail"]


async def test_un_favori_retire_du_catalogue_disparait_des_listes(
    client, session, apprenant, region_documentee  # noqa: F811
):
    """On ne ressert pas un contenu retire, meme s'il a ete aime."""
    fiche = region_documentee["fiche"]
    await client.put(f"/api/v1/me/favorites/CULTURAL_CONTENT/{fiche}", headers=apprenant)

    await session.execute(
        text("UPDATE culture.cultural_contents SET status = 'REJECTED' WHERE id = :id"),
        {"id": fiche},
    )
    await session.commit()

    body = (await client.get("/api/v1/me/favorites", headers=apprenant)).json()
    assert str(fiche) not in {f["id"] for f in body["fiches"]}


async def test_un_type_inconnu_est_refuse(client, apprenant):  # noqa: F811
    response = await client.put(
        f"/api/v1/me/favorites/RECETTE/{uuid.uuid4()}", headers=apprenant
    )
    assert response.status_code == 422
    assert "CULTURAL_CONTENT" in response.json()["detail"]


async def test_le_filtre_par_type(
    client, apprenant, region_documentee, enregistrement  # noqa: F811
):
    await client.put(
        f"/api/v1/me/favorites/CULTURAL_CONTENT/{region_documentee['fiche']}",
        headers=apprenant,
    )
    await client.put(
        f"/api/v1/me/favorites/AUDIO/{enregistrement['asset']}", headers=apprenant
    )

    audios = (
        await client.get("/api/v1/me/favorites?type=AUDIO", headers=apprenant)
    ).json()
    assert audios["fiches"] == []
    assert audios["enregistrements"]


async def test_les_favoris_sont_prives(client):  # noqa: F811
    assert (await client.get("/api/v1/me/favorites")).status_code == 401
    assert (
        await client.put(f"/api/v1/me/favorites/CULTURAL_CONTENT/{uuid.uuid4()}")
    ).status_code == 401
