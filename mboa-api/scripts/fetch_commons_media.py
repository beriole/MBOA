"""Rapatrie des photographies et des videos libres depuis Wikimedia Commons.

**Pourquoi.** Le catalogue culturel n'avait aucune image : les fiches sont du
texte, et la table `cultural_media` exige une fiche pour porter un media. Les
ecrans restaient donc vides alors que la matiere existe — Commons heberge des
milliers de photographies et des dizaines de videos du Cameroun, sous licence
libre, avec un auteur nomme.

**Ce que ce script garantit.**

1. **Aucun media sans licence libre.** La licence est relue dans les metadonnees
   Commons a chaque telechargement, et comparee a une liste blanche. Tout ce qui
   n'y figure pas est refuse et signale. On ne se fie pas au fait qu'un fichier
   soit sur Commons : certains y sont sous usage equitable.
2. **Aucune affirmation ajoutee.** Le titre et la description sont ceux de
   l'auteur, recopies tels quels. Le script n'invente ni legende ni attribution
   culturelle : dire d'un masque qu'il est bamileke serait une affirmation, et
   elle n'appartient pas a MBOA.
3. **La provenance reste verifiable.** L'adresse de la page Commons est
   conservee : licence, auteur et historique y restent consultables.

Le `theme` est une etiquette de rangement choisie par ce script pour l'affichage
(artisanat, danse, marche…). Ce n'est pas une affirmation sur ce qu'on voit.

Usage :
    python -m scripts.fetch_commons_media
    python -m scripts.fetch_commons_media --force
    python -m scripts.fetch_commons_media --dry-run   # verifie sans telecharger
"""

from __future__ import annotations

import argparse
import asyncio
import json
import re
import sys
import urllib.parse
import uuid
from pathlib import Path

import httpx
from sqlalchemy import text

from app.core.db import SessionLocal, engine

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

MEDIA = Path(__file__).resolve().parents[1] / "media" / "culture"
API = "https://commons.wikimedia.org/w/api.php"

#: Politique Wikimedia : un agent qui identifie le projet.
USER_AGENT = (
    "MBOA/0.1 (plateforme educative des langues camerounaises; "
    "https://github.com/mboa) httpx"
)

#: Les seules licences acceptees. Tout le reste est refuse, meme sur Commons :
#: la presence d'un fichier la-bas ne prouve pas qu'il soit librement
#: rediffusable.
LICENCES_LIBRES = {
    "cc0",
    "cc by 1.0",
    "cc by 2.0",
    "cc by 2.5",
    "cc by 3.0",
    "cc by 4.0",
    "cc by-sa 1.0",
    "cc by-sa 2.0",
    "cc by-sa 2.5",
    "cc by-sa 3.0",
    "cc by-sa 4.0",
    "public domain",
}

#: La recherche Commons est lache : « Cameroon traditional dance » remonte des
#: videos indonesiennes. Un media doit donc mentionner le Cameroun dans son
#: titre, sa description ou ses categories — sans quoi le ranger sous « danse »
#: reviendrait a presenter autre chose comme camerounais, ce qui est exactement
#: ce que la regle fondatrice interdit.
ANCRES = ("cameroon", "cameroun", "kamerun", "camerounais", "cameroonian")

#: Taille maximale d'un fichier. Au-dela, servir le media coute plus que ce
#: qu'il apporte, et l'application s'ouvrirait lentement sur une connexion
#: faible.
MAX_BYTES = 16 * 1024 * 1024

