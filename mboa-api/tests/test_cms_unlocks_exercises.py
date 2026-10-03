"""La contribution debloque les exercices de sens.

C'est la demonstration centrale du projet : tant qu'aucun locuteur natif n'a
traduit les mots, MBOA ne propose que des exercices d'ecoute. Des que des
traductions sont validees et publiees, les exercices de sens apparaissent —
et ils passent eux aussi par une revue humaine (SS13).
"""

import uuid

import pytest
import pytest_asyncio
from sqlalchemy import text

from tests.test_cms import _make_user, client, redacteur, validateur  # noqa: F401

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def unite(session, fixture_ids):
    """Une unite rattachee a un cours publie, avec ses mots cibles."""
    course, section, unit = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    params = {
        "course": course,
        "section": section,
        "unit": unit,
        "lang": fixture_ids["language"],
        "src": fixture_ids["source"],
    }
    await session.execute(
        text(
            """
            INSERT INTO learn.courses (id, language_id, level, title_fr, status, source_id)
            VALUES (:course, :lang, 'N0', 'Cours de test', 'DRAFT', :src);
            """
        ),
        params,
    )
    await session.execute(
        text(
            """
            INSERT INTO learn.sections (id, course_id, position, title_fr, status, source_id)
            VALUES (:section, :course, 0, 'Section de test', 'DRAFT', :src)
            """
        ),
        params,
    )
    await session.execute(
        text(
            """
            INSERT INTO learn.units
                (id, section_id, position, title_fr, objective_fr, status, source_id)
            VALUES (:unit, :section, 0, 'Unite de test', 'Objectif', 'DRAFT', :src)
            """
        ),
        params,
    )
    await session.commit()
    return unit


async def _publish_word(client, session, fixture_ids, redacteur, validateur, make_vocab, gloss):
    """Cree un mot, le fait traduire, valider puis publier."""
    item = await make_vocab(status="TO_VERIFY")
    await client.patch(
        f"/api/v1/cms/vocabulary/{item}", json={"meaning_fr": gloss}, headers=redacteur
    )
    await client.post(
        f"/api/v1/cms/vocabulary/{item}/decision", json={"decision": "ACCEPT"}, headers=validateur
    )
    await client.post(f"/api/v1/cms/vocabulary/{item}/publish", headers=validateur)
    return item


async def _attach_to_unit(session, unit, item_ids):
    await session.execute(
        text("UPDATE learn.units SET target_vocab_ids = :ids WHERE id = :id"),
        {"ids": item_ids, "id": unit},
    )
    await session.commit()



async def _exercise_for(session, item_id):
    """Retrouve l'exercice dont la bonne reponse est ce mot precis.

    La base de test est partagee entre les tests : on ne peut pas se contenter
    de prendre « le premier exercice ».
    """
    return (
        await session.execute(
            text(
                """
                SELECT id, payload, status::text AS status, created_by
                FROM learn.exercises
                WHERE type = 'MULTIPLE_CHOICE' AND answer_spec->>'correct_id' = :id
                """
            ),
            {"id": str(item_id)},
        )
    ).one()


async def test_sans_traductions_aucun_exercice_de_sens(
    client, session, fixture_ids, make_vocab, redacteur, unite
):
    """Trois mots traduits ne suffisent pas : il faut de vrais distracteurs."""
    items = [await make_vocab(status="TO_VERIFY") for _ in range(3)]
    await session.execute(
        text("UPDATE corpus.vocabulary_items SET meaning_fr = NULL WHERE id = ANY(:ids)"),
        {"ids": items},
    )
    await session.commit()
    await _attach_to_unit(session, unite, items)

    result = (
        await client.post(f"/api/v1/cms/units/{unite}/generate-exercises", headers=redacteur)
    ).json()

    assert result["created"] == 0
    assert result["glossed_words"] == 0
    assert "4" in result["message"]


async def test_quatre_traductions_publiees_debloquent_les_exercices(
    client, session, fixture_ids, make_vocab, redacteur, validateur, unite
):
    items = []
    for index in range(4):
        items.append(
            await _publish_word(
                client, session, fixture_ids, redacteur, validateur, make_vocab,
                f"sens numero {index}",
            )
        )
    await _attach_to_unit(session, unite, items)

    result = (
        await client.post(f"/api/v1/cms/units/{unite}/generate-exercises", headers=redacteur)
    ).json()
    assert result["created"] == 4, result
    assert result["glossed_words"] == 4

    # Les exercices existent mais ne sont PAS publies : ils attendent une revue.
    pending = (
        await client.get(
            f"/api/v1/cms/exercises/pending?language_id={fixture_ids['language']}",
            headers=redacteur,
        )
    ).json()
    assert len(pending) == 4
    assert {e["status"] for e in pending} == {"DRAFT"}
    assert {e["type"] for e in pending} == {"MULTIPLE_CHOICE"}

    # Aucun de ces exercices n'est encore visible par un apprenant.
    published = (
        await session.execute(
            text(
                """
                SELECT count(*) FROM learn.exercises
                WHERE type = 'MULTIPLE_CHOICE' AND status = 'PUBLISHED'
                """
            )
        )
    ).scalar_one()
    assert published == 0

    # Un autre contributeur valide : l'exercice devient visible.
    decision = await client.post(
        f"/api/v1/cms/exercises/{pending[0]['id']}/decision",
        json={"decision": "ACCEPT"},
        headers=validateur,
    )
    assert decision.json()["status"] == "PUBLISHED"


async def test_le_generateur_de_son_propre_exercice_ne_le_valide_pas(
    client, session, fixture_ids, make_vocab, redacteur, validateur, unite
):
    items = [
        await _publish_word(
            client, session, fixture_ids, redacteur, validateur, make_vocab, f"sens {i}"
        )
        for i in range(4)
    ]
    await _attach_to_unit(session, unite, items)
    await client.post(f"/api/v1/cms/units/{unite}/generate-exercises", headers=redacteur)

    mien = await _exercise_for(session, items[0])
    response = await client.post(
        f"/api/v1/cms/exercises/{mien.id}/decision",
        json={"decision": "ACCEPT"},
        headers=redacteur,
    )
    assert response.status_code == 409
    assert "autre contributeur" in response.json()["detail"]


async def test_les_distracteurs_sont_des_gloses_reelles(
    client, session, fixture_ids, make_vocab, redacteur, validateur, unite
):
    """Une mauvaise reponse doit rester une traduction attestee d'un autre mot."""
    gloses = {f"sens authentique {i}" for i in range(4)}
    items = []
    for gloss in sorted(gloses):
        items.append(
            await _publish_word(
                client, session, fixture_ids, redacteur, validateur, make_vocab, gloss
            )
        )
    await _attach_to_unit(session, unite, items)
    await client.post(f"/api/v1/cms/units/{unite}/generate-exercises", headers=redacteur)

    payload = (await _exercise_for(session, items[0])).payload

    proposees = {choice["text"] for choice in payload["choices"]}
    assert proposees <= gloses, "aucun choix ne sort du corpus valide"
    assert len(proposees) == 4
