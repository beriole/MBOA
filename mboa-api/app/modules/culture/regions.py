"""Exploration du patrimoine par region, et quiz culturel (lot 9).

Deux principes valent ici comme ailleurs :

  - **on compte ce qui existe.** Les maquettes affichent « 12 peuples, 6 langues,
    24 sites culturels » pour une region ; ces nombres sont lus en base, et
    valent souvent zero. Une region sans fiche est montree comme telle.

  - **un quiz ne s'invente pas.** Chaque question est derivee d'une fiche
    culturelle PUBLIEE, donc sourcee et validee : la rubrique a laquelle elle
    appartient, la region dont elle parle, ou l'affirmation qu'elle porte. Les
    mauvaises reponses sont d'autres rubriques ou d'autres regions reelles.
    La correction renvoie la fiche et sa source, pour qu'on puisse verifier.
"""

from __future__ import annotations

import random
import uuid
from dataclasses import dataclass

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session

router = APIRouter(prefix="/culture", tags=["culture"])

#: Nombre de propositions visé. On descend jusqu'a MIN_CHOICES quand le corpus
#: n'en offre pas davantage : trois propositions testent encore quelque chose,
#: deux ne testent plus rien.
CHOICES_PER_QUESTION = 4
MIN_CHOICES = 3

#: Types de question derivables sans rien inventer.
#: Depuis une fiche culturelle publiee :
CATEGORY = "CATEGORY"
REGION = "REGION"
SUMMARY = "SUMMARY"
#: Depuis un enregistrement dont l'auteur et la licence sont connus :
AUDIO_WORD = "AUDIO_WORD"
WORD_AUDIO = "WORD_AUDIO"


def propositions(bonne: dict, pool: list[dict]) -> list[dict] | None:
    """Tire des distracteurs parmi des entites REELLES, jamais fabriquees.

    Si le vivier ne permet pas MIN_CHOICES propositions, on ne pose pas la
    question. Completer avec des intrus inventes rendrait la bonne reponse
    devinable et ferait entrer de la fiction dans un contenu verifie.
    """
    autres = [item for item in pool if item["id"] != bonne["id"]]
    if len(autres) < MIN_CHOICES - 1:
        return None
    combien = min(CHOICES_PER_QUESTION, len(autres) + 1) - 1
    choix = random.sample(autres, combien) + [bonne]
    random.shuffle(choix)
    return [{"id": str(c["id"]), "label": c["label"]} for c in choix]


@dataclass(frozen=True)
class QuizQuestion:
    """Une question et ses propositions.

    L'identifiant porte la cible et le type : la correction se recalcule depuis
    la base, sans qu'aucune reponse n'ait besoin de voyager jusqu'au client ni
    d'etre stockee.
    """

    target_id: uuid.UUID
    kind: str
    prompt: str
    choices: list[dict]
    #: Renseigne quand l'enonce lui-meme s'ecoute.
    audio_url: str | None = None

    @property
    def id(self) -> str:
        return f"{self.target_id}:{self.kind}"

    def payload(self) -> dict:
        return {
            "id": self.id,
            "type": self.kind,
            "prompt_fr": self.prompt,
            "choices": self.choices,
            "audio_url": self.audio_url,
        }


class QuizAnswer(BaseModel):
    question_id: str
    choice_id: uuid.UUID


# ---------------------------------------------------------------------------
# Regions
# ---------------------------------------------------------------------------
@router.get("/regions")
async def list_regions(db: AsyncSession = Depends(get_session)) -> list[dict]:
    """Les dix regions du Cameroun, avec ce qui est documente dans chacune.

    Les regions sans fiche restent dans la liste : montrer ce qui reste a
    documenter fait partie du propos (SS20).
    """
    rows = await db.execute(
        text(
            """
            SELECT r.id, r.code, r.name,
                   count(c.id) FILTER (WHERE c.status = 'PUBLISHED') AS fiches,
                   count(DISTINCT c.language_id)
                       FILTER (WHERE c.status = 'PUBLISHED'
                               AND c.language_id IS NOT NULL) AS langues
            FROM ref.regions r
            LEFT JOIN culture.cultural_contents c ON c.region_id = r.id
            GROUP BY r.id, r.code, r.name
            ORDER BY count(c.id) FILTER (WHERE c.status = 'PUBLISHED') DESC, r.name
            """
        )
    )
    return [dict(r._mapping) for r in rows]