#: Les recherches menees sur Commons, et le rangement d'affichage associe.
#: Chaque entree : (theme, requete, type de fichier, combien en retenir).
RECHERCHES: list[tuple[str, str, str, int]] = [
    ("artisanat", "Cameroon basketry weaving", "bitmap", 6),
    ("artisanat", "Cameroon pottery", "bitmap", 5),
    ("artisanat", "Cameroon textile", "bitmap", 4),
    ("sculpture", "Cameroon mask sculpture", "bitmap", 6),
    ("marche", "Cameroon market", "bitmap", 5),
    ("musique", "Cameroon music instrument", "bitmap", 5),
    ("danse", "Cameroon traditional dance", "bitmap", 5),
    ("paysage", "Cameroon landscape", "bitmap", 5),
    ("architecture", "Cameroon architecture house", "bitmap", 4),
    ("cuisine", "Cameroon food dish", "bitmap", 4),
    # Les videos sont volumineuses : on en prend peu, et les plus legeres.
    ("danse", "Cameroon traditional dance", "video", 4),
    # Aucune video de langue camerounaise n'est retenable : la seule candidate
    # (« Jean Rene speaking Medumba », Wikitongues) ne porte, sur sa page
    # Commons, aucune mention du Cameroun — ni dans son titre, ni dans sa
    # description, ni dans ses categories. La rattacher ici reviendrait a ce que
    # MBOA affirme elle-meme le lien. Elle passera par une fiche sourcee, ou pas
    # du tout.
]


def sans_balises(valeur: str | None) -> str:
    """Commons renvoie ses metadonnees en HTML. On en retire le balisage."""
    if not valeur:
        return ""
    texte = re.sub(r"<[^>]+>", " ", valeur)
    texte = texte.replace("&amp;", "&").replace("&quot;", '"').replace("&#39;", "'")
    return re.sub(r"\s+", " ", texte).strip()


async def chercher(
    client: httpx.AsyncClient, requete: str, filetype: str, combien: int
) -> list[dict]:
    """Interroge Commons et renvoie les fichiers candidats, metadonnees incluses."""
    reponse = await client.get(
        API,
        params={
            "action": "query",
            "format": "json",
            "generator": "search",
            "gsrsearch": f"filetype:{filetype} {requete}",
            "gsrnamespace": "6",
            "gsrlimit": str(combien * 3),  # marge : certains seront refuses
            "prop": "imageinfo|categories",
            "iiprop": "url|size|mime|extmetadata|dimensions",
            "cllimit": "max",
        },
    )
    reponse.raise_for_status()
    pages = (reponse.json().get("query") or {}).get("pages", {})
    return list(pages.values())


def parle_du_cameroun(page: dict, meta: dict) -> bool:
    """Le media se rattache-t-il vraiment au Cameroun ?"""
    morceaux = [page.get("title", "")]
    morceaux.append(sans_balises(meta.get("ImageDescription", {}).get("value")))
    morceaux.append(sans_balises(meta.get("Categories", {}).get("value")))
    morceaux += [c.get("title", "") for c in page.get("categories", [])]
    foin = " ".join(morceaux).lower()
    return any(ancre in foin for ancre in ANCRES)


def retenir(page: dict) -> dict | None:
    """Valide un candidat, ou renvoie None en disant pourquoi il est ecarte."""
    infos = (page.get("imageinfo") or [{}])[0]
    meta = infos.get("extmetadata", {})

    if not parle_du_cameroun(page, meta):
        return None

    licence = sans_balises(meta.get("LicenseShortName", {}).get("value"))
    if licence.lower() not in LICENCES_LIBRES:
        return None

    auteur = sans_balises(meta.get("Artist", {}).get("value"))
    if not auteur:
        # Sans auteur nomme, CC BY et CC BY-SA sont inapplicables : on ne peut
        # pas crediter, donc on ne peut pas rediffuser.
        return None

    taille = infos.get("size", 0)
    if not taille or taille > MAX_BYTES:
        return None

    return {
        "titre": sans_balises(page["title"].removeprefix("File:").rsplit(".", 1)[0]),
        "description": sans_balises(
            meta.get("ImageDescription", {}).get("value")
        )[:1000]
        or None,
        "auteur": auteur[:300],
        "licence": licence[:64],
        "url": infos["url"],
        "page": infos.get("descriptionurl")
        or "https://commons.wikimedia.org/wiki/"
        + urllib.parse.quote(page["title"].replace(" ", "_")),
        "mime": infos.get("mime", ""),
        "largeur": infos.get("width"),
        "hauteur": infos.get("height"),
        "taille": taille,
    }


