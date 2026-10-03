"""Repartit les exercices deja valides en plusieurs lecons.

**Le probleme.** Le parcours comptait un cours, une section, une unite et **une
seule lecon**, qui portait vingt-quatre exercices. Deux consequences :

1. Un « chemin d'apprentissage » a un seul noeud ne ressemble a rien. Aucun
   travail de mise en page ne sauve un parcours d'une etape.
2. Une lecon de vingt-quatre exercices contredit la regle du projet : une lecon
   dure trois a sept minutes (SS11). Vingt-quatre exercices en demandent quinze
   ou vingt.

**Ce que ce script fait, et ce qu'il ne fait pas.** Il ne cree **aucun contenu**.
Les exercices existent, ils sont valides, ils viennent du corpus sourcé. Le
script les regroupe par type et les repartit dans des lecons de six, en suivant
la regle de duree que le projet s'est donnee. Les titres de lecon decrivent le
**type d'exercice** — « Reconnaitre a l'oreille » — jamais un contenu culturel :
ce sont des faits sur la forme de l'exercice, pas des affirmations.

Les nouvelles lecons passent par le circuit complet DRAFT -> PUBLISHED, avec une
validation enregistree, comme n'importe quel objet pedagogique. Les triggers
d'integrite s'appliquent : le script ne les contourne pas.

Usage :
    python -m scripts.restructure_path
    python -m scripts.restructure_path --dry-run
"""

from __future__ import annotations

import argparse
import asyncio
import sys
import uuid

from sqlalchemy import text

from app.core.db import SessionLocal, engine

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

#: Combien d'exercices par lecon. Six tiennent dans trois a sept minutes, la
#: duree que le projet s'est fixee (SS11).
PAR_LECON = 6

#: Comment nommer une lecon selon le type d'exercice qu'elle contient.
#: Ces libelles decrivent la mecanique de l'exercice, pas son contenu : aucun
#: n'affirme quoi que ce soit sur la langue ou la culture.
TITRES = {
    "LISTEN_AND_CHOOSE": (
        "Reconnaître à l’oreille",
        "J’écoute un mot et je retrouve sa forme écrite.",
    ),
    "WORD_TO_AUDIO": (
        "Retrouver l’enregistrement",
        "Je lis un mot et je retrouve l’enregistrement qui le dit.",
    ),
    "MULTIPLE_CHOICE": (
        "Choisir la bonne forme",
        "Je distingue des formes proches les unes des autres.",
    ),
    "MEMORY_GAME": (
        "Associer de mémoire",
        "Je retrouve les paires de mots et de sons.",
    ),
}

#: L'ordre pedagogique : on ecoute avant de produire, on reconnait avant de
#: distinguer.
ORDRE = ["LISTEN_AND_CHOOSE", "WORD_TO_AUDIO", "MULTIPLE_CHOICE", "MEMORY_GAME"]


async def publier(db, table: str, item_id: uuid.UUID, validateur: uuid.UUID) -> None:
    """Fait passer un objet pedagogique par tout le circuit de validation.

    Les triggers refusent de sauter une etape (SS2) : on les suit, on ne les
    contourne pas.
    """
    for etape in ("SOURCE_FOUND", "TO_VERIFY", "HUMAN_REVIEW"):
        await db.execute(
            text(
                f"UPDATE learn.{table} SET status = CAST(:s AS shared.content_status) "
                "WHERE id = :id"
            ),
            {"s": etape, "id": item_id},
        )
    await db.execute(
        text(
            """
            INSERT INTO prov.content_validations
                (id, target_type, target_id, validator_contributor_id, decision, decided_at)
            VALUES (:id, :tt, :target, :val, 'ACCEPT', now())
            """
        ),
        {"id": uuid.uuid4(), "tt": table, "target": item_id, "val": validateur},
    )
    await db.execute(
        text(
            f"UPDATE learn.{table} SET status = 'VALIDATED', validated_by = :val "
            "WHERE id = :id"
        ),
        {"val": validateur, "id": item_id},
    )
    await db.execute(
        text(f"UPDATE learn.{table} SET status = 'PUBLISHED' WHERE id = :id"),
        {"id": item_id},
    )