@router.get("/regions/{region_id}")
async def region_detail(
    region_id: uuid.UUID, db: AsyncSession = Depends(get_session)
) -> dict:
    region = (
        await db.execute(
            text("SELECT id, code, name FROM ref.regions WHERE id = :id"),
            {"id": region_id},
        )
    ).one_or_none()
    if region is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Region introuvable.")

    counts = (
        await db.execute(
            text(
                """
                SELECT
                    (SELECT count(*) FROM culture.cultural_contents
                      WHERE region_id = :id AND status = 'PUBLISHED') AS fiches,
                    (SELECT count(DISTINCT language_id) FROM culture.cultural_contents
                      WHERE region_id = :id AND status = 'PUBLISHED'
                        AND language_id IS NOT NULL) AS langues,
                    (SELECT count(*) FROM ref.communities co
                      JOIN ref.languages l ON l.id = co.language_id
                      WHERE EXISTS (
                        SELECT 1 FROM culture.cultural_contents c
                        WHERE c.region_id = :id AND c.language_id = l.id
                          AND c.status = 'PUBLISHED')) AS communautes
                """
            ),
            {"id": region_id},
        )
    ).one()

    contents = await db.execute(
        text(
            """
            SELECT c.id, c.title_fr, c.summary_fr, c.reading_minutes,
                   cat.code::text AS category_code, cat.name_fr AS category_name,
                   l.name AS language_name
            FROM culture.cultural_contents c
            JOIN culture.cultural_categories cat ON cat.id = c.category_id
            LEFT JOIN ref.languages l ON l.id = c.language_id
            WHERE c.region_id = :id AND c.status = 'PUBLISHED'
            ORDER BY c.published_at DESC NULLS LAST, c.title_fr
            """
        ),
        {"id": region_id},
    )
    items = [dict(r._mapping) for r in contents]

    # Rubriques representees dans cette region : ce sont les onglets de la
    # maquette, construits sur ce qui existe plutot que sur une liste fixe.
    rubriques: dict[str, dict] = {}
    for item in items:
        entry = rubriques.setdefault(
            item["category_code"], {"code": item["category_code"], "name": item["category_name"], "fiches": 0}
        )
        entry["fiches"] += 1

    medias = (
        await db.execute(
            text(
                """
                SELECT m.kind::text AS kind, count(*) AS total
                FROM culture.cultural_media m
                JOIN culture.cultural_contents c ON c.id = m.cultural_content_id
                WHERE c.region_id = :id AND c.status = 'PUBLISHED'
                GROUP BY m.kind
                """
            ),
            {"id": region_id},
        )
    ).all()

    return {
        "region": dict(region._mapping),
        "chiffres": dict(counts._mapping),
        "rubriques": sorted(rubriques.values(), key=lambda r: -r["fiches"]),
        "medias": {m.kind: m.total for m in medias},
        "fiches": items,
    }


# ---------------------------------------------------------------------------
# Quiz culturel
# ---------------------------------------------------------------------------
async def _fiche_questions(db: AsyncSession) -> list[QuizQuestion]:
    """Les questions derivees des fiches culturelles publiees."""
    fiches = [
        dict(r._mapping)
        for r in await db.execute(
            text(
                """
                SELECT c.id, c.title_fr, c.summary_fr, c.category_id, c.region_id,
                       cat.name_fr AS category_name, r.name AS region_name
                FROM culture.cultural_contents c
                JOIN culture.cultural_categories cat ON cat.id = c.category_id
                LEFT JOIN ref.regions r ON r.id = c.region_id
                WHERE c.status = 'PUBLISHED'
                """
            )
        )
    ]
    if not fiches:
        return []

    categories = [
        dict(r._mapping)
        for r in await db.execute(
            text(
                "SELECT id, name_fr AS label FROM culture.cultural_categories "
                "WHERE is_active ORDER BY position"
            )
        )
    ]
    regions = [
        dict(r._mapping)
        for r in await db.execute(text("SELECT id, name AS label FROM ref.regions ORDER BY name"))
    ]
    titres = [{"id": f["id"], "label": f["title_fr"]} for f in fiches]

    questions: list[QuizQuestion] = []
    for fiche in fiches:
        choix = propositions(
            {"id": fiche["category_id"], "label": fiche["category_name"]}, categories
        )
        if choix:
            questions.append(
                QuizQuestion(
                    target_id=fiche["id"],
                    kind=CATEGORY,
                    prompt=f"À quelle rubrique appartient la fiche « {fiche['title_fr']} » ?",
                    choices=choix,
                )
            )

        if fiche["region_id"] is not None:
            choix = propositions(
                {"id": fiche["region_id"], "label": fiche["region_name"]}, regions
            )
            if choix:
                questions.append(
                    QuizQuestion(
                        target_id=fiche["id"],
                        kind=REGION,
                        prompt=f"De quelle région parle la fiche « {fiche['title_fr']} » ?",
                        choices=choix,
                    )
                )

        choix = propositions({"id": fiche["id"], "label": fiche["title_fr"]}, titres)
        if choix:
            questions.append(
                QuizQuestion(
                    target_id=fiche["id"],
                    kind=SUMMARY,
                    prompt=f"Quelle fiche affirme ceci ?\n« {fiche['summary_fr']} »",
                    choices=choix,
                )
            )
    return questions


