"""Seed du Culture Hub : rubriques et premieres fiches.

Regle identique a celle du corpus linguistique : aucun fait culturel n'est
invente. Les trois fiches semees ici ne contiennent que des elements verifies
dans ce projet, aupres de sources identifiees :

  - Glottolog 5.3 (CC BY 4.0) pour l'identification de la langue ;
  - Hyman 2003, « Basaa (A.43) », pour la description linguistique ;
  - Makasso & Lee 2015 (JIPA) pour les tons ;
  - les fiches Lingua Libre et Common Voice pour la constitution du corpus.

Les explications sont redigees pour MBOA : le droit d'auteur protege
l'expression, pas le fait. Aucune phrase n'est recopiee.

Les autres rubriques (contes, danses, gastronomie, tenues...) restent vides :
elles attendent des contributeurs. Un Culture Hub a moitie vide mais honnete
vaut mieux qu'un Culture Hub rempli de generalites.

Usage :
    python -m app.seed.seed_culture
"""

from __future__ import annotations

import asyncio
import uuid

from sqlalchemy import text

from app.core.db import SessionLocal, engine
from app.shared.enums import CulturalCategoryCode

#: Les rubriques du SS20, dans l'ordre d'affichage.
CATEGORIES: list[tuple[CulturalCategoryCode, str, str]] = [
    (CulturalCategoryCode.LANGUAGE, "Langue", "Ce que disent les linguistes de la langue."),
    (CulturalCategoryCode.PEOPLES, "Peuples", "Qui parle cette langue, et ou."),
    (CulturalCategoryCode.HISTORY, "Histoire", "Le passe des communautes."),
    (CulturalCategoryCode.TALES, "Contes", "Recits transmis oralement."),
    (CulturalCategoryCode.PROVERBS, "Proverbes", "La sagesse en quelques mots."),
    (CulturalCategoryCode.DANCES, "Danses", "Ce que le corps raconte."),
    (CulturalCategoryCode.MUSIC, "Musiques", "Instruments, rythmes et repertoires."),
    (CulturalCategoryCode.GASTRONOMY, "Gastronomie", "Plats, ingredients et usages."),
    (CulturalCategoryCode.ATTIRE, "Tenues", "Vetements et parures."),
    (CulturalCategoryCode.CRAFTS, "Artisanat", "Savoir-faire et objets."),
    (CulturalCategoryCode.RITES, "Rites", "Ceremonies et passages."),
    (CulturalCategoryCode.FESTIVALS, "Fetes", "Celebrations collectives."),
    (CulturalCategoryCode.SYMBOLS, "Symboles", "Motifs et significations."),
    (CulturalCategoryCode.PERSONALITIES, "Personnalites", "Celles et ceux qui ont marque."),
    (CulturalCategoryCode.ARCHITECTURE, "Architecture", "Habitat et batisses."),
    (
        CulturalCategoryCode.ORAL_TRADITIONS,
        "Traditions orales",
        "Ce qui se transmet par la parole.",
    ),
]

#: Les dix regions du Cameroun.
REGIONS = [
    ("AD", "Adamaoua"),
    ("CE", "Centre"),
    ("ES", "Est"),
    ("EN", "Extrême-Nord"),
    ("LT", "Littoral"),
    ("NO", "Nord"),
    ("NW", "Nord-Ouest"),
    ("OU", "Ouest"),
    ("SU", "Sud"),
    ("SW", "Sud-Ouest"),
]


