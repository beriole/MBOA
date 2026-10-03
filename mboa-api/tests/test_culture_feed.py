"""Tests du fil du patrimoine.

Le fil emprunte la forme d'un reseau social : des cartes, des images, des sons,
des commentaires dessous. Ces tests fixent ce que cette forme ne doit pas
emporter avec elle.

Un fil social affiche ce que n'importe qui publie. Celui-ci n'affiche que ce qui
est deja passe par la validation, et il dit ce qui manque au lieu de combler
avec ce qui passe : pas de video d'illustration, pas de mot du vocabulaire
presente comme un chant.
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
async def enregistrement(session, fixture_ids, make_vocab):
    """Un mot publie **sans glose**, avec son enregistrement attribue.

    Le cas sans glose est celui qui compte : c'est la situation reelle du corpus
    aujourd'hui, et c'est la que la tentation de combler serait la plus forte.
    """
    vocab_id = await make_vocab("DRAFT")
    # La base refuse la publication directe (SS2) : le mot suit tout le circuit,
    # exactement comme un mot reel.
    for etape in ("TO_VERIFY", "HUMAN_REVIEW"):
        await session.execute(
            text(
                "UPDATE corpus.vocabulary_items "
                "SET status = CAST(:s AS shared.content_status) WHERE id = :id"
            ),
            {"s": etape, "id": vocab_id},
        )
    await session.execute(
        text(
            """
            INSERT INTO prov.content_validations
                (id, target_type, target_id, validator_contributor_id, decision, decided_at)
            VALUES (:id, 'vocabulary_items', :target, :v, 'ACCEPT', now())
            """
        ),
        {"id": uuid.uuid4(), "target": vocab_id, "v": fixture_ids["validator"]},
    )
    await session.execute(
        text(
            "UPDATE corpus.vocabulary_items SET status='VALIDATED', validated_by=:v, "
            "meaning_fr = NULL WHERE id = :id"
        ),
        {"v": fixture_ids["validator"], "id": vocab_id},
    )
    await session.execute(
        text("UPDATE corpus.vocabulary_items SET status='PUBLISHED' WHERE id = :id"),
        {"id": vocab_id},
    )
    asset_id = uuid.uuid4()
    await session.execute(
        text(
            """
            INSERT INTO audio.audio_assets
                (id, language_id, file_key, target_type, target_id, license,
                 source_id, attribution)
            VALUES (:id, :lang, :key, 'VOCAB', :target,
                    'CC_BY_SA', :source, :attribution)
            """
        ),
        {
            "id": asset_id,
            "lang": fixture_ids["language"],
            "key": f"audio/{asset_id}.wav",
            "target": vocab_id,
            "source": fixture_ids["source"],
            "attribution": "Locuteur de test (Lingua Libre) - CC BY-SA 4.0",
        },
    )
    await session.commit()
    return asset_id


async def test_le_fil_ne_montre_que_du_publie(client, creer_fiche, publier):  # noqa: F811
    brouillon = await creer_fiche("DRAFT")
    publiee = await creer_fiche("DRAFT")
    await publier(publiee)

    fil = (await client.get("/api/v1/culture/feed")).json()
    identifiants = {post["id"] for post in fil["posts"]}
    assert str(publiee) in identifiants
    assert str(brouillon) not in identifiants


async def test_chaque_carte_porte_ce_qui_l_etablit(
    client, creer_fiche, publier  # noqa: F811
):
    """Une fiche cite sa source ; un enregistrement, son attribution."""
    await publier(await creer_fiche("DRAFT"))

    fil = (await client.get("/api/v1/culture/feed")).json()
    assert fil["posts"], "le fil ne doit pas etre vide quand du contenu est publie"

    for post in fil["posts"]:
        assert post["kind"] in ("FICHE", "ENREGISTREMENT")
        # Rien n'entre dans le fil sans repondant exterieur a MBOA.
        assert post["source"] is not None and post["source"]["title"], post["titre"]


async def test_le_fil_annonce_ce_qui_manque_au_lieu_de_l_illustrer(
    client, creer_fiche, publier  # noqa: F811
):
    """Une vidéo d'illustration serait plus grave qu'une case vide."""
    await publier(await creer_fiche("DRAFT"))

    fil = (await client.get("/api/v1/culture/feed")).json()
    manques = {m["kind"]: m["message"] for m in fil["manques"]}

    assert fil["compteurs"]["videos"] == 0
    assert "VIDEO" in manques and "licence établie" in manques["VIDEO"]

    # Le point le plus facile a perdre : les enregistrements disponibles sont
    # des mots isoles. Les afficher sous une rubrique « chants » serait faux.
    assert "CHANT" in manques
    assert "mots isolés" in manques["CHANT"]


async def test_un_enregistrement_n_est_jamais_presente_comme_un_chant(
    client,  # noqa: F811
):
    fil = (await client.get("/api/v1/culture/feed")).json()
    sons = [p for p in fil["posts"] if p["kind"] == "ENREGISTREMENT"]
    for post in sons:
        assert post["categorie"] == "Prononciation"
        assert post["audio_url"].startswith("/api/v1/audio/")
        assert post["attribution"]


async def test_une_glose_absente_n_est_pas_remplacee(
    client, session, enregistrement  # noqa: F811
):
    """Un mot sans sens confirme sort avec un texte nul, pas une approximation.

    C'est la garantie la plus concrete de la regle fondatrice : les gloses du
    corpus disent aujourd'hui « sens à confirmer par un locuteur », et beaucoup
    manquent. Aucune couche d'affichage ne doit les remplir.
    """
    fil = (await client.get("/api/v1/culture/feed?limit=100")).json()
    sons = {p["id"]: p for p in fil["posts"] if p["kind"] == "ENREGISTREMENT"}
    assert str(enregistrement) in sons, "l'enregistrement cree doit entrer dans le fil"
    assert sons[str(enregistrement)]["texte"] is None

    for asset_id, post in sons.items():
        attendu = (
            await session.execute(
                text(
                    """
                    SELECT v.meaning_fr FROM audio.audio_assets a
                    JOIN corpus.vocabulary_items v
                      ON v.id = a.target_id AND a.target_type = 'VOCAB'
                    WHERE a.id = :id
                    """
                ),
                {"id": uuid.UUID(asset_id)},
            )
        ).scalar_one()
        assert post["texte"] == attendu


async def test_le_fil_compte_les_commentaires_sans_les_afficher_dans_la_fiche(
    client, session, creer_fiche, publier  # noqa: F811
):
    """Un avis se compte sous la carte, il n'entre pas dans le contenu."""
    fiche = await creer_fiche("DRAFT")
    await publier(fiche)
    lecteur = await _make_user(client, session, role="LEARNER")

    propos = "Je connaissais cette histoire autrement chez moi."
    await client.post(
        f"/api/v1/social/CULTURAL_CONTENT/{fiche}/comments",
        headers=lecteur,
        json={"body_fr": propos},
    )

    fil = (await client.get("/api/v1/culture/feed")).json()
    post = next(p for p in fil["posts"] if p["id"] == str(fiche))
    assert post["commentaires"] == 1
    # Le propos n'a contamine ni le resume ni le corps de la fiche.
    assert propos not in (post["texte"] or "")
    assert propos not in (post["corps"] or "")


async def test_le_fil_d_une_region_ne_ramasse_pas_tout(
    client, region, creer_fiche, publier, session  # noqa: F811
):
    """Filtrer par region ne doit pas laisser passer les fiches d'ailleurs."""
    region_id = region[0] if isinstance(region, tuple) else region
    fiche = await creer_fiche("DRAFT")
    await session.execute(
        text("UPDATE culture.cultural_contents SET region_id = :r WHERE id = :id"),
        {"r": region_id, "id": fiche},
    )
    await session.commit()
    await publier(fiche)

    fil = (await client.get(f"/api/v1/culture/feed?region_id={region_id}")).json()
    fiches = [p for p in fil["posts"] if p["kind"] == "FICHE"]
    assert fiches, "la fiche rattachee a la region doit sortir"
    for post in fiches:
        assert post["region"] is not None
