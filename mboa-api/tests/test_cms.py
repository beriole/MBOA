"""Tests de l'espace contributeur.

Le scenario central : une forme attestee mais sans traduction devient un
contenu publiable, puis un exercice de sens — sans qu'aucune etape de
validation humaine ne puisse etre contournee.
"""

import uuid

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.db import get_session
from app.main import app
from tests.conftest import TEST_SETTINGS

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def client():
    engine = create_async_engine(TEST_SETTINGS.database_url, poolclass=NullPool)
    maker = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async def _session():
        async with maker() as s:
            try:
                yield s
                await s.commit()
            except Exception:
                await s.rollback()
                raise

    app.dependency_overrides[get_session] = _session
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
    await engine.dispose()


async def _make_user(client, session, *, role: str, contributor_id=None, language_id=None):
    """Cree un compte, eventuellement lie a un contributeur habilite."""
    email = f"u-{uuid.uuid4().hex[:10]}@example.com"
    tokens = (
        await client.post(
            "/api/v1/auth/register",
            json={"email": email, "password": "motdepasse-solide", "display_name": "Test"},
        )
    ).json()

    if role != "LEARNER":
        await session.execute(
            text("UPDATE iam.users SET role = CAST(:r AS shared.user_role) WHERE email = :e"),
            {"r": role, "e": email},
        )
    if contributor_id is not None:
        user_id = (
            await session.execute(
                text("SELECT id FROM iam.users WHERE email = :e"), {"e": email}
            )
        ).scalar_one()
        await session.execute(
            text("UPDATE prov.contributors SET user_id = :uid WHERE id = :cid"),
            {"uid": user_id, "cid": contributor_id},
        )
        if language_id is not None:
            await session.execute(
                text(
                    """
                    INSERT INTO prov.validation_assignments
                        (id, contributor_id, language_id, scope, is_active)
                    VALUES (:id, :cid, :lang, ARRAY['LEXICON'], true)
                    ON CONFLICT (contributor_id, language_id) DO UPDATE SET is_active = true
                    """
                ),
                {"id": uuid.uuid4(), "cid": contributor_id, "lang": language_id},
            )
    await session.commit()
    return {"Authorization": f"Bearer {tokens['access_token']}"}


@pytest_asyncio.fixture
async def redacteur(client, session, fixture_ids):
    """Contributeur qui saisit les gloses."""
    return await _make_user(
        client,
        session,
        role="CULTURAL_SPECIALIST",
        contributor_id=fixture_ids["author"],
        language_id=fixture_ids["language"],
    )


@pytest_asyncio.fixture
async def validateur(client, session, fixture_ids):
    """Contributeur habilite qui relit et valide."""
    return await _make_user(
        client,
        session,
        role="CULTURAL_SPECIALIST",
        contributor_id=fixture_ids["validator"],
        language_id=fixture_ids["language"],
    )



async def _without_gloss(session, item_id):
    """La fixture partagee renseigne toujours une glose : ici on la retire,
    pour reproduire l'etat reel du corpus importe (forme attestee, sens inconnu)."""
    await session.execute(
        text("UPDATE corpus.vocabulary_items SET meaning_fr = NULL WHERE id = :id"),
        {"id": item_id},
    )
    await session.commit()
    return item_id


# ---------------------------------------------------------------------------
# Acces
# ---------------------------------------------------------------------------
async def test_un_apprenant_n_entre_pas_dans_l_espace_contributeur(client, session, fixture_ids):
    headers = await _make_user(client, session, role="LEARNER")
    response = await client.get(
        f"/api/v1/cms/queue?language_id={fixture_ids['language']}", headers=headers
    )
    assert response.status_code == 403
    assert "specialistes" in response.json()["detail"]


async def test_specialiste_sans_fiche_contributeur_refuse(client, session, fixture_ids):
    headers = await _make_user(client, session, role="CULTURAL_SPECIALIST")
    response = await client.get(
        f"/api/v1/cms/queue?language_id={fixture_ids['language']}", headers=headers
    )
    assert response.status_code == 403
    assert "contributeur" in response.json()["detail"]


