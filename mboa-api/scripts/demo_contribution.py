"""Demonstration : la contribution debloque les exercices de sens.

Deroule le scenario complet contre l'API locale :

    corpus sans traduction -> seuls des exercices d'ecoute
      -> un contributeur traduit 4 mots
      -> un second contributeur relit et valide
      -> publication
      -> les exercices de sens apparaissent, apres revue humaine

Prerequis : l'API tourne sur le port 8010 et la base est remplie
(`python -m app.seed.seed_basaa`).
"""

from __future__ import annotations

import sys
import uuid
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import text  # noqa: E402
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine  # noqa: E402
from sqlalchemy.pool import NullPool  # noqa: E402

from app.core.config import settings  # noqa: E402


def run_sql(work):
    """Execute un acces direct a la base, sur un moteur dedie.

    Chaque appel cree puis ferme sa propre connexion : le script alterne des
    appels HTTP et des acces SQL, et un moteur partage entre plusieurs boucles
    asyncio finirait par utiliser une connexion deja fermee.
    """
    import asyncio

    async def _run():
        engine = create_async_engine(settings.database_url, poolclass=NullPool)
        maker = async_sessionmaker(engine, expire_on_commit=False)
        try:
            async with maker() as db:
                return await work(db)
        finally:
            await engine.dispose()

    return asyncio.run(_run())

BASE = "http://127.0.0.1:8010/api/v1"


def show(title: str) -> None:
    print(f"\n{'=' * 70}\n  {title}\n{'=' * 70}")


def promote(email: str, iso: str, name: str) -> None:
    """Promeut un compte en specialiste et l'habilite sur la langue."""

    async def _work(db):
        user_id = (
            await db.execute(text("SELECT id FROM iam.users WHERE email = :e"), {"e": email})
        ).scalar_one()
        language_id = (
            await db.execute(
                text("SELECT id FROM ref.languages WHERE iso639_3 = :i"), {"i": iso}
            )
        ).scalar_one()
        await db.execute(
            text("UPDATE iam.users SET role = 'CULTURAL_SPECIALIST' WHERE id = :id"),
            {"id": user_id},
        )
        contributor = uuid.uuid4()
        await db.execute(
            text(
                """
                INSERT INTO prov.contributors (id, user_id, display_name, role)
                VALUES (:id, :uid, :name, 'NATIVE_SPEAKER')
                """
            ),
            {"id": contributor, "uid": user_id, "name": name},
        )
        await db.execute(
            text(
                """
                INSERT INTO prov.validation_assignments
                    (id, contributor_id, language_id, scope, is_active)
                VALUES (:id, :cid, :lang, ARRAY['LEXICON','EXERCISE'], true)
                """
            ),
            {"id": uuid.uuid4(), "cid": contributor, "lang": language_id},
        )
        await db.commit()

    run_sql(_work)


def _client(email: str) -> httpx.Client:
    c = httpx.Client(base_url=BASE, timeout=30)
    tokens = c.post(
        "/auth/register",
        json={"email": email, "password": "motdepasse-demo-2026", "display_name": email[:8]},
    ).json()
    c.headers["Authorization"] = f"Bearer {tokens['access_token']}"
    return c


