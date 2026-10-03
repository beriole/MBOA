"""Deroule le scenario du SS49 de bout en bout contre l'API locale.

    inscription -> choix de la langue -> parcours -> lecon -> ecoute -> reponses
    -> feedback -> fin de lecon -> XP -> progression -> revision du lendemain

Ce script sert de demonstration executable : il n'utilise que l'API publique,
exactement comme le fera l'application Flutter.
"""

from __future__ import annotations

import sys
import uuid
from pathlib import Path

import httpx

# Le script est lance depuis scripts/ : on rend le paquet `app` importable.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

BASE = "http://127.0.0.1:8010/api/v1"


def show(title: str) -> None:
    print(f"\n{'=' * 66}\n  {title}\n{'=' * 66}")


def advance_one_day(user_id: str) -> None:
    """Recule les echeances de revision de 24 h, pour simuler le lendemain.

    Uniquement pour la demonstration : l'API n'expose evidemment aucun moyen de
    manipuler le temps.
    """
    import asyncio

    from sqlalchemy import text

    from app.core.db import SessionLocal, engine

    async def _run() -> None:
        async with SessionLocal() as db:
            await db.execute(
                text(
                    """
                    UPDATE progress.review_items
                    SET next_review_at = next_review_at - interval '1 day'
                    WHERE user_id = :uid
                    """
                ),
                {"uid": user_id},
            )
            await db.commit()
        await engine.dispose()

    asyncio.run(_run())