async def test_habilitation_limitee_a_ses_langues(client, session, fixture_ids, redacteur):
    autre_langue = uuid.uuid4()
    await session.execute(
        text(
            "INSERT INTO ref.languages (id, iso639_3, name) VALUES (:id, 'zxy', 'Autre langue')"
        ),
        {"id": autre_langue},
    )
    await session.commit()

    response = await client.get(
        f"/api/v1/cms/queue?language_id={autre_langue}", headers=redacteur
    )
    assert response.status_code == 403
    assert "habilite" in response.json()["detail"]


# ---------------------------------------------------------------------------
# File de travail
# ---------------------------------------------------------------------------
async def test_la_file_met_en_avant_les_mots_sans_traduction(
    client, session, fixture_ids, make_vocab, redacteur
):
    await _without_gloss(session, await make_vocab(status="TO_VERIFY"))
    await _without_gloss(session, await make_vocab(status="TO_VERIFY"))

    data = (
        await client.get(
            f"/api/v1/cms/queue?language_id={fixture_ids['language']}", headers=redacteur
        )
    ).json()

    assert data["missing_gloss"] >= 2
    assert all(item["has_gloss"] is False for item in data["items"][:2])
    # La provenance accompagne chaque entree : on valide en voyant la source.
    assert data["items"][0]["source_title"] is not None


# ---------------------------------------------------------------------------
# Saisie et validation
# ---------------------------------------------------------------------------
async def test_parcours_complet_d_une_glose(
    client, session, fixture_ids, make_vocab, redacteur, validateur
):
    """Saisie par un contributeur, validation par un autre, puis publication."""
    item = await make_vocab(status="TO_VERIFY")

    edit = await client.patch(
        f"/api/v1/cms/vocabulary/{item}",
        json={"meaning_fr": "traduction de test", "grammatical_category": "NOUN"},
        headers=redacteur,
    )
    assert edit.status_code == 200, edit.text
    assert edit.json()["status"] == "HUMAN_REVIEW"

    decision = await client.post(
        f"/api/v1/cms/vocabulary/{item}/decision",
        json={"decision": "ACCEPT", "comment": "Forme et sens confirmes."},
        headers=validateur,
    )
    assert decision.status_code == 200, decision.text
    assert decision.json()["status"] == "VALIDATED"

    publication = await client.post(
        f"/api/v1/cms/vocabulary/{item}/publish", headers=validateur
    )
    assert publication.status_code == 200
    assert publication.json()["status"] == "PUBLISHED"

    # La decision est tracee, et l'historique des statuts aussi.
    trace = (
        await session.execute(
            text(
                """
                SELECT decision::text, comment FROM prov.content_validations
                WHERE target_id = :id AND decision = 'ACCEPT'
                """
            ),
            {"id": item},
        )
    ).one()
    assert trace[1] == "Forme et sens confirmes."


async def test_on_ne_valide_pas_sa_propre_saisie(
    client, session, fixture_ids, make_vocab, redacteur
):
    item = await make_vocab(status="TO_VERIFY", created_by=fixture_ids["author"])
    await client.patch(
        f"/api/v1/cms/vocabulary/{item}", json={"meaning_fr": "essai"}, headers=redacteur
    )

    response = await client.post(
        f"/api/v1/cms/vocabulary/{item}/decision", json={"decision": "ACCEPT"}, headers=redacteur
    )
    assert response.status_code == 409
    assert "autre contributeur" in response.json()["detail"]


async def test_validation_impossible_sans_traduction(
    client, session, make_vocab, validateur
):
    item = await _without_gloss(session, await make_vocab(status="TO_VERIFY"))
    response = await client.post(
        f"/api/v1/cms/vocabulary/{item}/decision", json={"decision": "ACCEPT"}, headers=validateur
    )
    assert response.status_code == 409
    assert "traduction" in response.json()["detail"]


async def test_publication_impossible_sans_validation(client, make_vocab, validateur):
    item = await make_vocab(status="TO_VERIFY")
    response = await client.post(f"/api/v1/cms/vocabulary/{item}/publish", headers=validateur)
    assert response.status_code == 409
    assert "VALIDATED" in response.json()["detail"]


