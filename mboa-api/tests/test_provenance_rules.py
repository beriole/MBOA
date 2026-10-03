"""Tests des regles d'integrite du contenu.

Ces tests sont la preuve executable de la promesse centrale de MBOA :
il est techniquement impossible de publier un contenu linguistique sans source
identifiee et sans validation par un humain habilite.

Les regles sont portees par PostgreSQL : elles resistent donc a un bug applicatif,
a un script d'import maladroit ou a un acces direct par psql.
"""

import uuid

import pytest
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError

pytestmark = pytest.mark.asyncio


async def _set_status(session, item_id, status, **cols):
    assignments = ", ".join(f"{k} = :{k}" for k in cols)
    prefix = f"{assignments}, " if assignments else ""
    await session.execute(
        text(
            f"""
            UPDATE corpus.vocabulary_items
            SET {prefix} status = CAST(:status AS shared.content_status)
            WHERE id = :id
            """
        ),
        {"id": item_id, "status": status, **cols},
    )
    await session.commit()


# ---------------------------------------------------------------------------
# SS4 : pas de contenu exploitable sans source
# ---------------------------------------------------------------------------
async def test_validation_refusee_sans_source(session, make_vocab, fixture_ids, accept_decision):
    """Un item sans source ne peut pas etre valide, meme si tout le reste est correct."""
    item = await make_vocab(status="DRAFT", with_source=False)
    await accept_decision("vocabulary_items", item)

    with pytest.raises(DBAPIError) as exc:
        await _set_status(session, item, "VALIDATED", validated_by=fixture_ids["validator"])

    assert "source_manquante" in str(exc.value)


# ---------------------------------------------------------------------------
# SS2 : aucun contenu genere ne passe directement a PUBLISHED
# ---------------------------------------------------------------------------
async def test_publication_directe_refusee(session, make_vocab):
    """DRAFT -> PUBLISHED est interdit : il faut passer par VALIDATED."""
    item = await make_vocab(status="DRAFT")

    with pytest.raises(DBAPIError) as exc:
        await _set_status(session, item, "PUBLISHED")

    assert "publication_directe" in str(exc.value)


async def test_insertion_directe_en_published_refusee(session, make_vocab):
    """Meme une insertion initiale en PUBLISHED est bloquee."""
    with pytest.raises(DBAPIError) as exc:
        await make_vocab(status="PUBLISHED")

    assert "publication_directe" in str(exc.value)


# ---------------------------------------------------------------------------
# SS5 : validation humaine effective
# ---------------------------------------------------------------------------
async def test_validation_sans_validateur_refusee(session, make_vocab):
    item = await make_vocab(status="DRAFT")

    with pytest.raises(DBAPIError) as exc:
        await _set_status(session, item, "VALIDATED")

    assert "validateur_manquant" in str(exc.value)


async def test_auto_validation_refusee(session, make_vocab, fixture_ids, accept_decision):
    """Le redacteur ne peut pas valider son propre travail."""
    item = await make_vocab(status="DRAFT", created_by=fixture_ids["author"])
    await accept_decision("vocabulary_items", item, validator=fixture_ids["author"])

    with pytest.raises(DBAPIError) as exc:
        await _set_status(session, item, "VALIDATED", validated_by=fixture_ids["author"])

    assert "auto_validation" in str(exc.value)


async def test_validation_sans_decision_enregistree_refusee(session, make_vocab, fixture_ids):
    """Renseigner `validated_by` ne suffit pas : une decision ACCEPT doit exister."""
    item = await make_vocab(status="DRAFT")

    with pytest.raises(DBAPIError) as exc:
        await _set_status(session, item, "VALIDATED", validated_by=fixture_ids["validator"])

    assert "decision_absente" in str(exc.value)


