"""Le fil du patrimoine : ce qui est publie, presente comme un fil.

Les maquettes demandent un fil a la facon d'un reseau social - cartes, images,
sons, commentaires. La forme est reprise ; ce qui la remplit ne l'est pas.

Un fil social affiche ce que n'importe qui poste. Ici, un element n'entre dans
le fil que s'il est deja passe par la chaine de validation : une fiche PUBLISHED
porte une source, un enregistrement porte son auteur et sa licence. Le fil est
donc une **mise en page** de contenu verifie, pas un mur de publication libre.

Ce que le fil ne fabrique pas :

  - il n'y a aujourd'hui **aucune video ni aucun chant** au catalogue. Le fil
    l'annonce au lieu d'illustrer avec ce qui passe. Les enregistrements
    disponibles sont des mots isoles du vocabulaire : les presenter comme de la
    musique traditionnelle serait faux ;
  - les commentaires apparaissent sous les cartes, jamais dedans. Un avis ne
    devient pas une ligne de la fiche.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session

router = APIRouter(prefix="/culture", tags=["culture"])

#: Ce que le fil sait afficher aujourd'hui, et ce qui manque pour le reste.
#: Chaque entree est verifiee en base avant d'etre annoncee : ces phrases ne
#: doivent jamais survivre a l'arrivee du contenu qu'elles disent absent.
MANQUES = {
    "VIDEO": (
        "Aucune vidéo au catalogue. MBOA n'en diffusera que sous licence établie ; "
        "aucune illustration de remplissage n'est affichée."
    ),
    "CHANT": (
        "Aucun chant ni morceau de musique n'est encore collecté. Les "
        "enregistrements disponibles sont des mots isolés du vocabulaire : les "
        "présenter comme de la musique serait faux."
    ),
    "IMAGE": (
        "Aucune photographie n'accompagne encore les fiches. Une image sans "
        "provenance ni licence ne sera pas publiée."
    ),
}


async def _compteurs_sociaux(
    db: AsyncSession, cibles: list[tuple[str, uuid.UUID]]
) -> dict[tuple[str, str], dict]:
    """Nombre de commentaires et de favoris, par cible."""
    if not cibles:
        return {}
    types = [t for t, _ in cibles]
    ids = [i for _, i in cibles]

    commentaires = await db.execute(
        text(
            """
            SELECT target_type, target_id, count(*) AS total
            FROM culture.comments
            WHERE hidden_at IS NULL
              AND (target_type, target_id) IN (
                  SELECT * FROM unnest(CAST(:types AS text[]), CAST(:ids AS uuid[]))
              )
            GROUP BY target_type, target_id
            """
        ),
        {"types": types, "ids": ids},
    )
    favoris = await db.execute(
        text(
            """
            SELECT target_type, target_id, count(*) AS total
            FROM culture.favorites
            WHERE (target_type, target_id) IN (
                SELECT * FROM unnest(CAST(:types AS text[]), CAST(:ids AS uuid[]))
            )
            GROUP BY target_type, target_id
            """
        ),
        {"types": types, "ids": ids},
    )

    stats: dict[tuple[str, str], dict] = {}
    for row in commentaires:
        stats.setdefault((row.target_type, str(row.target_id)), {})["commentaires"] = row.total
    for row in favoris:
        stats.setdefault((row.target_type, str(row.target_id)), {})["favoris"] = row.total
    return stats


@router.get("/feed")
async def feed(
    region_id: uuid.UUID | None = Query(default=None),
    limit: int = Query(default=30, ge=1, le=100),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Le fil : fiches publiees et enregistrements sourcés, melanges par date."""
    conditions = "WHERE c.status = 'PUBLISHED'"
    params: dict = {"n": limit}
    if region_id is not None:
        conditions += " AND c.region_id = :region"
        params["region"] = region_id

    fiches = [
        dict(r._mapping)
        for r in await db.execute(
            text(
                f"""
                SELECT c.id, c.title_fr, c.summary_fr, c.body_fr, c.reading_minutes,
                       c.published_at, c.created_at,
                       cat.name_fr AS categorie, cat.code::text AS categorie_code,
                       r.name AS region, r.id AS region_id,
                       l.name AS langue,
                       s.title AS source_title, s.authors AS source_authors,
                       s.year AS source_year, s.url AS source_url
                FROM culture.cultural_contents c
                JOIN culture.cultural_categories cat ON cat.id = c.category_id
                LEFT JOIN ref.regions r ON r.id = c.region_id
                LEFT JOIN ref.languages l ON l.id = c.language_id
                LEFT JOIN prov.sources s ON s.id = c.source_id
                {conditions}
                ORDER BY coalesce(c.published_at, c.created_at) DESC
                LIMIT :n
                """
            ),
            params,
        )
    ]

    # Les medias attaches aux fiches retenues.
    medias: dict[str, list[dict]] = {}
    if fiches:
        for row in await db.execute(
            text(
                """
                SELECT m.cultural_content_id, m.kind::text AS kind, m.file_key,
                       m.caption, m.credit, m.license
                FROM culture.cultural_media m
                WHERE m.cultural_content_id = ANY(CAST(:ids AS uuid[]))
                ORDER BY m.position
                """
            ),
            {"ids": [f["id"] for f in fiches]},
        ):
            medias.setdefault(str(row.cultural_content_id), []).append(
                {
                    "kind": row.kind,
                    "url": row.file_key,
                    "caption": row.caption,
                    "credit": row.credit,
                    "license": row.license,
                }
            )

    # Les enregistrements : ils n'entrent dans un fil regional que si une fiche
    # publiee rattache leur langue a la region demandee.
    audio_params: dict = {"n": limit}
    audio_filtre = ""
    if region_id is not None:
        audio_filtre = """
            AND a.language_id IN (
                SELECT language_id FROM culture.cultural_contents
                WHERE region_id = :region AND status = 'PUBLISHED'
                  AND language_id IS NOT NULL
            )
        """
        audio_params["region"] = region_id

    enregistrements = [
        dict(r._mapping)
        for r in await db.execute(
            text(
                f"""
                SELECT a.id, a.attribution, a.license::text AS license, a.duration_ms,
                       a.created_at, v.lemma, v.meaning_fr,
                       l.name AS langue, sp.display_code AS locuteur
                FROM audio.audio_assets a
                JOIN corpus.vocabulary_items v
                  ON v.id = a.target_id AND a.target_type = 'VOCAB'
                JOIN ref.languages l ON l.id = a.language_id
                LEFT JOIN audio.speakers sp ON sp.id = a.speaker_id
                WHERE v.status = 'PUBLISHED' {audio_filtre}
                ORDER BY a.created_at DESC, v.lemma
                LIMIT :n
                """
            ),
            audio_params,
        )
    ]

    cibles = [("CULTURAL_CONTENT", f["id"]) for f in fiches]
    cibles += [("AUDIO", a["id"]) for a in enregistrements]
    stats = await _compteurs_sociaux(db, cibles)

    def social(target_type: str, target_id) -> dict:
        s = stats.get((target_type, str(target_id)), {})
        return {
            "target_type": target_type,
            "commentaires": s.get("commentaires", 0),
            "favoris": s.get("favoris", 0),
        }

    posts: list[dict] = []
    for f in fiches:
        posts.append(
            {
                "id": str(f["id"]),
                "kind": "FICHE",
                "titre": f["title_fr"],
                "texte": f["summary_fr"],
                "corps": f["body_fr"],
                "categorie": f["categorie"],
                "region": f["region"],
                "langue": f["langue"],
                "minutes": f["reading_minutes"],
                "media": medias.get(str(f["id"]), []),
                "date": f["published_at"] or f["created_at"],
                "source": (
                    {
                        "title": f["source_title"],
                        "authors": list(f["source_authors"] or []),
                        "year": f["source_year"],
                        "url": f["source_url"],
                    }
                    if f["source_title"]
                    else None
                ),
                **social("CULTURAL_CONTENT", f["id"]),
            }
        )

    for a in enregistrements:
        posts.append(
            {
                "id": str(a["id"]),
                "kind": "ENREGISTREMENT",
                "titre": a["lemma"],
                # On ne remplace pas une glose absente par une approximation.
                "texte": a["meaning_fr"],
                "corps": None,
                "categorie": "Prononciation",
                "region": None,
                "langue": a["langue"],
                "minutes": None,
                "media": [],
                "audio_url": f"/api/v1/audio/{a['id']}",
                "attribution": a["attribution"],
                "license": a["license"],
                "locuteur": a["locuteur"],
                "date": a["created_at"],
                "source": (
                    {"title": a["attribution"], "authors": [], "year": None, "url": None}
                    if a["attribution"]
                    else None
                ),
                **social("AUDIO", a["id"]),
            }
        )

    posts.sort(key=lambda p: p["date"], reverse=True)
    posts = posts[:limit]

    # Ce qui manque n'est annonce que si c'est vrai : on le relit en base.
    # CHANT n'a pas de colonne a interroger - le modele de donnees n'a pas de
    # notion de morceau. Son absence est donc structurelle, pas conjoncturelle,
    # et c'est ce que le message dit.
    presents = {m["kind"] for liste in medias.values() for m in liste}
    manques = [
        {"kind": kind, "message": message}
        for kind, message in MANQUES.items()
        if kind == "CHANT" or kind not in presents
    ]

    return {
        "posts": posts,
        "compteurs": {
            "fiches": len(fiches),
            "enregistrements": len(enregistrements),
            "videos": sum(1 for liste in medias.values() for m in liste if m["kind"] == "VIDEO"),
            "images": sum(1 for liste in medias.values() for m in liste if m["kind"] == "IMAGE"),
        },
        "manques": manques,
        "avertissement": (
            "Chaque publication de ce fil est passée par la validation : une fiche "
            "porte sa source, un enregistrement porte son auteur et sa licence. Les "
            "commentaires, eux, n'engagent que leurs auteurs."
        ),
    }