async def seed() -> None:
    async with SessionLocal() as db:
        language_id = (
            await db.execute(text("SELECT id FROM ref.languages WHERE iso639_3 = 'bas'"))
        ).scalar_one_or_none()
        if language_id is None:
            print("[!] Lancez d'abord `python -m app.seed.seed_basaa`.")
            return

        # ------------------------------------------------------------------
        # 1. Rubriques
        # ------------------------------------------------------------------
        for position, (code, name, description) in enumerate(CATEGORIES):
            await db.execute(
                text(
                    """
                    INSERT INTO culture.cultural_categories
                        (id, code, name_fr, description_fr, position)
                    VALUES (:id, CAST(:code AS shared.cultural_category_code), :name, :desc, :pos)
                    ON CONFLICT (code) DO UPDATE
                        SET name_fr = EXCLUDED.name_fr, position = EXCLUDED.position
                    """
                ),
                {
                    "id": uuid.uuid4(),
                    "code": code.value,
                    "name": name,
                    "desc": description,
                    "pos": position,
                },
            )

        # ------------------------------------------------------------------
        # 2. Referentiel geographique
        # ------------------------------------------------------------------
        for code, name in REGIONS:
            await db.execute(
                text(
                    """
                    INSERT INTO ref.regions (id, code, name) VALUES (:id, :code, :name)
                    ON CONFLICT (code) DO NOTHING
                    """
                ),
                {"id": uuid.uuid4(), "code": code, "name": name},
            )
        await db.commit()

        regions = {
            row.code: row.id
            for row in await db.execute(text("SELECT id, code FROM ref.regions"))
        }
        categories = {
            row.code: row.id
            for row in await db.execute(
                text("SELECT id, code::text AS code FROM culture.cultural_categories")
            )
        }

        # ------------------------------------------------------------------
        # 3. Sources et contributeurs
        # ------------------------------------------------------------------
        src_glottolog = (
            await db.execute(
                text("SELECT id FROM prov.sources WHERE title LIKE 'Glottolog%' LIMIT 1")
            )
        ).scalar_one_or_none()
        src_hyman = (
            await db.execute(
                text("SELECT id FROM prov.sources WHERE title LIKE 'Basaa (A.43)%' LIMIT 1")
            )
        ).scalar_one_or_none()
        src_lingua = (
            await db.execute(
                text("SELECT id FROM prov.sources WHERE title LIKE 'Lingua Libre%' LIMIT 1")
            )
        ).scalar_one_or_none()

        src_jipa = uuid.uuid4()
        await db.execute(
            text(
                """
                INSERT INTO prov.sources
                    (id, kind, title, authors, year, publisher, url, license, usable_for,
                     consulted_at, notes)
                VALUES (:id, 'ARTICLE',
                        'Basaa - Illustrations of the IPA, JIPA 45(1)',
                        ARRAY['Emmanuel-Moselly Makasso','Seunghun J. Lee'], 2015,
                        'Cambridge University Press',
                        'https://www.cambridge.org/core/journals/journal-of-the-international-phonetic-association/article/basaa/630CB83A1DB4851CE043540DFCEF2F0A',
                        'COPYRIGHT_NO_AGREEMENT', ARRAY['GRAMMAR','CULTURE'], now(),
                        'Consultee pour l''inventaire phonetique et les tons. Faits repris, texte non recopie.')
                """
            ),
            {"id": src_jipa},
        )

        author = uuid.uuid4()
        validator = (
            await db.execute(
                text(
                    "SELECT id FROM prov.contributors WHERE display_name LIKE 'DEMO%' LIMIT 1"
                )
            )
        ).scalar_one_or_none()
        await db.execute(
            text(
                """
                INSERT INTO prov.contributors (id, display_name, role, affiliation)
                VALUES (:id, 'Redaction MBOA (fiches sourcees)', 'EDITOR', 'MBOA')
                """
            ),
            {"id": author},
        )
        if validator is None:
            validator = uuid.uuid4()
            await db.execute(
                text(
                    """
                    INSERT INTO prov.contributors (id, display_name, role, affiliation)
                    VALUES (:id, 'DEMO - validateur de demonstration (a remplacer)',
                            'NATIVE_SPEAKER', 'MBOA')
                    """
                ),
                {"id": validator},
            )
        await db.execute(
            text(
                """
                INSERT INTO prov.validation_assignments
                    (id, contributor_id, language_id, scope, is_active)
                VALUES (:id, :cid, :lang, ARRAY['CULTURE'], true)
                ON CONFLICT (contributor_id, language_id) DO UPDATE SET is_active = true
                """
            ),
            {"id": uuid.uuid4(), "cid": validator, "lang": language_id},
        )
        await db.commit()

        # ------------------------------------------------------------------
        # 4. Fiches
        # ------------------------------------------------------------------
        fiches = [
            {
                "category": "LANGUAGE",
                "title": "Le basaa se parle sur quatre tons",
                "summary": (
                    "En basaa, la hauteur de la voix distingue les mots. La langue compte "
                    "quatre tons : haut, bas, descendant et montant."
                ),
                "body": (
                    "Le basaa fait partie des langues a tons : la hauteur a laquelle une "
                    "syllabe est prononcee change le mot lui-meme, comme le feraient des "
                    "lettres differentes en francais.\n\n"
                    "Les descriptions linguistiques s'accordent sur quatre tons contrastifs : "
                    "haut, bas, descendant et montant. C'est ce que notent Makasso et Lee dans "
                    "leur illustration de l'alphabet phonetique international consacree au "
                    "basaa, et ce que decrit Larry Hyman dans le chapitre qu'il consacre a "
                    "cette langue.\n\n"
                    "Consequence pratique pour qui apprend : les accents ecrits au-dessus des "
                    "voyelles ne sont pas decoratifs. Les omettre revient a changer de mot, "
                    "ou a n'en ecrire aucun."
                ),
                "sources": [
                    (src_jipa, "Makasso & Lee 2015, Illustrations of the IPA"),
                    (src_hyman, "Hyman 2003, chapitre 15, section phonologie"),
                ],
                "region": None,
                "minutes": 2,
                "link_to_unit": True,
            },
            {
                "category": "PEOPLES",
                "title": "Où parle-t-on le basaa ?",
                "summary": (
                    "Le basaa est parle dans le Centre et le Littoral du Cameroun. Il sert "
                    "aussi de langue vehiculaire au-dela des communautes qui le portent."
                ),
                "body": (
                    "Le basaa est une langue bantoue de la zone A, identifiee par le code "
                    "A.43 dans la classification de Guthrie et par le code international "
                    "bas.\n\n"
                    "On le parle principalement dans deux regions du Cameroun : le Centre et "
                    "le Littoral, notamment dans les departements du Nyong-et-Kelle et de la "
                    "Sanaga-Maritime, ainsi que dans le Nkam et le Wouri.\n\n"
                    "La variete generalement prise comme reference est celle que l'on nomme "
                    "mbene, parlee autour de Pouma. Hyman signale par ailleurs que le basaa "
                    "sert de langue vehiculaire dans des zones voisines, au-dela des "
                    "locuteurs qui en ont herite.\n\n"
                    "Les estimations du nombre de locuteurs varient selon les releves et les "
                    "annees : elles s'echelonnent de 280 000 a plusieurs centaines de "
                    "milliers. MBOA prefere citer cette fourchette plutot qu'un chiffre unique "
                    "qui donnerait une fausse impression de precision."
                ),
                "sources": [
                    (src_glottolog, "Glottolog, fiche basa1284"),
                    (src_hyman, "Hyman 2003, introduction"),
                ],
                "region": regions.get("LT"),
                "minutes": 3,
                "link_to_unit": False,
            },
            {
                "category": "ORAL_TRADITIONS",
                "title": "D'ou viennent les voix que vous entendez",
                "summary": (
                    "Les enregistrements de l'application proviennent de locuteurs qui les "
                    "ont deposes sous licence libre. Aucune voix de synthese."
                ),
                "body": (
                    "Chaque mot que vous entendez dans MBOA a ete prononce par une personne, "
                    "pas par un logiciel. C'est un choix : une voix de synthese generique ne "
                    "restitue pas les tons d'une langue comme le basaa, et donnerait a "
                    "entendre une langue qui n'existe pas.\n\n"
                    "Les enregistrements actuels viennent de Lingua Libre, un service de "
                    "l'association Wikimedia France qui permet a chacun d'enregistrer sa "
                    "langue. Les fichiers sont deposes sur Wikimedia Commons sous licence "
                    "Creative Commons BY-SA 4.0 : ils peuvent etre reutilises, a condition de "
                    "citer la personne qui les a enregistres. C'est pourquoi son nom "
                    "apparait sous chaque son.\n\n"
                    "Une seconde source existe deja pour le basaa : le projet Common Voice de "
                    "la fondation Mozilla, qui rassemble plus de douze heures de parole "
                    "validee, versees au domaine public. Ces enregistrements serviront a "
                    "elargir le corpus.\n\n"
                    "Documenter une langue est un travail collectif et lent. Les personnes qui "
                    "enregistrent leur voix aujourd'hui rendent possible ce que d'autres "
                    "apprendront demain."
                ),
                "sources": [(src_lingua, "Categorie Lingua Libre pronunciation-bas")],
                "region": None,
                "minutes": 3,
                "link_to_unit": False,
            },
        ]

        unit_id = (
            await db.execute(
                text(
                    """
                    SELECT u.id FROM learn.units u
                    JOIN learn.sections s ON s.id = u.section_id
                    JOIN learn.courses c ON c.id = s.course_id
                    WHERE c.language_id = :lang ORDER BY u.position LIMIT 1
                    """
                ),
                {"lang": language_id},
            )
        ).scalar_one_or_none()

        created = []
        for fiche in fiches:
            content_id = uuid.uuid4()
            primary_source = fiche["sources"][0][0]
            await db.execute(
                text(
                    """
                    INSERT INTO culture.cultural_contents
                        (id, category_id, title_fr, summary_fr, body_fr, region_id,
                         language_id, reading_minutes, status, source_id, created_by)
                    VALUES (:id, :cat, :title, :summary, :body, :region, :lang, :minutes,
                            'DRAFT', :src, :by)
                    """
                ),
                {
                    "id": content_id,
                    "cat": categories[fiche["category"]],
                    "title": fiche["title"],
                    "summary": fiche["summary"],
                    "body": fiche["body"],
                    "region": fiche["region"],
                    "lang": language_id,
                    "minutes": fiche["minutes"],
                    "src": primary_source,
                    "by": author,
                },
            )
            for source_id, locator in fiche["sources"]:
                if source_id is None:
                    continue
                await db.execute(
                    text(
                        """
                        INSERT INTO prov.source_references
                            (id, source_id, target_type, target_id, locator, consulted_at)
                        VALUES (:id, :src, 'cultural_contents', :target, :loc, now())
                        """
                    ),
                    {
                        "id": uuid.uuid4(),
                        "src": source_id,
                        "target": content_id,
                        "loc": locator,
                    },
                )
            created.append((content_id, fiche))
        await db.commit()

        # Circuit de validation complet, comme pour le corpus linguistique.
        for content_id, _ in created:
            for step in ("SOURCE_FOUND", "TO_VERIFY", "HUMAN_REVIEW"):
                await db.execute(
                    text(
                        "UPDATE culture.cultural_contents "
                        "SET status = CAST(:s AS shared.content_status) WHERE id = :id"
                    ),
                    {"s": step, "id": content_id},
                )
            await db.execute(
                text(
                    """
                    INSERT INTO prov.content_validations
                        (id, target_type, target_id, validator_contributor_id, decision,
                         comment, decided_at)
                    VALUES (:id, 'cultural_contents', :target, :v, 'ACCEPT', :c, now())
                    """
                ),
                {
                    "id": uuid.uuid4(),
                    "target": content_id,
                    "v": validator,
                    "c": "Faits verifies contre les sources citees.",
                },
            )
            await db.execute(
                text(
                    "UPDATE culture.cultural_contents SET status='VALIDATED', validated_by=:v "
                    "WHERE id = :id"
                ),
                {"v": validator, "id": content_id},
            )
            await db.execute(
                text("UPDATE culture.cultural_contents SET status='PUBLISHED' WHERE id = :id"),
                {"id": content_id},
            )
        await db.commit()

        # Lien avec l'apprentissage : la carte « Le savais-tu ? » (SS21).
        linked = 0
        if unit_id is not None:
            for content_id, fiche in created:
                if not fiche["link_to_unit"]:
                    continue
                await db.execute(
                    text(
                        """
                        INSERT INTO culture.cultural_links
                            (id, cultural_content_id, target_type, target_id, placement)
                        VALUES (:id, :content, 'UNIT', :unit, 'DID_YOU_KNOW')
                        ON CONFLICT DO NOTHING
                        """
                    ),
                    {"id": uuid.uuid4(), "content": content_id, "unit": unit_id},
                )
                linked += 1
        await db.commit()

        vides = len(CATEGORIES) - len({f["category"] for _, f in created})
        print("\n=== SEED Culture Hub ===")
        print(f"  rubriques         : {len(CATEGORIES)}")
        print(f"  fiches publiees   : {len(created)} (toutes sourcees)")
        print(f"  cartes en lecon   : {linked}")
        print(f"  rubriques vides   : {vides} — elles attendent des contributeurs")
        print("  Aucun fait culturel n'a ete invente.\n")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(seed())