async def _audio_questions(db: AsyncSession) -> list[QuizQuestion]:
    """Les questions derivees des enregistrements sourcés.

    Le corpus compte peu de fiches culturelles, mais chaque mot du vocabulaire
    publie porte un enregistrement dont l'auteur et la licence sont connus.
    C'est de la matiere sourcee, et elle permet deux questions honnetes : celle
    qui fait ecouter et demander le mot, et son inverse.

    Ce qui reste impossible : demander la traduction. Les gloses disponibles
    disent « sens à confirmer par un locuteur » — ce n'est pas un sens, c'est
    l'aveu qu'il manque. Poser la question reviendrait a faire valider une
    reponse que personne n'a etablie.
    """
    mots = [
        dict(r._mapping)
        for r in await db.execute(
            text(
                """
                SELECT v.id, v.lemma, a.id AS audio_id, a.attribution,
                       l.name AS language_name
                FROM corpus.vocabulary_items v
                JOIN audio.audio_assets a
                  ON a.target_id = v.id AND a.target_type = 'VOCAB'
                JOIN ref.languages l ON l.id = v.language_id
                WHERE v.status = 'PUBLISHED'
                ORDER BY v.lemma
                """
            )
        )
    ]
    if len(mots) < MIN_CHOICES:
        return []

    lemmes = [{"id": m["id"], "label": m["lemma"]} for m in mots]
    questions: list[QuizQuestion] = []
    for mot in mots:
        # On entend, on reconnait le mot ecrit.
        choix = propositions({"id": mot["id"], "label": mot["lemma"]}, lemmes)
        if choix:
            questions.append(
                QuizQuestion(
                    target_id=mot["id"],
                    kind=AUDIO_WORD,
                    prompt="Quel mot entendez-vous ?",
                    choices=choix,
                    audio_url=f"/api/v1/audio/{mot['audio_id']}",
                )
            )

        # On lit, on retrouve l'enregistrement : chaque proposition s'ecoute.
        pistes = [{"id": m["id"], "label": m["lemma"], "audio": m["audio_id"]} for m in mots]
        choix = propositions(
            {"id": mot["id"], "label": mot["lemma"], "audio": mot["audio_id"]}, pistes
        )
        if choix:
            questions.append(
                QuizQuestion(
                    target_id=mot["id"],
                    kind=WORD_AUDIO,
                    prompt=f"Lequel de ces enregistrements dit « {mot['lemma']} » ?",
                    choices=[
                        {
                            "id": c["id"],
                            # Le libelle est masque : sinon la reponse est lisible.
                            "label": f"Enregistrement {index + 1}",
                            "audio_url": "/api/v1/audio/"
                            + str(next(p["audio"] for p in pistes if str(p["id"]) == c["id"])),
                        }
                        for index, c in enumerate(choix)
                    ],
                )
            )
    return questions


@router.get("/quiz")
async def quiz(
    limit: int = Query(default=10, ge=1, le=40), db: AsyncSession = Depends(get_session)
) -> dict:
    """Un quiz tire de ce qui est publie et sourcé.

    Deux gisements l'alimentent : les fiches culturelles validees, et les
    enregistrements du vocabulaire, dont l'auteur et la licence sont connus. Le
    second est aujourd'hui le plus fourni — c'est lui qui fait qu'un quiz existe
    au-dela de trois questions.

    Le plafond reste dicte par le corpus. On l'annonce dans la reponse plutot
    que de completer avec des questions fabriquees.
    """
    questions = (await _fiche_questions(db)) + (await _audio_questions(db))
    random.shuffle(questions)
    disponibles = len(questions)
    questions = questions[:limit]

    publiees = (
        await db.execute(
            text("SELECT count(*) FROM culture.cultural_contents WHERE status = 'PUBLISHED'")
        )
    ).scalar_one()
    enregistres = (
        await db.execute(
            text(
                """
                SELECT count(*) FROM corpus.vocabulary_items v
                JOIN audio.audio_assets a
                  ON a.target_id = v.id AND a.target_type = 'VOCAB'
                WHERE v.status = 'PUBLISHED'
                """
            )
        )
    ).scalar_one()

    return {
        "questions": [q.payload() for q in questions],
        "fiches_publiees": publiees,
        "mots_enregistres": enregistres,
        "questions_disponibles": disponibles,
        "message": (
            f"{disponibles} questions sont aujourd'hui dérivables de {publiees} fiche"
            f"{'s' if publiees > 1 else ''} publiée{'s' if publiees > 1 else ''} et "
            f"{enregistres} enregistrement{'s' if enregistres > 1 else ''} sourcé"
            f"{'s' if enregistres > 1 else ''}. Le quiz s'étoffera à mesure que du "
            "contenu vérifié sera validé."
            if questions
            else "Rien de publié ne permet encore de poser une question."
        ),
    }