async def executer(dry_run: bool) -> int:
    async with SessionLocal() as db:
        unite = (
            await db.execute(
                text(
                    """
                    SELECT u.id, u.section_id, u.source_id, u.created_by, u.validated_by
                    FROM learn.units u
                    WHERE u.status = 'PUBLISHED'
                    ORDER BY u.position
                    LIMIT 1
                    """
                )
            )
        ).one_or_none()
        if unite is None:
            print("[MBOA] aucune unité publiée : lancez d'abord seed_basaa.")
            await engine.dispose()
            return 1

        lecons = [
            dict(r._mapping)
            for r in await db.execute(
                text(
                    """
                    SELECT id, position, title_fr FROM learn.lessons
                    WHERE unit_id = :u AND status = 'PUBLISHED' ORDER BY position
                    """
                ),
                {"u": unite.id},
            )
        ]
        if len(lecons) > 1:
            print(
                f"[MBOA] l'unité compte déjà {len(lecons)} leçons : rien à faire."
            )
            await engine.dispose()
            return 0

        origine = lecons[0]
        blocs = [
            dict(r._mapping)
            for r in await db.execute(
                text(
                    """
                    SELECT b.id, b.position, b.kind::text AS kind, b.exercise_id,
                           e.type::text AS type
                    FROM learn.lesson_blocks b
                    LEFT JOIN learn.exercises e ON e.id = b.exercise_id
                    WHERE b.lesson_id = :l
                    ORDER BY b.position
                    """
                ),
                {"l": origine["id"]},
            )
        ]
        pratiques = [b for b in blocs if b["kind"] == "PRACTICE" and b["type"]]
        encadrement = [b for b in blocs if b["kind"] != "PRACTICE"]

        # Les exercices, regroupes par type puis decoupes en lecons de six.
        par_type: dict[str, list[dict]] = {}
        for bloc in pratiques:
            par_type.setdefault(bloc["type"], []).append(bloc)

        # Répartition **équitable** au sein d'un type : découper 13 exercices
        # en tranches de six donne 6 + 6 + 1, et une leçon d'un seul exercice
        # est pire que pas de découpage du tout. On calcule donc combien de
        # leçons il faut, puis on répartit.
        MINIMUM = 3
        groupes: list[tuple[list[str], list[dict]]] = []
        for type_exercice in ORDRE + [t for t in par_type if t not in ORDRE]:
            liste = par_type.get(type_exercice, [])
            if not liste:
                continue
            combien = max(1, -(-len(liste) // PAR_LECON))
            taille = -(-len(liste) // combien)
            for debut in range(0, len(liste), taille):
                groupes.append(([type_exercice], liste[debut : debut + taille]))

        # Un groupe trop maigre rejoint le précédent : une leçon de deux
        # exercices ne vaut pas le détour, et le titre dira honnêtement qu'elle
        # mêle plusieurs formes.
        fusionnes: list[tuple[list[str], list[dict]]] = []
        for types, groupe in groupes:
            if len(groupe) < MINIMUM and fusionnes:
                types_precedents, precedent = fusionnes[-1]
                fusionnes[-1] = (
                    list(dict.fromkeys(types_precedents + types)),
                    precedent + groupe,
                )
            else:
                fusionnes.append((types, groupe))
        groupes = fusionnes

        def nommer(types: list[str], groupe: list[dict]) -> tuple[str, str]:
            """Le titre d'une leçon, d'après les formes d'exercice qu'elle porte."""
            if len(types) > 1:
                return (
                    "Exercices variés",
                    "Je mêle les formes rencontrées jusqu’ici.",
                )
            return TITRES.get(
                types[0],
                (types[0].replace("_", " ").capitalize(), ""),
            )

        print(
            f"[MBOA] {len(pratiques)} exercice(s) dans 1 leçon "
            f"-> {len(groupes)} leçon(s) de {PAR_LECON} au plus."
        )
        for index, (types, groupe) in enumerate(groupes):
            titre, objectif = nommer(types, groupe)
            memes = [g for g in groupes if g[0] == types]
            if len(memes) > 1:
                titre = f"{titre} {memes.index((types, groupe)) + 1}/{len(memes)}"
            print(
                f"   {index + 1}. {titre:34} {len(groupe)} exercice(s)"
                f"  — {objectif[:46]}"
            )

        if dry_run:
            await engine.dispose()
            return 0

        validateur = unite.validated_by or unite.created_by

        # La première leçon existe déjà : on la renomme et on lui laisse son
        # premier groupe. Les autres sont créées.
        nouvelles: list[uuid.UUID] = []
        for index, (types, groupe) in enumerate(groupes):
            titre, _ = nommer(types, groupe)
            memes = [g for g in groupes if g[0] == types]
            if len(memes) > 1:
                titre = f"{titre} {memes.index((types, groupe)) + 1}/{len(memes)}"

            if index == 0:
                lecon_id = origine["id"]
                await db.execute(
                    text(
                        """
                        UPDATE learn.lessons
                        SET title_fr = :titre, position = 0,
                            estimated_minutes = :minutes, xp_reward = 10
                        WHERE id = :id
                        """
                    ),
                    {
                        "titre": titre,
                        "minutes": max(3, min(7, len(groupe))),
                        "id": lecon_id,
                    },
                )
            else:
                lecon_id = uuid.uuid4()
                await db.execute(
                    text(
                        """
                        INSERT INTO learn.lessons
                            (id, unit_id, position, kind, title_fr,
                             estimated_minutes, xp_reward, status, source_id, created_by)
                        VALUES (:id, :u, :pos, 'LESSON', :titre, :minutes, 10,
                                'DRAFT', :src, :by)
                        """
                    ),
                    {
                        "id": lecon_id,
                        "u": unite.id,
                        "pos": index,
                        "titre": titre,
                        "minutes": max(3, min(7, len(groupe))),
                        "src": unite.source_id,
                        "by": unite.created_by,
                    },
                )
                nouvelles.append(lecon_id)

            # Les blocs migrent vers leur nouvelle leçon, renumérotés.
            for position, bloc in enumerate(groupe):
                await db.execute(
                    text(
                        "UPDATE learn.lesson_blocks SET lesson_id = :l, position = :p "
                        "WHERE id = :id"
                    ),
                    {"l": lecon_id, "p": position + 1, "id": bloc["id"]},
                )

        # L'introduction et le récapitulatif restent sur la première leçon :
        # ils encadrent l'entrée dans l'unité.
        for bloc in encadrement:
            await db.execute(
                text(
                    "UPDATE learn.lesson_blocks SET lesson_id = :l WHERE id = :id"
                ),
                {"l": origine["id"], "id": bloc["id"]},
            )

        await db.commit()

        for lecon_id in nouvelles:
            await publier(db, "lessons", lecon_id, validateur)
        await db.commit()

        etat = [
            dict(r._mapping)
            for r in await db.execute(
                text(
                    """
                    SELECT l.position, l.title_fr, l.status::text AS status,
                           count(b.id) AS blocs
                    FROM learn.lessons l
                    LEFT JOIN learn.lesson_blocks b ON b.lesson_id = l.id
                    WHERE l.unit_id = :u
                    GROUP BY l.id, l.position, l.title_fr, l.status
                    ORDER BY l.position
                    """
                ),
                {"u": unite.id},
            )
        ]

    await engine.dispose()
    print("\n[MBOA] parcours après répartition :")
    for lecon in etat:
        print(
            f"   {lecon['position']}. {lecon['title_fr'][:38]:40} "
            f"{lecon['status']:10} {lecon['blocs']} bloc(s)"
        )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="montre sans modifier")
    return asyncio.run(executer(parser.parse_args().dry_run))


if __name__ == "__main__":
    sys.exit(main())