async def test_modifier_un_contenu_publie_le_renvoie_en_relecture(
    client, session, fixture_ids, make_vocab, redacteur, validateur
):
    """Une correction ne peut pas contourner la validation humaine."""
    item = await make_vocab(status="TO_VERIFY")
    await client.patch(
        f"/api/v1/cms/vocabulary/{item}", json={"meaning_fr": "premier sens"}, headers=redacteur
    )
    await client.post(
        f"/api/v1/cms/vocabulary/{item}/decision", json={"decision": "ACCEPT"}, headers=validateur
    )
    await client.post(f"/api/v1/cms/vocabulary/{item}/publish", headers=validateur)

    correction = await client.patch(
        f"/api/v1/cms/vocabulary/{item}",
        json={"meaning_fr": "sens corrige"},
        headers=redacteur,
    )
    assert correction.status_code == 200
    assert correction.json()["status"] == "HUMAN_REVIEW", "le contenu repasse en relecture"

    status_en_base = (
        await session.execute(
            text("SELECT status::text FROM corpus.vocabulary_items WHERE id = :id"),
            {"id": item},
        )
    ).scalar_one()
    assert status_en_base == "HUMAN_REVIEW"


async def test_demande_de_modification_renvoie_dans_la_file(
    client, make_vocab, redacteur, validateur
):
    item = await make_vocab(status="TO_VERIFY")
    await client.patch(
        f"/api/v1/cms/vocabulary/{item}", json={"meaning_fr": "sens douteux"}, headers=redacteur
    )
    response = await client.post(
        f"/api/v1/cms/vocabulary/{item}/decision",
        json={"decision": "REQUEST_CHANGES", "comment": "Verifier le ton."},
        headers=validateur,
    )
    assert response.json()["status"] == "TO_VERIFY"


async def test_rejet_definitif(client, make_vocab, redacteur, validateur):
    item = await make_vocab(status="TO_VERIFY")
    response = await client.post(
        f"/api/v1/cms/vocabulary/{item}/decision",
        json={"decision": "REJECT", "comment": "Etiquette non fiable."},
        headers=validateur,
    )
    assert response.json()["status"] == "REJECTED"


async def test_correction_orthographique_normalisee_en_nfc(
    client, session, make_vocab, redacteur
):
    """Une saisie clavier en NFD est normalisee : sinon deux graphies coexisteraient."""
    item = await make_vocab(status="TO_VERIFY")
    await client.patch(
        f"/api/v1/cms/vocabulary/{item}",
        json={"lemma": "élep"},  # « e » + accent combinant
        headers=redacteur,
    )
    lemma = (
        await session.execute(
            text("SELECT lemma FROM corpus.vocabulary_items WHERE id = :id"), {"id": item}
        )
    ).scalar_one()
    assert lemma == "élep", "la forme est stockee en NFC"


async def test_saisir_une_glose_rend_auteur_meme_sur_un_import(
    client, session, fixture_ids, make_vocab, redacteur
):
    """Cas reel du corpus importe : `created_by` vaut l'import automatique.

    Celui qui saisit la traduction en devient l'auteur : il ne peut donc plus
    la valider lui-meme.
    """
    item = await make_vocab(status="TO_VERIFY")
    importeur = uuid.uuid4()
    await session.execute(
        text(
            "INSERT INTO prov.contributors (id, display_name, role) "
            "VALUES (:id, 'Import automatique', 'EDITOR')"
        ),
        {"id": importeur},
    )
    await session.execute(
        text("UPDATE corpus.vocabulary_items SET created_by = :c WHERE id = :id"),
        {"c": importeur, "id": item},
    )
    await session.commit()

    await client.patch(
        f"/api/v1/cms/vocabulary/{item}", json={"meaning_fr": "ma traduction"}, headers=redacteur
    )
    response = await client.post(
        f"/api/v1/cms/vocabulary/{item}/decision", json={"decision": "ACCEPT"}, headers=redacteur
    )
    assert response.status_code == 409
    assert "autre contributeur" in response.json()["detail"]
