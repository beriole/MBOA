"""Fixtures de test.

Les tests tournent sur la base `mboa_test`, distincte de `mboa_dev`. Le schema
est recree une seule fois par session ; chaque test obtient ensuite son propre
engine et sa propre boucle asyncio, ce qui evite tout partage de connexion
entre boucles.
"""

import asyncio
import os
import uuid

import pytest
import pytest_asyncio

# Doit etre positionne avant l'import de la configuration.
os.environ["DB_NAME"] = "mboa_test"

from sqlalchemy import text  # noqa: E402
from sqlalchemy.ext.asyncio import (  # noqa: E402
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import Settings  # noqa: E402

TEST_SETTINGS = Settings(db_name="mboa_test")


@pytest.fixture(scope="session", autouse=True)
def schema() -> None:
    """Recree le schema de test une fois pour toute la session."""
    import app.core.db as core_db
    import app.db.init_db as init_module

    test_engine = create_async_engine(TEST_SETTINGS.database_url, echo=False)
    original = core_db.engine
    core_db.engine = test_engine
    init_module.engine = test_engine
    try:
        asyncio.run(init_module.init_db(reset=True))
    finally:
        core_db.engine = original


@pytest_asyncio.fixture
async def session() -> AsyncSession:
    """Une session par test, sur un engine dedie a la boucle du test."""
    engine = create_async_engine(TEST_SETTINGS.database_url, echo=False, poolclass=None)
    maker = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with maker() as s:
        try:
            yield s
        finally:
            await s.rollback()
    await engine.dispose()


@pytest_asyncio.fixture
async def fixture_ids(session: AsyncSession) -> dict[str, uuid.UUID]:
    """Jeu minimal : une langue, une source CC0, deux contributeurs, une habilitation.

    Aucun contenu linguistique n'est cree ici : uniquement la structure.
    """
    ids = {
        "source": uuid.uuid4(),
        "author": uuid.uuid4(),
        "validator": uuid.uuid4(),
    }

    # 'zxx' = code ISO 639-3 reserve a "pas de contenu linguistique" : il ne peut
    # entrer en collision avec aucune vraie langue du referentiel.
    await session.execute(
        text(
            """
            INSERT INTO ref.languages (id, iso639_3, name, guthrie_code, tone_count)
            VALUES (:id, 'zxx', 'Langue de test', 'A.00', 4)
            ON CONFLICT (iso639_3) DO NOTHING
            """
        ),
        {"id": uuid.uuid4()},
    )
    ids["language"] = (
        await session.execute(
            text("SELECT id FROM ref.languages WHERE iso639_3 = 'zxx'")
        )
    ).scalar_one()
    await session.execute(
        text(
            """
            INSERT INTO prov.sources (id, kind, title, authors, year, license, url, usable_for)
            VALUES (:id, 'DATASET', 'Common Voice 27.0 - Basaa', ARRAY['Mozilla Foundation'],
                    2026, 'CC0',
                    'https://mozilladatacollective.com/datasets/cmu61xynu00n7nq079r4v8398',
                    ARRAY['LEXICON','AUDIO','ASR_TRAINING'])
            """
        ),
        {"id": ids["source"]},
    )
    await session.execute(
        text(
            """
            INSERT INTO prov.contributors (id, display_name, role)
            VALUES (:a, 'Redacteur test', 'EDITOR'),
                   (:v, 'Validateur natif test', 'NATIVE_SPEAKER')
            """
        ),
        {"a": ids["author"], "v": ids["validator"]},
    )
    await session.execute(
        text(
            """
            INSERT INTO prov.validation_assignments
                (id, contributor_id, language_id, scope, is_active)
            VALUES (:id, :v, :lang, ARRAY['LEXICON','GRAMMAR'], true)
            """
        ),
        {"id": uuid.uuid4(), "v": ids["validator"], "lang": ids["language"]},
    )
    await session.commit()
    return ids


@pytest_asyncio.fixture
async def make_vocab(session: AsyncSession, fixture_ids):
    """Cree une entree lexicale au statut voulu, sans jamais inventer de forme.

    La forme utilisee est un identifiant technique neutre, pas un mot basaa :
    ces tests verifient la mecanique de validation, pas le contenu linguistique.
    """
    counter = {"n": 0}

    async def _make(status: str = "DRAFT", with_source: bool = True, **overrides):
        counter["n"] += 1
        item_id = uuid.uuid4()
        await session.execute(
            text(
                """
                INSERT INTO corpus.vocabulary_items
                    (id, language_id, lemma, lemma_toneless, grammatical_category,
                     meaning_fr, status, source_id, created_by, validated_by)
                VALUES
                    (:id, :lang, :lemma, :lemma, 'NOUN', :meaning,
                     CAST(:status AS shared.content_status), :source, :created_by, :validated_by)
                """
            ),
            {
                "id": item_id,
                "lang": fixture_ids["language"],
                "lemma": f"lemme-test-{counter['n']}-{item_id.hex[:6]}",
                "meaning": f"sens de test {counter['n']}",
                "status": status,
                "source": fixture_ids["source"] if with_source else None,
                "created_by": overrides.get("created_by", fixture_ids["author"]),
                "validated_by": overrides.get("validated_by"),
            },
        )
        await session.commit()
        return item_id

    return _make


@pytest_asyncio.fixture
async def accept_decision(session: AsyncSession, fixture_ids):
    """Enregistre une decision ACCEPT d'un validateur sur une cible."""

    async def _accept(target_type: str, target_id: uuid.UUID, validator: uuid.UUID | None = None):
        await session.execute(
            text(
                """
                INSERT INTO prov.content_validations
                    (id, target_type, target_id, validator_contributor_id, decision, decided_at)
                VALUES (:id, :tt, :ti, :v, 'ACCEPT', now())
                """
            ),
            {
                "id": uuid.uuid4(),
                "tt": target_type,
                "ti": target_id,
                "v": validator or fixture_ids["validator"],
            },
        )
        await session.commit()

    return _accept
