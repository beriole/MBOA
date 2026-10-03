"""Deroule le circuit d'habilitation de bout en bout, par l'API.

Une apprenante candidate pour valider le basaa, une administratrice statue, et
l'espace contributeur s'ouvre. Le script affiche ensuite le journal et les
controles d'integrite : c'est la demonstration que les droits ne s'accordent pas
en silence.

Prerequis : l'API tourne sur http://127.0.0.1:8010

Usage :
    python -m scripts.demo_administration
"""

from __future__ import annotations

import asyncio
import sys
import uuid

import httpx

BASE = "http://127.0.0.1:8010/api/v1"
PASSWORD = "motdepasse-solide"


def titre(text: str) -> None:
    print(f"\n{text}")
    print("-" * len(text))


async def register(client: httpx.AsyncClient, display_name: str) -> tuple[str, dict]:
    email = f"demo-{uuid.uuid4().hex[:8]}@example.org"
    response = await client.post(
        "/auth/register",
        json={"email": email, "password": PASSWORD, "display_name": display_name},
    )
    response.raise_for_status()
    token = response.json()["access_token"]
    return email, {"Authorization": f"Bearer {token}"}


async def main() -> int:
    async with httpx.AsyncClient(base_url=BASE, timeout=20) as client:
        try:
            await client.get("/languages")
        except httpx.ConnectError:
            print("[erreur] l'API ne repond pas sur http://127.0.0.1:8010")
            return 1

        languages = (await client.get("/languages")).json()
        if not languages:
            print("[erreur] aucune langue en base : lancez d'abord les scripts de seed.")
            return 1
        language = languages[0]

        # -------------------------------------------------------- les comptes
        titre("1. Deux comptes ordinaires")
        learner_email, learner = await register(client, "Ngo Bassong")
        admin_email, admin = await register(client, "Administratrice")
        print(f"   apprenante     : {learner_email}")
        print(f"   administratrice: {admin_email}")

        # Le premier administrateur ne peut pas se designer lui-meme depuis
        # l'API : on passe par la ligne de commande, comme en production.
        from app.core.db import SessionLocal

        async with SessionLocal() as db:
            from sqlalchemy import text

            await db.execute(
                text("UPDATE iam.users SET role = 'ADMIN' WHERE email = :e"),
                {"e": admin_email},
            )
            await db.commit()
        print("   role ADMIN accorde hors API (scripts.grant_admin)")

        # --------------------------------------------------- l'acces est ferme
        titre("2. Avant toute decision, l'espace contributeur est ferme")
        closed = await client.get(
            f"/cms/queue?language_id={language['id']}", headers=learner
        )
        print(f"   GET /cms/queue -> {closed.status_code} : {closed.json()['detail']}")

        # ------------------------------------------------------ la candidature
        titre("3. L'apprenante candidate")
        application = await client.post(
            "/me/specialist-application",
            headers=learner,
            json={
                "language_id": language["id"],
                "claimed_role": "NATIVE_SPEAKER",
                "relationship_fr": (
                    "Langue maternelle, parlee quotidiennement en famille depuis "
                    "l'enfance ; je co-anime une emission de radio communautaire."
                ),
                "affiliation": "Radio communautaire (demonstration)",
                "referees_fr": "Le responsable d'antenne peut confirmer.",
                "requested_scope": ["LEXICON", "AUDIO"],
            },
        )
        application.raise_for_status()
        application_id = application.json()["id"]
        print(f"   candidature deposee sur {language['name']} : {application_id}")

        pending = (
            await client.get("/admin/applications?status=PENDING", headers=admin)
        ).json()
        print(f"   file d'attente de l'administration : {len(pending)} demande(s)")

        # --------------------------------------------------------- la decision
        titre("4. L'administration statue, avec un motif")
        sans_motif = await client.post(
            f"/admin/applications/{application_id}/decision",
            headers=admin,
            json={"decision": "ACCEPT", "reason": "ok"},
        )
        print(f"   motif de deux caracteres -> {sans_motif.status_code} (refuse)")

        decision = await client.post(
            f"/admin/applications/{application_id}/decision",
            headers=admin,
            json={
                "decision": "ACCEPT",
                "reason": (
                    "Entretien mene le 3 avril ; le responsable d'antenne confirme "
                    "la pratique quotidienne de la langue."
                ),
                "granted_scope": ["LEXICON"],
            },
        )
        decision.raise_for_status()
        print(f"   decision enregistree, perimetre accorde : {decision.json()['scope']}")
        print("   (le perimetre accorde est plus etroit que celui demande)")

        # ----------------------------------------------------- l'acces s'ouvre
        titre("5. L'espace contributeur s'ouvre, avec le meme jeton")
        opened = await client.get(
            f"/cms/queue?language_id={language['id']}", headers=learner
        )
        queue = opened.json()
        print(f"   GET /cms/queue -> {opened.status_code}")
        print(f"   mots en attente de glose : {queue['missing_gloss']}")

        # ------------------------------------------------------- la tracabilite
        titre("6. Le journal, que rien n'efface")
        for entry in (await client.get("/admin/audit", headers=admin)).json()[:5]:
            print(f"   {entry['action']:<24} {entry['target_label'] or ''}")
            print(f"     motif : {entry['reason']}")
            print(f"     par   : {entry['actor_label']}")

        titre("7. Les controles d'integrite")
        integrity = (await client.get("/admin/integrity", headers=admin)).json()
        for check in integrity["controles"]:
            marque = "ok " if check["conforme"] else "!! "
            print(f"   {marque}{check['libelle']:<52}{check['anomalies']}")
        print(
            f"\n   conforme : {integrity['conforme']} "
            f"({integrity['anomalies_totales']} anomalie(s))"
        )

    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