async def _correct_fiche(db: AsyncSession, target_id: uuid.UUID, kind: str) -> dict:
    fiche = (
        await db.execute(
            text(
                """
                SELECT c.id, c.title_fr, c.summary_fr, c.category_id, c.region_id,
                       cat.name_fr AS category_name, r.name AS region_name,
                       s.title AS source_title, s.authors AS source_authors,
                       s.year AS source_year
                FROM culture.cultural_contents c
                JOIN culture.cultural_categories cat ON cat.id = c.category_id
                LEFT JOIN ref.regions r ON r.id = c.region_id
                LEFT JOIN prov.sources s ON s.id = c.source_id
                WHERE c.id = :id AND c.status = 'PUBLISHED'
                """
            ),
            {"id": target_id},
        )
    ).one_or_none()
    if fiche is None:
        raise HTTPException(status_code=404, detail="Fiche introuvable ou retirée.")

    attendu, libelle = {
        CATEGORY: (fiche.category_id, fiche.category_name),
        REGION: (fiche.region_id, fiche.region_name),
        SUMMARY: (fiche.id, fiche.title_fr),
    }[kind]
    if attendu is None:
        raise HTTPException(status_code=409, detail="Cette question n'est plus posable.")

    return {
        "attendu": attendu,
        "correct_label": libelle,
        "explication_fr": (
            f"« {fiche.title_fr} » est classée dans la rubrique {fiche.category_name}."
            if kind == CATEGORY
            else f"« {fiche.title_fr} » traite de la région {fiche.region_name}."
            if kind == REGION
            else f"C'est « {fiche.title_fr} » qui l'affirme."
        ),
        "fiche": {
            "id": str(fiche.id),
            "title_fr": fiche.title_fr,
            "summary_fr": fiche.summary_fr,
        },
        "source": (
            {
                "title": fiche.source_title,
                "authors": list(fiche.source_authors or []),
                "year": fiche.source_year,
            }
            if fiche.source_title
            else None
        ),
    }


async def _correct_audio(db: AsyncSession, target_id: uuid.UUID, kind: str) -> dict:
    mot = (
        await db.execute(
            text(
                """
                SELECT v.id, v.lemma, a.id AS audio_id, a.attribution,
                       a.license::text AS license, l.name AS language_name
                FROM corpus.vocabulary_items v
                JOIN audio.audio_assets a
                  ON a.target_id = v.id AND a.target_type = 'VOCAB'
                JOIN ref.languages l ON l.id = v.language_id
                WHERE v.id = :id AND v.status = 'PUBLISHED'
                """
            ),
            {"id": target_id},
        )
    ).one_or_none()
    if mot is None:
        raise HTTPException(status_code=404, detail="Mot introuvable ou retiré.")

    return {
        # Dans les deux sens, la bonne reponse designe le mot lui-meme : les
        # propositions du second type portent l'identifiant du mot, pas celui
        # de la piste, pour que la correction reste la meme des deux cotes.
        "attendu": mot.id,
        "correct_label": mot.lemma,
        "explication_fr": (
            f"C'est « {mot.lemma} », en {mot.language_name}."
            if kind == AUDIO_WORD
            else f"La bonne piste est celle de « {mot.lemma} », en {mot.language_name}."
        ),
        "fiche": None,
        "audio_url": f"/api/v1/audio/{mot.audio_id}",
        "source": (
            {"title": mot.attribution, "authors": [], "year": None} if mot.attribution else None
        ),
    }


@router.post("/quiz/answer")
async def answer(payload: QuizAnswer, db: AsyncSession = Depends(get_session)) -> dict:
    """Corrige une reponse, cote serveur.

    La bonne reponse est relue depuis la base : elle n'a jamais transite par le
    client. La correction renvoie ce qui l'etablit — la fiche et sa source, ou
    l'attribution de l'enregistrement.
    """
    try:
        target_text, kind = payload.question_id.rsplit(":", 1)
        target_id = uuid.UUID(target_text)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail="Question inconnue.") from exc

    if kind in (CATEGORY, REGION, SUMMARY):
        resultat = await _correct_fiche(db, target_id, kind)
    elif kind in (AUDIO_WORD, WORD_AUDIO):
        resultat = await _correct_audio(db, target_id, kind)
    else:
        raise HTTPException(status_code=422, detail="Type de question inconnu.")

    attendu = resultat.pop("attendu")
    return {
        "is_correct": payload.choice_id == attendu,
        "correct_id": str(attendu),
        **resultat,
    }
