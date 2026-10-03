"""Initialisation complete du schema local.

Sequence : schemas -> types ENUM -> tables -> triggers de provenance.

Usage :
    python -m app.db.init_db            # cree ce qui manque
    python -m app.db.init_db --reset    # supprime puis recree tout (local uniquement)
"""

import argparse
import asyncio
from pathlib import Path

from sqlalchemy import text

from app.core.config import settings
from app.core.db import Base, engine
from app.db import models as _models  # noqa: F401  (enregistre les tables)
from app.db.bootstrap import bootstrap_schemas_and_types
from app.db.models import SCHEMAS

TRIGGERS_SQL = Path(__file__).parent / "triggers.sql"

#: Tables soumises au circuit de provenance (heritant de ProvenanceMixin).
PROVENANCE_TABLES = (
    ("corpus", "vocabulary_items"),
    ("corpus", "example_sentences"),
    ("corpus", "grammar_rules"),
    ("learn", "courses"),
    ("learn", "sections"),
    ("learn", "units"),
    ("learn", "lessons"),
    ("learn", "exercises"),
    ("culture", "cultural_contents"),
)


async def _run_script(connection, sql: str) -> None:
    """Execute un script multi-instructions.

    asyncpg passe par des prepared statements, qui n'acceptent qu'une instruction
    a la fois : on descend donc jusqu'a la connexion driver pour ce cas precis.
    """
    raw = await connection.get_raw_connection()
    await raw.driver_connection.execute(sql)


async def _attach_triggers(connection) -> None:
    await _run_script(connection, TRIGGERS_SQL.read_text(encoding="utf-8"))

    for schema, table in PROVENANCE_TABLES:
        await connection.execute(
            text(f"DROP TRIGGER IF EXISTS trg_status_guard ON {schema}.{table}")
        )
        await connection.execute(
            text(
                f"""
                CREATE TRIGGER trg_status_guard
                BEFORE INSERT OR UPDATE ON {schema}.{table}
                FOR EACH ROW EXECUTE FUNCTION prov.enforce_content_status()
                """
            )
        )
        await connection.execute(
            text(f"DROP TRIGGER IF EXISTS trg_status_log ON {schema}.{table}")
        )
        await connection.execute(
            text(
                f"""
                CREATE TRIGGER trg_status_log
                AFTER INSERT OR UPDATE ON {schema}.{table}
                FOR EACH ROW EXECUTE FUNCTION prov.log_status_transition()
                """
            )
        )

    # Une attestation ne s'emet pas sans le parcours qu'elle affirme (SS15).
    # A l'INSERT seulement : une attestation delivree est figee, et le cours
    # peut gagner des lecons apres coup sans rendre les anciennes incoherentes.
    await connection.execute(
        text("DROP TRIGGER IF EXISTS trg_certificate_completion ON progress.certificates")
    )
    await connection.execute(
        text(
            """
            CREATE TRIGGER trg_certificate_completion
            BEFORE INSERT ON progress.certificates
            FOR EACH ROW EXECUTE FUNCTION progress.enforce_certificate_completion()
            """
        )
    )

    # Place de marche : l'argent ne circule pas, et un objet ne se reclame pas
    # d'une fiche culturelle qui n'est pas publiee (SS45, SS3).
    for table, function in (
        ("orders", "market.enforce_no_payment"),
        ("products", "market.enforce_cultural_claim"),
    ):
        trigger = f"trg_{table}_guard"
        await connection.execute(
            text(f"DROP TRIGGER IF EXISTS {trigger} ON market.{table}")
        )
        await connection.execute(
            text(
                f"""
                CREATE TRIGGER {trigger}
                BEFORE INSERT OR UPDATE ON market.{table}
                FOR EACH ROW EXECUTE FUNCTION {function}()
                """
            )
        )

    # Controle specifique des origines d'exercice (SS13).
    await connection.execute(
        text("DROP TRIGGER IF EXISTS trg_exercise_sources ON learn.exercises")
    )
    await connection.execute(
        text(
            """
            CREATE TRIGGER trg_exercise_sources
            BEFORE INSERT OR UPDATE ON learn.exercises
            FOR EACH ROW EXECUTE FUNCTION learn.enforce_exercise_sources()
            """
        )
    )

    # Normalisation Unicode NFC des formes ecrites (indispensable aux tons).
    await connection.execute(
        text(
            """
            ALTER TABLE corpus.vocabulary_items
            DROP CONSTRAINT IF EXISTS ck_vocabulary_items_lemma_nfc
            """
        )
    )
    await connection.execute(
        text(
            """
            ALTER TABLE corpus.vocabulary_items
            ADD CONSTRAINT ck_vocabulary_items_lemma_nfc
            CHECK (lemma = normalize(lemma, NFC))
            """
        )
    )
    await connection.execute(
        text(
            """
            ALTER TABLE corpus.example_sentences
            DROP CONSTRAINT IF EXISTS ck_example_sentences_text_nfc
            """
        )
    )
    await connection.execute(
        text(
            """
            ALTER TABLE corpus.example_sentences
            ADD CONSTRAINT ck_example_sentences_text_nfc
            CHECK (text = normalize(text, NFC))
            """
        )
    )


async def init_db(reset: bool = False) -> None:
    async with engine.begin() as connection:
        if reset:
            for schema in reversed(SCHEMAS):
                await connection.execute(text(f'DROP SCHEMA IF EXISTS "{schema}" CASCADE'))

        await bootstrap_schemas_and_types(connection)
        await connection.run_sync(Base.metadata.create_all)
        await _attach_triggers(connection)

    await engine.dispose()


def main() -> None:
    parser = argparse.ArgumentParser(description="Initialise la base MBOA locale.")
    parser.add_argument("--reset", action="store_true", help="supprime puis recree tout le schema")
    args = parser.parse_args()

    print(f"[MBOA] base cible : {settings.db_name} sur {settings.db_host}:{settings.db_port}")
    asyncio.run(init_db(reset=args.reset))
    print("[MBOA] schema initialise (schemas, types, tables, triggers).")


if __name__ == "__main__":
    main()