async def test_validateur_non_habilite_refuse(session, make_vocab, accept_decision):
    """Un validateur sans habilitation pour cette langue est rejete."""
    intrus = uuid.uuid4()
    await session.execute(
        text(
            "INSERT INTO prov.contributors (id, display_name, role) "
            "VALUES (:id, 'Contributeur non habilite', 'EDITOR')"
        ),
        {"id": intrus},
    )
    await session.commit()

    item = await make_vocab(status="DRAFT")
    await accept_decision("vocabulary_items", item, validator=intrus)

    with pytest.raises(DBAPIError) as exc:
        await _set_status(session, item, "VALIDATED", validated_by=intrus)

    assert "validateur_non_habilite" in str(exc.value)


# ---------------------------------------------------------------------------
# Chemin nominal complet
# ---------------------------------------------------------------------------
async def test_parcours_complet_du_contenu(session, make_vocab, fixture_ids, accept_decision):
    """DRAFT -> SOURCE_FOUND -> TO_VERIFY -> HUMAN_REVIEW -> VALIDATED -> PUBLISHED."""
    item = await make_vocab(status="DRAFT")

    for etape in ("SOURCE_FOUND", "TO_VERIFY", "HUMAN_REVIEW"):
        await _set_status(session, item, etape)

    await accept_decision("vocabulary_items", item)
    await _set_status(session, item, "VALIDATED", validated_by=fixture_ids["validator"])

    row = (
        await session.execute(
            text(
                "SELECT status::text, validated_at IS NOT NULL "
                "FROM corpus.vocabulary_items WHERE id = :id"
            ),
            {"id": item},
        )
    ).one()
    assert row[0] == "VALIDATED"
    assert row[1] is True, "validated_at doit etre horodate automatiquement"

    await _set_status(session, item, "PUBLISHED")
    row = (
        await session.execute(
            text(
                "SELECT status::text, published_at IS NOT NULL "
                "FROM corpus.vocabulary_items WHERE id = :id"
            ),
            {"id": item},
        )
    ).one()
    assert row[0] == "PUBLISHED"
    assert row[1] is True


async def test_journal_des_transitions(session, make_vocab, fixture_ids, accept_decision):
    """Chaque changement de statut est trace, pour l'audit et le rapport de subvention."""
    item = await make_vocab(status="DRAFT")
    await _set_status(session, item, "TO_VERIFY")
    await accept_decision("vocabulary_items", item)
    await _set_status(session, item, "VALIDATED", validated_by=fixture_ids["validator"])

    transitions = (
        await session.execute(
            text(
                "SELECT from_status, to_status FROM prov.status_transitions "
                "WHERE target_id = :id ORDER BY occurred_at"
            ),
            {"id": item},
        )
    ).all()

    assert [t[1] for t in transitions] == ["DRAFT", "TO_VERIFY", "VALIDATED"]
    assert transitions[0][0] is None


# ---------------------------------------------------------------------------
# Normalisation Unicode : indispensable pour les langues a tons
# ---------------------------------------------------------------------------
async def test_forme_non_nfc_refusee(session, fixture_ids):
    """Une forme non normalisee NFC est rejetee : sinon deux ecritures visuellement
    identiques seraient traitees comme deux mots differents."""
    # "e" + accent aigu combinant (NFD) au lieu du caractere precompose (NFC).
    forme_nfd = "é-test"

    with pytest.raises(DBAPIError) as exc:
        await session.execute(
            text(
                """
                INSERT INTO corpus.vocabulary_items
                    (id, language_id, lemma, lemma_toneless, grammatical_category,
                     meaning_fr, status, source_id, difficulty, tags)
                VALUES (:id, :lang, :lemma, :lemma, 'NOUN', 'test', 'DRAFT', :src, 1, ARRAY[]::text[])
                """
            ),
            {
                "id": uuid.uuid4(),
                "lang": fixture_ids["language"],
                "lemma": forme_nfd,
                "src": fixture_ids["source"],
            },
        )
        await session.commit()

    assert "lemma_nfc" in str(exc.value)
    await session.rollback()
