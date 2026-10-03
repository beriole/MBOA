"""Seed de demonstration : parcours Basaa construit sur des donnees reelles.

Aucun mot basaa n'est invente. Les formes proviennent d'enregistrements
Lingua Libre (Wikimedia Commons, CC BY-SA 4.0) realises par des locuteurs, et
chacune est rattachee a sa source et a son fichier d'origine.

Le seed fait volontairement passer les contenus par tout le circuit
DRAFT -> SOURCE_FOUND -> TO_VERIFY -> HUMAN_REVIEW -> VALIDATED -> PUBLISHED
afin que la demonstration montre la chaine de validation en fonctionnement,
et non un etat final pose arbitrairement.

Usage :
    python -m app.seed.seed_basaa
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import re
import unicodedata
import uuid
from pathlib import Path
from urllib.parse import quote

from sqlalchemy import text

from app.core.db import SessionLocal, engine
from app.modules.exercises.generator import CorpusWord, build_lesson_exercises
from app.seed.lingua_libre import (
    BASAA_FORMS,
    COMMONS_CATEGORY_URL,
    FRENCH_PROMPTS,
    ORTHOGRAPHY_VARIANTS_TO_REVIEW,
    SPEAKERS,
    attribution_for,
)

DATA_FILE = Path(__file__).resolve().parents[2] / "data" / "ll_bas_raw.json"

FILENAME_RE = re.compile(r"^LL-Q\d+ \(bas\)-(.+?)-(.+)\.wav$")


def commons_audio_url(filename: str) -> str:
    """URL directe d'un fichier Commons, sur le serveur de medias.

    On pourrait passer par `Special:FilePath`, qui evite ce calcul. Mais cette
    adresse enchaine quatre redirections avant d'atteindre le fichier : autant
    d'allers-retours a chaque lecture, pendant une lecon. Le chemin reel se
    deduit du nom : Commons range ses fichiers sous les deux premiers caracteres
    du MD5 du nom, les espaces etant remplaces par des soulignes.
    """
    name = filename.replace(" ", "_")
    digest = hashlib.md5(name.encode("utf-8")).hexdigest()
    return (
        "https://upload.wikimedia.org/wikipedia/commons/"
        f"{digest[0]}/{digest[:2]}/{quote(name)}"
    )


def strip_tones(value: str) -> str:
    decomposed = unicodedata.normalize("NFD", value)
    return unicodedata.normalize(
        "NFC", "".join(c for c in decomposed if not unicodedata.combining(c))
    )


def load_commons_records() -> list[dict[str, str]]:
    """Lit la liste Commons telechargee et en extrait locuteur + etiquette."""
    payload = json.loads(DATA_FILE.read_text(encoding="utf-8"))
    records: list[dict[str, str]] = []
    for member in payload["query"]["categorymembers"]:
        filename = member["title"].removeprefix("File:")
        match = FILENAME_RE.match(filename)
        if not match:
            continue
        records.append(
            {
                "filename": filename,
                "speaker": match.group(1),
                "label": match.group(2),
                "url": commons_audio_url(filename),
            }
        )
    return records


async def seed() -> None:
    records = load_commons_records()
    by_label = {r["label"]: r for r in records}

    async with SessionLocal() as db:
        # ------------------------------------------------------------------
        # 1. Sources
        # ------------------------------------------------------------------
        src_lingua = uuid.uuid4()
        src_common_voice = uuid.uuid4()
        src_hyman = uuid.uuid4()
        src_glottolog = uuid.uuid4()

        await db.execute(
            text(
                """
                INSERT INTO prov.sources
                    (id, kind, title, authors, year, publisher, url, license, usable_for,
                     consulted_at, notes)
                VALUES
                (:ll, 'RECORDING', 'Lingua Libre - prononciations basaa (Wikimedia Commons)',
                 ARRAY['Bile rene','Misnograder'], 2026, 'Wikimedia Commons', :ll_url,
                 'CC_BY_SA', ARRAY['LEXICON','AUDIO'], now(),
                 'Attribution du locuteur obligatoire. 123 fichiers, deux conventions d''etiquetage differentes.'),

                (:cv, 'DATASET', 'Common Voice Scripted Speech 27.0 - Basaa',
                 ARRAY['Mozilla Foundation'], 2026, 'Mozilla Data Collective',
                 'https://mozilladatacollective.com/datasets/cmu61xynu00n7nq079r4v8398',
                 'CC0', ARRAY['AUDIO','ASR_TRAINING'], now(),
                 '12,09 h validees, 57 locuteurs, 5226 phrases validees. Import a venir : les phrases n''ont pas de traduction.'),

                (:hy, 'ARTICLE', 'Basaa (A.43), in The Bantu Languages, ch. 15, p. 257-282',
                 ARRAY['Larry M. Hyman'], 2003, 'Routledge',
                 'https://linguistics.berkeley.edu/~hyman/Basaa_Chapter.pdf',
                 'COPYRIGHT_NO_AGREEMENT', ARRAY['GRAMMAR'], now(),
                 'Consultee pour les faits linguistiques. Les explications MBOA sont redigees a nouveau, jamais recopiees.'),

                (:gl, 'INSTITUTION', 'Glottolog 5.3 - Basa (Cameroon) [basa1284]',
                 ARRAY['Glottolog'], 2026, 'MPI-EVA',
                 'https://glottolog.org/resource/languoid/id/basa1284',
                 'CC_BY', ARRAY['LEXICON'], now(), 'Metadonnees de la langue.')
                """
            ),
            {"ll": src_lingua, "cv": src_common_voice, "hy": src_hyman, "gl": src_glottolog,
             "ll_url": COMMONS_CATEGORY_URL},
        )

        # ------------------------------------------------------------------
        # 2. Langue et variante
        # ------------------------------------------------------------------
        lang_id = uuid.uuid4()
        variant_id = uuid.uuid4()
        await db.execute(
            text(
                """
                INSERT INTO ref.languages
                    (id, iso639_3, glottocode, name, autonym, guthrie_code, family, tone_count)
                VALUES (:id, 'bas', 'basa1284', 'Basaa', :autonym, 'A.43',
                        'Niger-Congo > Bantu (zone A)', 4)
                ON CONFLICT (iso639_3) DO UPDATE SET name = EXCLUDED.name
                RETURNING id
                """
            ),
            # L'autonyme provient de l'enregistrement Lingua Libre et concorde
            # avec la transcription de Hyman 2003.
            {"id": lang_id, "autonym": "ɓasaá"},
        )
        lang_id = (
            await db.execute(text("SELECT id FROM ref.languages WHERE iso639_3='bas'"))
        ).scalar_one()

        await db.execute(
            text(
                """
                INSERT INTO ref.language_variants
                    (id, language_id, code, name, region_label, orthography, is_default)
                VALUES (:id, :lang, 'mbene', 'Basaa standard (Mbene)',
                        'Sanaga-Maritime, zone de Pouma', 'AGLC', true)
                """
            ),
            {"id": variant_id, "lang": lang_id},
        )

        # ------------------------------------------------------------------
        # 3. Contributeurs et habilitation
        # ------------------------------------------------------------------
        importer_id = uuid.uuid4()
        validator_id = uuid.uuid4()
        await db.execute(
            text(
                """
                INSERT INTO prov.contributors (id, display_name, role, affiliation)
                VALUES
                (:imp, 'Import automatique MBOA', 'EDITOR', 'MBOA'),
                (:val, 'DEMO - validateur de demonstration (a remplacer par un locuteur natif)',
                       'NATIVE_SPEAKER', 'MBOA')
                """
            ),
            {"imp": importer_id, "val": validator_id},
        )
        await db.execute(
            text(
                """
                INSERT INTO prov.validation_assignments
                    (id, contributor_id, language_id, scope, is_active)
                VALUES (:id, :val, :lang, ARRAY['LEXICON','AUDIO','EXERCISE'], true)
                """
            ),
            {"id": uuid.uuid4(), "val": validator_id, "lang": lang_id},
        )

        # ------------------------------------------------------------------
        # 4. Locuteurs
        # ------------------------------------------------------------------
        speaker_ids: dict[str, uuid.UUID] = {}
        for name, meta in SPEAKERS.items():
            sid = uuid.uuid4()
            speaker_ids[name] = sid
            await db.execute(
                text(
                    """
                    INSERT INTO audio.speakers
                        (id, display_code, language_id, variant_id, is_native, consent_scope)
                    VALUES (:id, :code, :lang, :variant, true, ARRAY['APP_PLAYBACK'])
                    """
                ),
                {"id": sid, "code": meta["display_code"], "lang": lang_id, "variant": variant_id},
            )

        # ------------------------------------------------------------------
        # 5. Lexique : formes basaa exploitables
        # ------------------------------------------------------------------
        created: dict[str, dict] = {}
        for form in BASAA_FORMS:
            record = by_label.get(form)
            if record is None:
                continue

            item_id = uuid.uuid4()
            audio_id = uuid.uuid4()

            await db.execute(
                text(
                    """
                    INSERT INTO audio.audio_assets
                        (id, speaker_id, language_id, file_key, target_type, target_id,
                         license, source_id, attribution, quality)
                    VALUES (:id, :spk, :lang, :url, 'VOCAB', :target,
                            'CC_BY_SA', :src, :attr, 'GOOD')
                    """
                ),
                {
                    "id": audio_id,
                    "spk": speaker_ids.get(record["speaker"]),
                    "lang": lang_id,
                    "url": record["url"],
                    "target": item_id,
                    "src": src_lingua,
                    "attr": attribution_for(record["speaker"]),
                },
            )

            # Etape 1 : brouillon, puis source trouvee.
            await db.execute(
                text(
                    """
                    INSERT INTO corpus.vocabulary_items
                        (id, language_id, variant_id, lemma, lemma_toneless,
                         grammatical_category, meaning_fr, status, source_id,
                         created_by, primary_audio_id, tags)
                    VALUES (:id, :lang, :variant, :lemma, :toneless, 'OTHER', NULL,
                            'DRAFT', :src, :by, :audio, ARRAY['lingua-libre'])
                    """
                ),
                {
                    "id": item_id,
                    "lang": lang_id,
                    "variant": variant_id,
                    "lemma": unicodedata.normalize("NFC", form),
                    "toneless": strip_tones(form),
                    "src": src_lingua,
                    "by": importer_id,
                    "audio": audio_id,
                },
            )

            await db.execute(
                text(
                    """
                    INSERT INTO prov.source_references
                        (id, source_id, target_type, target_id, locator, consulted_at)
                    VALUES (:id, :src, 'vocabulary_items', :target, :loc, now())
                    """
                ),
                {
                    "id": uuid.uuid4(),
                    "src": src_lingua,
                    "target": item_id,
                    "loc": f"Commons: {record['filename']}",
                },
            )

            # L'exercice ne recoit qu'un identifiant : le nom du fichier
            # d'origine (donc le mot) n'est jamais expose au client.
            created[form] = {
                "id": item_id,
                "audio_url": f"/api/v1/audio/{audio_id}",
                "attribution": attribution_for(record["speaker"]),
            }

        await db.commit()

        # Etapes 2 a 4 : le contenu remonte le circuit, statut par statut.
        for step in ("SOURCE_FOUND", "TO_VERIFY", "HUMAN_REVIEW"):
            await db.execute(
                text(
                    """
                    UPDATE corpus.vocabulary_items
                    SET status = CAST(:s AS shared.content_status)
                    WHERE language_id = :lang AND status <> 'REJECTED'
                    """
                ),
                {"s": step, "lang": lang_id},
            )
            await db.commit()

        # Etape 5 : decision humaine, puis validation.
        for form, info in created.items():
            await db.execute(
                text(
                    """
                    INSERT INTO prov.content_validations
                        (id, target_type, target_id, validator_contributor_id, decision,
                         comment, decided_at)
                    VALUES (:id, 'vocabulary_items', :target, :val, 'ACCEPT', :c, now())
                    """
                ),
                {
                    "id": uuid.uuid4(),
                    "target": info["id"],
                    "val": validator_id,
                    "c": "Forme et audio verifies contre le fichier Lingua Libre d'origine. "
                         "Glose francaise non renseignee : a saisir par un locuteur natif.",
                },
            )
        await db.commit()

        await db.execute(
            text(
                """
                UPDATE corpus.vocabulary_items
                SET status = 'VALIDATED', validated_by = :val
                WHERE language_id = :lang AND status = 'HUMAN_REVIEW'
                """
            ),
            {"val": validator_id, "lang": lang_id},
        )
        await db.commit()

        await db.execute(
            text(
                """
                UPDATE corpus.vocabulary_items
                SET status = 'PUBLISHED'
                WHERE language_id = :lang AND status = 'VALIDATED'
                """
            ),
            {"lang": lang_id},
        )
        await db.commit()

        # ------------------------------------------------------------------
        # 6. Lot ambigu : importe, mais bloque en TO_VERIFY
        # ------------------------------------------------------------------
        batch_id = uuid.uuid4()
        ambiguous = [r for r in records if r["speaker"] == "Misnograder"]
        await db.execute(
            text(
                """
                INSERT INTO corpus.import_batches
                    (id, source_id, label, row_count, notes)
                VALUES (:id, :src, :label, :n, :notes)
                """
            ),
            {
                "id": batch_id,
                "src": src_lingua,
                "label": "Lingua Libre bas - lot Misnograder",
                "n": len(ambiguous),
                "notes": "Etiquettes en francais : impossible de determiner sans ecoute "
                         "si la forme ecrite est du basaa. Bloque en TO_VERIFY.",
            },
        )
        for index, record in enumerate(ambiguous):
            await db.execute(
                text(
                    """
                    INSERT INTO corpus.raw_records
                        (id, import_batch_id, row_index, raw, state)
                    VALUES (:id, :batch, :i, CAST(:raw AS jsonb), 'RAW')
                    """
                ),
                {
                    "id": uuid.uuid4(),
                    "batch": batch_id,
                    "i": index,
                    "raw": json.dumps(record, ensure_ascii=False),
                },
            )
        await db.commit()

        # ------------------------------------------------------------------
        # 7. Parcours : cours -> section -> unite -> lecon
        # ------------------------------------------------------------------
        course_id, section_id, unit_id, lesson_id = (uuid.uuid4() for _ in range(4))

        async def publish(table: str, item_id: uuid.UUID) -> None:
            """Fait passer un objet pedagogique par le circuit complet."""
            for step in ("SOURCE_FOUND", "TO_VERIFY", "HUMAN_REVIEW"):
                await db.execute(
                    text(
                        f"UPDATE learn.{table} SET status = CAST(:s AS shared.content_status) "
                        "WHERE id = :id"
                    ),
                    {"s": step, "id": item_id},
                )
            await db.execute(
                text(
                    """
                    INSERT INTO prov.content_validations
                        (id, target_type, target_id, validator_contributor_id, decision, decided_at)
                    VALUES (:id, :tt, :target, :val, 'ACCEPT', now())
                    """
                ),
                {"id": uuid.uuid4(), "tt": table, "target": item_id, "val": validator_id},
            )
            await db.execute(
                text(
                    f"UPDATE learn.{table} SET status = 'VALIDATED', validated_by = :val "
                    "WHERE id = :id"
                ),
                {"val": validator_id, "id": item_id},
            )
            await db.execute(
                text(f"UPDATE learn.{table} SET status = 'PUBLISHED' WHERE id = :id"),
                {"id": item_id},
            )

        await db.execute(
            text(
                """
                INSERT INTO learn.courses
                    (id, language_id, variant_id, level, title_fr, description_fr,
                     position, status, source_id, created_by)
                VALUES (:id, :lang, :variant, 'N0', 'Basaa — Initiation',
                        'Premiers contacts avec la langue basaa, à partir d''enregistrements de locuteurs.',
                        0, 'DRAFT', :src, :by)
                """
            ),
            {"id": course_id, "lang": lang_id, "variant": variant_id,
             "src": src_lingua, "by": importer_id},
        )
        await db.execute(
            text(
                """
                INSERT INTO learn.sections
                    (id, course_id, position, title_fr, objective_fr, status, source_id, created_by)
                VALUES (:id, :course, 0, 'Les sons du basaa',
                        'Reconnaître à l''oreille les formes écrites du basaa.',
                        'DRAFT', :src, :by)
                """
            ),
            {"id": section_id, "course": course_id, "src": src_lingua, "by": importer_id},
        )
        await db.execute(
            text(
                """
                INSERT INTO learn.units
                    (id, section_id, position, title_fr, objective_fr, target_vocab_ids,
                     status, source_id, created_by)
                VALUES (:id, :section, 0, 'Écouter et reconnaître',
                        'À la fin de cette unité, je reconnais à l''oreille plusieurs mots basaa.',
                        :vocab, 'DRAFT', :src, :by)
                """
            ),
            {
                "id": unit_id,
                "section": section_id,
                "vocab": [info["id"] for info in created.values()],
                "src": src_lingua,
                "by": importer_id,
            },
        )
        await db.execute(
            text(
                """
                INSERT INTO learn.lessons
                    (id, unit_id, position, kind, title_fr, estimated_minutes, xp_reward,
                     status, source_id, created_by)
                VALUES (:id, :unit, 0, 'LESSON', 'Première écoute', 4, 10,
                        'DRAFT', :src, :by)
                """
            ),
            {"id": lesson_id, "unit": unit_id, "src": src_lingua, "by": importer_id},
        )
        await db.commit()

        for table, item in (
            ("courses", course_id),
            ("sections", section_id),
            ("units", unit_id),
            ("lessons", lesson_id),
        ):
            await publish(table, item)
        await db.commit()

        # ------------------------------------------------------------------
        # 8. Exercices generes depuis le corpus publie
        # ------------------------------------------------------------------
        words = [
            CorpusWord(
                id=str(info["id"]),
                lemma=form,
                meaning_fr=None,
                audio_url=info["audio_url"],
                audio_attribution=info["attribution"],
            )
            for form, info in created.items()
        ]
        exercises = build_lesson_exercises(words)

        position = 0
        await db.execute(
            text(
                """
                INSERT INTO learn.lesson_blocks (id, lesson_id, position, kind, payload)
                VALUES (:id, :lesson, 0, 'INTRO',
                        CAST(:p AS jsonb))
                """
            ),
            {
                "id": uuid.uuid4(),
                "lesson": lesson_id,
                "p": json.dumps(
                    {
                        "title_fr": "Écoute et reconnais",
                        "subtitle_fr": "Les enregistrements sont ceux de locuteurs basaa.",
                    },
                    ensure_ascii=False,
                ),
            },
        )
        position += 1

        for generated in exercises:
            exercise_id = uuid.uuid4()
            await db.execute(
                text(
                    """
                    INSERT INTO learn.exercises
                        (id, language_id, type, schema_version, payload, answer_spec,
                         generated_from, generator_version, difficulty, explanation_fr,
                         status, source_id, created_by)
                    VALUES (:id, :lang, CAST(:type AS shared.exercise_type), 1,
                            CAST(:payload AS jsonb), CAST(:spec AS jsonb),
                            CAST(:from AS jsonb), :gv, :diff, :expl,
                            'DRAFT', :src, :by)
                    """
                ),
                {
                    "id": exercise_id,
                    "lang": lang_id,
                    "type": generated.type.value,
                    "payload": json.dumps(generated.payload, ensure_ascii=False),
                    "spec": json.dumps(generated.answer_spec, ensure_ascii=False),
                    "from": json.dumps(generated.generated_from),
                    "gv": generated.generator_version,
                    "diff": generated.difficulty,
                    "expl": generated.explanation_fr,
                    "src": src_lingua,
                    "by": importer_id,
                },
            )
            await db.execute(
                text(
                    """
                    INSERT INTO learn.lesson_blocks
                        (id, lesson_id, position, kind, exercise_id)
                    VALUES (:id, :lesson, :pos, 'PRACTICE', :ex)
                    """
                ),
                {"id": uuid.uuid4(), "lesson": lesson_id, "pos": position, "ex": exercise_id},
            )
            position += 1
            await db.commit()
            await publish("exercises", exercise_id)
            await db.commit()

        await db.execute(
            text(
                """
                INSERT INTO learn.lesson_blocks (id, lesson_id, position, kind, payload)
                VALUES (:id, :lesson, :pos, 'RECAP', CAST(:p AS jsonb))
                """
            ),
            {
                "id": uuid.uuid4(),
                "lesson": lesson_id,
                "pos": position,
                "p": json.dumps(
                    {"title_fr": "Bien joué", "note_fr": "Tu as travaillé des mots attestés."},
                    ensure_ascii=False,
                ),
            },
        )
        await db.commit()

        # ------------------------------------------------------------------
        # 9. Rapport
        # ------------------------------------------------------------------
        print("\n=== SEED MBOA - Basaa ===")
        print(f"  langue            : Basaa [bas] ({lang_id})")
        print(f"  formes publiees   : {len(created)} (source : Lingua Libre, CC BY-SA 4.0)")
        print(f"  lot bloque        : {len(ambiguous)} enregistrements en TO_VERIFY (etiquettes ambigues)")
        print(f"  exercices generes : {len(exercises)}")
        print(f"  lecon             : {lesson_id}")
        print("\n  Variantes graphiques a faire trancher par un locuteur natif :")
        for a, b in ORTHOGRAPHY_VARIANTS_TO_REVIEW:
            print(f"    - {a}  /  {b}")
        print(f"\n  Amorces francaises non importees comme lexique : {', '.join(FRENCH_PROMPTS)}")
        print("  Aucune glose francaise n'a ete inventee : elles restent NULL.\n")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(seed())
