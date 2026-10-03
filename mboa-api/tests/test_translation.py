"""Tests de la traduction par recherche dans le corpus (SS41).

La promesse testee ici : MBOA ne renvoie que des formes publiees et verifiees,
dit clairement quand il ne trouve rien, et trace chaque demande.
"""

import unicodedata
import uuid

import pytest
import pytest_asyncio
from sqlalchemy import text

from app.modules.translation import service
from tests.test_cms import _make_user, client  # noqa: F401

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def apprenant(client, session):
    return await _make_user(client, session, role="LEARNER")


@pytest_asyncio.fixture
async def publier(session, fixture_ids):
    """Publie une entree du corpus, avec sa glose et son audio."""

    async def _make(lemma: str, meaning: str | None, *, with_audio: bool = True):
        item_id = uuid.uuid4()
        audio_id = uuid.uuid4() if with_audio else None
        if with_audio:
            await session.execute(
                text(
                    """
                    INSERT INTO audio.audio_assets
                        (id, language_id, file_key, target_type, target_id,
                         license, attribution)
                    VALUES (:id, :lang, 'https://example.org/a.wav', 'VOCAB', :target,
                            'CC_BY_SA', 'Locuteur test - CC BY-SA 4.0')
                    """
                ),
                {"id": audio_id, "lang": fixture_ids["language"], "target": item_id},
            )
        normalized = unicodedata.normalize("NFC", lemma)
        await session.execute(
            text(
                """
                INSERT INTO corpus.vocabulary_items
                    (id, language_id, lemma, lemma_toneless, grammatical_category,
                     meaning_fr, status, source_id, created_by, primary_audio_id)
                VALUES (:id, :lang, :lemma, :toneless, 'NOUN', :meaning,
                        'DRAFT', :src, :by, :audio)
                """
            ),
            {
                "id": item_id,
                "lang": fixture_ids["language"],
                "lemma": normalized,
                "toneless": service.strip_tones(normalized),
                "meaning": meaning,
                "src": fixture_ids["source"],
                "by": fixture_ids["author"],
                "audio": audio_id,
            },
        )
        # Circuit complet : une entree non validee ne doit jamais sortir.
        for step in ("TO_VERIFY", "HUMAN_REVIEW"):
            await session.execute(
                text(
                    "UPDATE corpus.vocabulary_items "
                    "SET status = CAST(:s AS shared.content_status) WHERE id = :id"
                ),
                {"s": step, "id": item_id},
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
        await session.commit()
        return item_id

    return _make


async def _translate(client, apprenant, language_id, texte, *, into_french=True):
    response = await client.post(
        "/api/v1/translate",
        json={"language_id": str(language_id), "text": texte, "into_french": into_french},
        headers=apprenant,
    )
    assert response.status_code == 200, response.text
    return response.json()


# ---------------------------------------------------------------------------
# Correspondances
# ---------------------------------------------------------------------------
async def test_correspondance_exacte(client, apprenant, fixture_ids, publier):
    await publier("màlep-test", "eau de test")

    data = await _translate(client, apprenant, fixture_ids["language"], "màlep-test")

    assert data["confidence"] == 1.0
    assert data["mode"] == "LEXICON"
    assert data["matches"][0]["meaning_fr"] == "eau de test"
    assert data["matches"][0]["kind"] == "EXACT"
    # La provenance accompagne la reponse : on sait d'ou elle vient.
    # La licence affichee est celle de la source du mot (ici Common Voice, CC0).
    assert data["matches"][0]["source_license"] == "CC0"
    assert data["matches"][0]["audio_url"].startswith("/api/v1/audio/")


async def test_correspondance_sans_les_tons(client, apprenant, fixture_ids, publier):
    """Un apprenant tape rarement les diacritiques : on retrouve quand meme le mot,
    mais on l'avertit."""
    await publier("bìjɛk-test", "nourriture de test")

    data = await _translate(client, apprenant, fixture_ids["language"], "bijɛk-test")

    assert data["matches"][0]["kind"] == "TONELESS"
    assert data["confidence"] == 0.8
    assert "tons" in data["message"]


async def test_recherche_au_clavier_ordinaire(client, apprenant, fixture_ids, publier):
    """Taper « basaa » doit retrouver « ɓasaá » : sinon la fonction est
    inutilisable depuis un telephone."""
    await publier("ɓasaá-test", "la langue basaa")

    data = await _translate(client, apprenant, fixture_ids["language"], "basaa-test")

    assert data["matches"], "le mot doit etre retrouve sans les lettres speciales"
    assert data["matches"][0]["kind"] == "FOLDED"
    assert data["confidence"] == 0.7
    # L'orthographe exacte est rappelee : on aide sans laisser croire que
    # « basaa » est une graphie valide.
    assert "ɓasaá-test" in data["message"]
    assert "ɛ" in data["message"]


async def test_faute_de_frappe_signalee_comme_approchante(
    client, apprenant, fixture_ids, publier
):
    await publier("mitoumba-test", "sens de test")

    data = await _translate(client, apprenant, fixture_ids["language"], "mitouba-test")

    assert data["matches"], "une forme proche doit etre proposee"
    assert data["matches"][0]["kind"] == "FUZZY"
    assert data["matches"][0]["confidence"] < 1.0
    assert "confirmer" in data["message"]


async def test_sens_francais_vers_forme_locale(client, apprenant, fixture_ids, publier):
    await publier("ngweha-test", "salutation de test")

    data = await _translate(
        client, apprenant, fixture_ids["language"], "salutation de test", into_french=False
    )

    assert data["matches"][0]["lemma"] == "ngweha-test"


# ---------------------------------------------------------------------------
# Ce que la traduction refuse de faire
# ---------------------------------------------------------------------------
async def test_mot_inconnu_ne_produit_aucune_invention(client, apprenant, fixture_ids):
    data = await _translate(
        client, apprenant, fixture_ids["language"], "zzzquelquechosedintrouvable"
    )

    assert data["matches"] == []
    assert data["confidence"] is None
    assert "Aucune correspondance" in data["message"]
    assert "vérifiés par des locuteurs" in data["message"]


async def test_une_entree_non_publiee_reste_invisible(
    client, session, apprenant, fixture_ids, make_vocab
):
    """Le corpus en cours de validation ne doit jamais fuiter par la traduction."""
    item = await make_vocab(status="HUMAN_REVIEW")
    lemma = (
        await session.execute(
            text("SELECT lemma FROM corpus.vocabulary_items WHERE id = :id"), {"id": item}
        )
    ).scalar_one()

    data = await _translate(client, apprenant, fixture_ids["language"], lemma)

    # D'autres mots publies peuvent ressembler a ce lemme : ce qui compte est que
    # l'entree non publiee, elle, n'apparaisse jamais.
    renvoyes = {m["vocabulary_id"] for m in data["matches"]}
    assert str(item) not in renvoyes
    assert all(m["lemma"] != lemma for m in data["matches"])


async def test_un_mot_sans_glose_ne_repond_pas_au_francais(
    client, apprenant, fixture_ids, publier
):
    """Une forme attestee mais non traduite ne peut pas repondre a une recherche
    en francais : il n'y a rien a chercher."""
    await publier("litowa-test", None)

    data = await _translate(
        client, apprenant, fixture_ids["language"], "litowa-test", into_french=False
    )
    assert data["matches"] == []


async def test_le_mode_reste_lexical(client, apprenant, fixture_ids, publier):
    """Aucun modele n'est entraine : le mode ne doit jamais basculer en MODEL."""
    await publier("soulouk-test", "sens de test")
    data = await _translate(client, apprenant, fixture_ids["language"], "soulouk-test")

    assert data["mode"] == "LEXICON"
    assert data["model"] == "lexicon-search"
    assert "ne traduit pas de phrases libres" in data["disclaimer"]


# ---------------------------------------------------------------------------
# Tracabilite
# ---------------------------------------------------------------------------
async def test_chaque_demande_est_tracee(client, session, apprenant, fixture_ids, publier):
    await publier("mbombo-test", "sens de test")
    data = await _translate(client, apprenant, fixture_ids["language"], "mbombo-test")

    trace = (
        await session.execute(
            text(
                """
                SELECT source_code, target_code, mode::text AS mode, model, model_version,
                       confidence, match_count, human_validation::text AS human_validation
                FROM translate.translation_requests WHERE id = :id
                """
            ),
            {"id": data["request_id"]},
        )
    ).one()

    assert trace.target_code == "fr"
    assert trace.mode == "LEXICON"
    assert trace.model_version == "1.0"
    assert trace.confidence == 1.0
    assert trace.match_count >= 1
    assert trace.human_validation == "NONE"


async def test_signalement_par_l_utilisateur(client, session, apprenant, fixture_ids, publier):
    await publier("ndi-laa-test", "sens douteux")
    data = await _translate(client, apprenant, fixture_ids["language"], "ndi-laa-test")

    response = await client.post(
        f"/api/v1/translate/{data['request_id']}/report",
        json={"comment": "Ce sens ne me semble pas juste."},
        headers=apprenant,
    )
    assert response.status_code == 200
    assert response.json()["status"] == "REQUESTED"

    trace = (
        await session.execute(
            text(
                "SELECT human_validation::text, report_comment "
                "FROM translate.translation_requests WHERE id = :id"
            ),
            {"id": data["request_id"]},
        )
    ).one()
    assert trace[0] == "REQUESTED"
    assert "pas juste" in trace[1]


async def test_historique_personnel(client, apprenant, fixture_ids, publier):
    await publier("mbongo-test", "sens de test")
    await _translate(client, apprenant, fixture_ids["language"], "mbongo-test")

    historique = (await client.get("/api/v1/translate/history", headers=apprenant)).json()
    assert any(h["input_text"] == "mbongo-test" for h in historique)


async def test_traduction_protegee_par_authentification(client, fixture_ids):
    response = await client.post(
        "/api/v1/translate",
        json={"language_id": str(fixture_ids["language"]), "text": "essai"},
    )
    assert response.status_code == 401
