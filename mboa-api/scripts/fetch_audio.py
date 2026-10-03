"""Telecharge une fois pour toutes les enregistrements, et les sert en local.

**Pourquoi.** Tant que `file_key` pointe vers Wikimedia, chaque ecoute part sur
le reseau : mesure a 1,5 a 2 secondes depuis Douala comme depuis ici. Pendant
une lecon, l'apprenant repond souvent avant que le son soit arrive, et il
entend la piste precedente. Les fichiers font 90 a 120 Ko : les garder a cote de
l'API coute 1,3 Mo et supprime l'attente.

**Licence.** Les enregistrements Lingua Libre sont sous CC BY-SA 4.0, qui
autorise la redistribution a condition de crediter et de partager aux memes
conditions. L'attribution est conservee en base et affichee a l'ecran ; elle
voyage aussi dans l'en-tete `X-Attribution` de chaque reponse.

**Agent.** Wikimedia refuse les requetes sans agent descriptif (403). On
s'annonce donc explicitement, comme leur politique le demande.

Usage :
    python -m scripts.fetch_audio
    python -m scripts.fetch_audio --force   # retelecharge meme si present
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

import httpx
from sqlalchemy import text

from app.core.db import SessionLocal, engine

# La console Windows est en cp1252 : elle ne sait pas ecrire ɓ ni ɛ. Un
# probleme d'affichage ne doit pas interrompre un telechargement.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

MEDIA = Path(__file__).resolve().parents[1] / "media" / "audio"

#: Politique Wikimedia : un agent qui identifie le projet et un contact.
USER_AGENT = (
    "MBOA/0.1 (plateforme educative des langues camerounaises; "
    "https://github.com/mboa) httpx"
)


async def fetch(force: bool) -> int:
    MEDIA.mkdir(parents=True, exist_ok=True)

    async with SessionLocal() as db:
        rows = list(
            await db.execute(
                text(
                    """
                    SELECT a.id, a.file_key, v.lemma
                    FROM audio.audio_assets a
                    LEFT JOIN corpus.vocabulary_items v
                      ON v.id = a.target_id AND a.target_type = 'VOCAB'
                    ORDER BY v.lemma NULLS LAST
                    """
                )
            )
        )

    distants = [r for r in rows if r.file_key.startswith("http")]
    print(f"[MBOA] {len(rows)} enregistrements, dont {len(distants)} encore distants")

    telecharges, ignores, echecs = 0, 0, 0
    async with httpx.AsyncClient(
        follow_redirects=True, timeout=60, headers={"User-Agent": USER_AGENT}
    ) as client:
        for row in rows:
            cible = MEDIA / f"{row.id}.wav"
            if cible.exists() and not force:
                ignores += 1
                continue
            if not row.file_key.startswith("http"):
                # Deja localise, mais le fichier manque : on ne sait plus ou le
                # reprendre. On le signale plutot que de le passer sous silence.
                print(f"  [!] {row.lemma or row.id} : fichier local absent ({row.file_key})")
                echecs += 1
                continue

            try:
                reponse = await client.get(row.file_key)
                reponse.raise_for_status()
            except httpx.HTTPError as exc:
                print(f"  [!] {row.lemma or row.id} : {exc}")
                echecs += 1
                continue

            cible.write_bytes(reponse.content)
            telecharges += 1
            print(f"  ok  {str(row.lemma or row.id):<18} {len(reponse.content) // 1024:>4} Ko")

    # On ne bascule les references qu'apres coup : une interruption au milieu
    # ne doit pas laisser la base pointer vers des fichiers absents.
    async with SessionLocal() as db:
        bascules = 0
        for row in rows:
            if (MEDIA / f"{row.id}.wav").exists() and row.file_key.startswith("http"):
                await db.execute(
                    text("UPDATE audio.audio_assets SET file_key = :k WHERE id = :id"),
                    {"k": f"audio/{row.id}.wav", "id": row.id},
                )
                bascules += 1
        await db.commit()

    await engine.dispose()
    print(
        f"\n[MBOA] {telecharges} telecharge(s), {ignores} deja present(s), "
        f"{echecs} echec(s), {bascules} reference(s) basculee(s) en local."
    )
    return 1 if echecs and not telecharges else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--force", action="store_true", help="retelecharge meme si le fichier existe"
    )
    return asyncio.run(fetch(parser.parse_args().force))


if __name__ == "__main__":
    sys.exit(main())