def main() -> int:
    suffix = uuid.uuid4().hex[:8]
    redacteur_mail = f"redacteur-{suffix}@example.com"
    validateur_mail = f"validateur-{suffix}@example.com"

    show("0. DEUX CONTRIBUTEURS  (la saisie et la validation ne sont jamais la meme personne)")
    redacteur = _client(redacteur_mail)
    validateur = _client(validateur_mail)
    promote(redacteur_mail, "bas", "Contributeur A (saisie)")
    promote(validateur_mail, "bas", "Contributeur B (relecture)")
    print(f"  redacteur  : {redacteur_mail}")
    print(f"  validateur : {validateur_mail}")

    langues = redacteur.get("/cms/languages").json()
    langue = langues[0]
    print(f"  langue     : {langue['name']} — {langue['sans_glose']} mot(s) sans traduction "
          f"sur {langue['total']}")

    show("1. ETAT DE DEPART  (le corpus est muet : aucune traduction)")
    apprenant = _client(f"apprenant-{suffix}@example.com")
    lang_id = langue["id"]
    path = apprenant.get(f"/languages/{lang_id}/path").json()
    lesson_id = path["sections"][0]["units"][0]["lessons"][0]["id"]
    unit_id = None

    lesson = apprenant.get(f"/lessons/{lesson_id}").json()
    types = {}
    for block in lesson["blocks"]:
        if block.get("exercise"):
            types[block["exercise"]["type"]] = types.get(block["exercise"]["type"], 0) + 1
    print(f"  exercices proposes : {types}")
    print("  -> aucun exercice de sens : MBOA n'invente pas de traduction.")

    show("2. SAISIE  (un locuteur traduit quatre mots)")
    queue = redacteur.get(f"/cms/queue?language_id={lang_id}&only_missing_gloss=true").json()
    cibles = queue["items"][:4]
    if len(cibles) < 4:
        print("  [!] moins de 4 mots sans traduction : relancez le seed.")
        return 1

    # Traductions de demonstration, volontairement neutres : elles seront
    # remplacees par celles d'un vrai locuteur natif.
    for index, item in enumerate(cibles, start=1):
        gloss = f"sens à confirmer par un locuteur ({index})"
        result = redacteur.patch(
            f"/cms/vocabulary/{item['id']}",
            json={"meaning_fr": gloss, "grammatical_category": "NOUN"},
        ).json()
        print(f"  {item['lemma']:<16} -> \"{gloss}\"   statut : {result['status']}")
    print("  -> chaque saisie repasse en relecture : elle ne se publie pas toute seule.")

    show("3. AUTO-VALIDATION REFUSEE  (le redacteur tente de valider son propre travail)")
    refus = redacteur.post(
        f"/cms/vocabulary/{cibles[0]['id']}/decision", json={"decision": "ACCEPT"}
    )
    print(f"  reponse HTTP {refus.status_code} : {refus.json()['detail']}")

    show("4. RELECTURE PAR UN SECOND CONTRIBUTEUR")
    for item in cibles:
        decision = validateur.post(
            f"/cms/vocabulary/{item['id']}/decision",
            json={"decision": "ACCEPT", "comment": "Forme et sens verifies."},
        ).json()
        publication = validateur.post(f"/cms/vocabulary/{item['id']}/publish").json()
        print(f"  {item['lemma']:<16} {decision['status']} -> {publication['status']}")

    show("5. GENERATION DES EXERCICES DE SENS")
    # On rattache les mots a l'unite existante.
    async def _unit(db) -> str:
            unit = (
                await db.execute(
                    text(
                        """
                        SELECT u.id FROM learn.units u
                        JOIN learn.sections s ON s.id = u.section_id
                        JOIN learn.courses c ON c.id = s.course_id
                        WHERE c.language_id = :lang LIMIT 1
                        """
                    ),
                    {"lang": lang_id},
                )
            ).scalar_one()
            return str(unit)

    unit_id = run_sql(_unit)
    generation = redacteur.post(f"/cms/units/{unit_id}/generate-exercises").json()
    print(f"  {generation['message']}")
    print(f"  mots traduits disponibles : {generation['glossed_words']}")

    en_attente = [
        e
        for e in redacteur.get(f"/cms/exercises/pending?language_id={lang_id}").json()
        if e["status"] != "VALIDATED"
    ]
    print(f"  exercices en attente de revue : {len(en_attente)}")
    print("  -> generes, mais PAS publies : un humain doit encore les relire (SS13).")

    show("6. REVUE DES EXERCICES, PUIS PUBLICATION")
    publies = 0
    for exercice in en_attente:
        reponse = validateur.post(
            f"/cms/exercises/{exercice['id']}/decision", json={"decision": "ACCEPT"}
        )
        if reponse.status_code == 200 and reponse.json()["status"] == "PUBLISHED":
            publies += 1
    print(f"  {publies} exercice(s) de sens publie(s).")

    attachement = validateur.post(f"/cms/lessons/{lesson_id}/attach-exercises").json()
    print(f"  {attachement['message']}")

    show("7. COTE APPRENANT  (la lecon a change)")
    lesson = apprenant.get(f"/lessons/{lesson_id}").json()
    nouveaux = {}
    exemple = None
    for block in lesson["blocks"]:
        exercice = block.get("exercise")
        if exercice:
            nouveaux[exercice["type"]] = nouveaux.get(exercice["type"], 0) + 1
            if exercice["type"] == "MULTIPLE_CHOICE" and exemple is None:
                exemple = exercice

    print(f"  exercices proposes : {nouveaux}")
    if exemple:
        print(f"\n  Exemple d'exercice de sens :")
        print(f"    {exemple['payload']['prompt_fr']}")
        for choix in exemple["payload"]["choices"]:
            print(f"      - {choix['text']}")
        print("    (les mauvaises reponses sont les traductions reelles d'autres mots)")

    print("\n" + "=" * 70)
    print("  La contribution humaine a debloque un nouveau type d'exercice.")
    print("=" * 70 + "\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