def main() -> int:
    client = httpx.Client(base_url=BASE, timeout=30.0)

    # ------------------------------------------------------------------
    show("1. INSCRIPTION  (le role LEARNER est impose par le serveur)")
    email = f"demo-{uuid.uuid4().hex[:8]}@example.com"
    response = client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "motdepasse-demo-2026",
            "display_name": "Apprenant de demonstration",
            "daily_goal_xp": 20,
        },
    )
    response.raise_for_status()
    tokens = response.json()
    client.headers["Authorization"] = f"Bearer {tokens['access_token']}"
    profile = client.get("/auth/me").json()
    print(f"  compte : {profile['email']}")
    print(f"  role   : {profile['role']}  (impose, non choisi)")

    # ------------------------------------------------------------------
    show("2. CHOIX DE LA LANGUE")
    languages = client.get("/languages").json()
    for language in languages:
        print(
            f"  {language['name']} [{language['iso639_3']}] "
            f"autonyme={language['autonym']}  tons={language['tone_count']}  "
            f"mots publies={language['published_words']}"
        )
    language = languages[0]

    # ------------------------------------------------------------------
    show("3. PARCOURS")
    path = client.get(f"/languages/{language['id']}/path").json()
    print(f"  cours : {path['course']['title_fr']} (niveau {path['course']['level']})")
    first_lesson = None
    for section in path["sections"]:
        print(f"  Section {section['position'] + 1} - {section['title_fr']}")
        for unit in section["units"]:
            print(f"    Unite {unit['position'] + 1} - {unit['title_fr']}")
            print(f"      objectif : {unit['objective_fr']}")
            for lesson in unit["lessons"]:
                marker = {"COMPLETED": "[x]", "AVAILABLE": "[>]", "LOCKED": "[ ]"}.get(
                    lesson["status"], "[?]"
                )
                print(
                    f"      {marker} {lesson['title_fr']} "
                    f"({lesson['estimated_minutes']} min, {lesson['xp_reward']} XP)"
                )
                if first_lesson is None and lesson["status"] != "LOCKED":
                    first_lesson = lesson

    if first_lesson is None:
        print("  aucune lecon disponible")
        return 1

    # ------------------------------------------------------------------
    show("4. LECON")
    lesson = client.get(f"/lessons/{first_lesson['id']}").json()
    print(f"  {lesson['title_fr']} - {lesson['unit']['objective_fr']}")
    exercises = [b["exercise"] for b in lesson["blocks"] if b.get("exercise")]
    print(f"  {len(exercises)} exercices")

    leaked = [e for e in exercises if "answer_spec" in (e.get("payload") or {})]
    print(f"  fuite de la reponse dans le payload : {'OUI' if leaked else 'NON'}")

    session = client.post(f"/lessons/{first_lesson['id']}/start", json={}).json()
    print(f"  session : {session['session_id']}")

    # ------------------------------------------------------------------
    show("5. REPONSES  (volontairement : 1 erreur, puis des bonnes reponses)")
    correct_count = 0
    for index, exercise in enumerate(exercises):
        payload = exercise["payload"]
        choices = payload.get("choices") or []

        if exercise["type"] == "MEMORY_GAME":
            answer = {"matched_ids": [p["id"] for p in payload["pairs"]]}
        elif choices:
            # Premier exercice : on choisit volontairement mal, pour voir la
            # correction et l'entree en file de revision.
            pick = choices[-1] if index == 0 else choices[0]
            answer = {"choice_id": pick["id"]}
        else:
            answer = {}

        result = client.post(
            f"/exercises/{exercise['id']}/attempt",
            json={
                "session_id": session["session_id"],
                "client_attempt_id": str(uuid.uuid4()),
                "answer": answer,
                "response_ms": 1800,
            },
        ).json()

        if result["is_correct"]:
            correct_count += 1

        if index < 4:
            mark = "OK " if result["is_correct"] else "NON"
            label = payload.get("text") or payload.get("prompt_fr", "")
            print(f"  [{mark}] {exercise['type']:<18} {label[:38]:<38} +{result['xp_delta']} XP")

    print(f"  ... {len(exercises)} exercices traites, {correct_count} corrects")

    # ------------------------------------------------------------------
    show("6. IDEMPOTENCE  (rejeu d'une meme tentative, comme apres une coupure reseau)")
    replay_id = str(uuid.uuid4())
    body = {
        "session_id": session["session_id"],
        "client_attempt_id": replay_id,
        "answer": {"choice_id": "x"},
        "origin": "OFFLINE_SYNC",
    }
    first = client.post(f"/exercises/{exercises[0]['id']}/attempt", json=body).json()
    second = client.post(f"/exercises/{exercises[0]['id']}/attempt", json=body).json()
    print(f"  1er envoi : enregistre={not first['already_recorded']}  XP={first['xp_delta']}")
    print(f"  2e envoi  : deja enregistre={second['already_recorded']}  XP={second['xp_delta']}")

    # ------------------------------------------------------------------
    show("7. FIN DE LECON")
    summary = client.post(
        f"/lessons/{first_lesson['id']}/complete",
        json={"session_id": session["session_id"]},
    ).json()
    print(f"  score        : {summary['correct']}/{summary['total']} ({summary['score'] * 100:.0f} %)")
    print(f"  XP gagnes    : {summary['xp_awarded']}   total : {summary['total_xp']}")
    print(f"  serie        : {summary['streak']['current_days']} jour(s)")
    print(f"  a reviser    : {summary['items_to_review']} element(s) faibles")

    # ------------------------------------------------------------------
    show("8. PROGRESSION")
    progress = client.get("/progress").json()
    print(f"  XP du jour   : {progress['today_xp']} / {progress['daily_goal_xp']}"
          f"  objectif atteint : {'oui' if progress['goal_reached'] else 'non'}")
    print(f"  lecons finies: {progress['lessons_completed']}")
    print(f"  maitrise     : {progress['mastery']}")
    print(f"  a reviser    : {progress['items_due']}")

    # ------------------------------------------------------------------
    show("9. LE LENDEMAIN  (la repetition espacee ramene les elements faibles)")
    empty_today = client.get("/review").json()
    print(f"  aujourd'hui : {empty_today['count']} element(s) a reviser")
    print("    -> normal : la repetition espacee les replanifie a demain (SS14).")

    # Simulation du passage d'une journee. Seul point du script qui touche la
    # base directement, faute de pouvoir attendre 24 heures pour la demo.
    advance_one_day(profile["id"])
    print("  [simulation : on avance l'horloge de 24 h]")

    review = client.get("/review").json()
    print(f"  {review['count']} element(s) proposes :")
    for item in review["items"][:6]:
        print(f"    [{item['state']:<8}] {item['lemma']:<16} maitrise={item['mastery_score']}")

    # ------------------------------------------------------------------
    show("10. TRACABILITE  (provenance d'un mot, visible depuis l'application)")
    if review["items"]:
        provenance = client.get(f"/vocabulary/{review['items'][0]['target_id']}/provenance").json()
        print(f"  mot      : {provenance['lemma']}")
        print(f"  glose    : {provenance['meaning_fr'] or '(non renseignee - a saisir par un locuteur natif)'}")
        print(f"  source   : {provenance['source']['title']}")
        print(f"  licence  : {provenance['source']['license']}")
        print(f"  valide par : {provenance['validated_by']}")
        for reference in provenance["references"]:
            print(f"  reference : {reference['locator']}")
        print("  historique :")
        for step in provenance["history"]:
            print(f"    {step['from_status'] or 'creation':<14} -> {step['to_status']}")

    print("\n" + "=" * 66)
    print("  Scenario SS49 execute de bout en bout.")
    print("=" * 66 + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
