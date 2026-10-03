"""Un exercice ne peut citer que du contenu valide (SS13), verifie par PostgreSQL."""

import json
import uuid

import pytest
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError

pytestmark = pytest.mark.asyncio


async def _insert_exercise(session, fixture_ids, origins, status="DRAFT"):
    await session.execute(
        text(
            """
            INSERT INTO learn.exercises
                (id, language_id, type, payload, answer_spec, generated_from,
                 status, source_id, created_by)
            VALUES (:id, :lang, 'LISTEN_AND_CHOOSE', '{}'::jsonb, '{}'::jsonb,
                    CAST(:origins AS jsonb), CAST(:status AS shared.content_status),
                    :src, :by)
            """
        ),
        {
            "id": uuid.uuid4(),
            "lang": fixture_ids["language"],
            "origins": json.dumps(origins),
            "status": status,
            "src": fixture_ids["source"],
            "by": fixture_ids["author"],
        },
    )
    await session.commit()


async def _validate(session, item_id, fixture_ids, accept_decision):
    for step in ("TO_VERIFY", "HUMAN_REVIEW"):
        await session.execute(
            text(
                "UPDATE corpus.vocabulary_items "
                "SET status = CAST(:s AS shared.content_status) WHERE id = :id"
            ),
            {"s": step, "id": item_id},
        )
    await session.commit()
    await accept_decision("vocabulary_items", item_id)
    await session.execute(
        text(
            "UPDATE corpus.vocabulary_items SET status='VALIDATED', validated_by=:v WHERE id=:id"
        ),
        {"v": fixture_ids["validator"], "id": item_id},
    )
    await session.commit()


async def test_exercice_citant_un_brouillon_refuse(session, fixture_ids, make_vocab):
    draft = await make_vocab(status="DRAFT")
    with pytest.raises(DBAPIError) as exc:
        await _insert_exercise(session, fixture_ids, [{"type": "VOCAB", "id": str(draft)}])
    assert "origine_non_validee" in str(exc.value)


async def test_exercice_citant_un_item_inexistant_refuse(session, fixture_ids):
    with pytest.raises(DBAPIError) as exc:
        await _insert_exercise(
            session, fixture_ids, [{"type": "VOCAB", "id": str(uuid.uuid4())}]
        )
    assert "origine_introuvable" in str(exc.value)


async def test_un_seul_distracteur_non_valide_suffit_a_bloquer(
    session, fixture_ids, make_vocab, accept_decision
):
    """Une mauvaise reponse ne doit pas enseigner une forme non validee."""
    ok = await make_vocab(status="DRAFT")
    await _validate(session, ok, fixture_ids, accept_decision)
    bad = await make_vocab(status="DRAFT")

    with pytest.raises(DBAPIError) as exc:
        await _insert_exercise(
            session,
            fixture_ids,
            [{"type": "VOCAB", "id": str(ok)}, {"type": "VOCAB", "id": str(bad)}],
        )
    assert "origine_non_validee" in str(exc.value)


async def test_exercice_sur_contenu_valide_accepte(
    session, fixture_ids, make_vocab, accept_decision
):
    ids = []
    for _ in range(2):
        item = await make_vocab(status="DRAFT")
        await _validate(session, item, fixture_ids, accept_decision)
        ids.append(item)

    await _insert_exercise(session, fixture_ids, [{"type": "VOCAB", "id": str(i)} for i in ids])