async def executer(force: bool, dry_run: bool) -> int:
    MEDIA.mkdir(parents=True, exist_ok=True)
    telecharges = ignores = refuses = 0

    async with httpx.AsyncClient(
        follow_redirects=True, timeout=180, headers={"User-Agent": USER_AGENT}
    ) as client:
        async with SessionLocal() as db:
            deja = {
                r[0]
                for r in await db.execute(text("SELECT source_url FROM culture.media_library"))
            }

        for theme, requete, filetype, combien in RECHERCHES:
            try:
                pages = await chercher(client, requete, filetype, combien)
            except httpx.HTTPError as exc:
                print(f"  [!] recherche « {requete} » : {exc}")
                continue

            candidats: list[dict] = []
            for page in pages:
                retenu = retenir(page)
                if retenu is None:
                    refuses += 1
                    continue
                candidats.append(retenu)

            # Les plus legers d'abord : a qualite d'affichage egale, ils servent
            # plus vite sur une connexion faible.
            candidats.sort(key=lambda c: c["taille"])
            print(f"\n[{theme}] « {requete} » ({filetype}) : {len(candidats)} retenable(s)")

            pris = 0
            for candidat in candidats:
                if pris >= combien:
                    break
                if candidat["page"] in deja and not force:
                    ignores += 1
                    pris += 1
                    continue

                extension = Path(urllib.parse.urlparse(candidat["url"]).path).suffix or ".jpg"
                identifiant = uuid.uuid4()
                cible = MEDIA / f"{identifiant}{extension}"
                kind = "VIDEO" if filetype == "video" else "IMAGE"

                if dry_run:
                    print(
                        f"   [essai] {candidat['titre'][:44]:46} "
                        f"{candidat['licence']:14} {candidat['taille'] // 1024:>6} Ko"
                    )
                    pris += 1
                    continue

                try:
                    async with client.stream("GET", candidat["url"]) as flux:
                        flux.raise_for_status()
                        with cible.open("wb") as sortie:
                            async for morceau in flux.aiter_bytes(65536):
                                sortie.write(morceau)
                except httpx.HTTPError as exc:
                    print(f"   [!] {candidat['titre'][:40]} : {exc}")
                    cible.unlink(missing_ok=True)
                    continue

                async with SessionLocal() as db:
                    await db.execute(
                        text(
                            """
                            INSERT INTO culture.media_library
                                (id, kind, file_key, title, description, author,
                                 license, source_url, theme, width, height)
                            VALUES (:id, CAST(:kind AS shared.cultural_media_kind),
                                    :cle, :titre, :desc, :auteur, :licence, :page,
                                    :theme, :l, :h)
                            ON CONFLICT (source_url) DO NOTHING
                            """
                        ),
                        {
                            "id": identifiant,
                            "kind": kind,
                            "cle": f"culture/{identifiant}{extension}",
                            "titre": candidat["titre"],
                            "desc": candidat["description"],
                            "auteur": candidat["auteur"],
                            "licence": candidat["licence"],
                            "page": candidat["page"],
                            "theme": theme,
                            "l": candidat["largeur"],
                            "h": candidat["hauteur"],
                        },
                    )
                    await db.commit()

                telecharges += 1
                pris += 1
                print(
                    f"   ok  {candidat['titre'][:44]:46} {candidat['licence']:14} "
                    f"{candidat['taille'] // 1024:>6} Ko  {candidat['auteur'][:24]}"
                )

    async with SessionLocal() as db:
        total = (
            await db.execute(text("SELECT count(*) FROM culture.media_library"))
        ).scalar_one()
        par_type = {
            r[0]: r[1]
            for r in await db.execute(
                text("SELECT kind::text, count(*) FROM culture.media_library GROUP BY 1")
            )
        }
    await engine.dispose()

    print(
        f"\n[MBOA] {telecharges} telecharge(s), {ignores} deja present(s), "
        f"{refuses} refuse(s) : licence non libre, auteur manquant, poids, ou "
        f"aucun rattachement au Cameroun."
    )
    print(f"[MBOA] mediatheque : {total} media(s) — {json.dumps(par_type)}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="retelecharge tout")
    parser.add_argument(
        "--dry-run", action="store_true", help="liste sans rien telecharger"
    )
    args = parser.parse_args()
    return asyncio.run(executer(args.force, args.dry_run))


if __name__ == "__main__":
    sys.exit(main())
