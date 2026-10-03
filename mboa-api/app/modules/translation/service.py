"""Traduction par recherche dans le corpus valide (SS41).

Principe : MBOA ne traduit pas, MBOA **retrouve**. Chaque reponse provient d'une
entree publiee du corpus, avec sa source et son enregistrement. Quand rien ne
correspond, on le dit — c'est preferable a une invention plausible.

Trois niveaux de correspondance, par confiance decroissante :

  1. EXACTE       la forme ecrite correspond, diacritiques comprises   -> 1.00
  2. SANS_TONS    elle correspond une fois les tons retires            -> 0.80
  3. SIMPLIFIEE   elle correspond en remplacant les lettres speciales  -> 0.70
                  de l'alphabet (ɓ, ɛ, ɔ, ŋ, ǝ) par leur equivalent
                  clavier : personne ne tape « ɓasaá » sur un telephone
  4. APPROCHANTE  similarite trigramme (faute de frappe, variante)     -> 0.30 a 0.70

Aucune correspondance sous le seuil n'est renvoyee : mieux vaut une reponse vide
qu'une suggestion trompeuse.
"""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass
from enum import StrEnum

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

#: En deca de ce score, une correspondance approchante est jugee trop hasardeuse.
SIMILARITY_THRESHOLD = 0.30

#: Version du moteur de recherche, tracee avec chaque demande.
ENGINE = "lexicon-search"
ENGINE_VERSION = "1.0"

#: Le francais n'est pas une langue du referentiel : c'est la langue pivot.
PIVOT = "fr"


class MatchKind(StrEnum):
    EXACT = "EXACT"
    TONELESS = "TONELESS"
    FOLDED = "FOLDED"
    FUZZY = "FUZZY"


CONFIDENCE = {
    MatchKind.EXACT: 1.0,
    MatchKind.TONELESS: 0.8,
    MatchKind.FOLDED: 0.7,
}

#: Lettres de l'Alphabet General des Langues Camerounaises absentes d'un clavier
#: ordinaire, et ce qu'un apprenant tape a leur place.
ALPHABET_FOLDING = {
    "ɓ": "b",  # ɓ implosive
    "Ɓ": "b",  # Ɓ
    "ɛ": "e",  # ɛ
    "Ɛ": "e",  # Ɛ
    "ɔ": "o",  # ɔ
    "Ɔ": "o",  # Ɔ
    "ǝ": "e",  # ǝ
    "ə": "e",  # ə
    "ŋ": "ng",  # ŋ
    "Ŋ": "ng",  # Ŋ
}


def strip_tones(value: str) -> str:
    """Retire les diacritiques combinantes, en conservant la forme NFC."""
    decomposed = unicodedata.normalize("NFD", value)
    return unicodedata.normalize(
        "NFC", "".join(c for c in decomposed if not unicodedata.combining(c))
    )


def fold_alphabet(value: str) -> str:
    """Ramene une forme a ce qu'un clavier ordinaire permet d'ecrire.

    Sert UNIQUEMENT a la recherche : la forme stockee et affichee reste
    l'orthographe exacte. On aide l'apprenant a trouver le mot, on ne modifie
    jamais le corpus.
    """
    simplified = strip_tones(value).lower()
    # Le groupe « ŋg » (prenasalisee) se tape « ng », pas « ngg ».
    simplified = simplified.replace("ŋg", "ng")
    return "".join(ALPHABET_FOLDING.get(c, c) for c in simplified)


def normalize(value: str) -> str:
    return unicodedata.normalize("NFC", value.strip())


@dataclass(frozen=True)
class Match:
    """Une correspondance trouvee dans le corpus."""

    vocabulary_id: str
    lemma: str
    meaning_fr: str | None
    grammatical_category: str
    kind: MatchKind
    confidence: float
    audio_url: str | None
    audio_attribution: str | None
    source_title: str | None
    source_license: str | None
    examples: list[dict]

    def as_dict(self) -> dict:
        return {
            "vocabulary_id": self.vocabulary_id,
            "lemma": self.lemma,
            "meaning_fr": self.meaning_fr,
            "grammatical_category": self.grammatical_category,
            "kind": self.kind.value,
            "confidence": round(self.confidence, 3),
            "audio_url": self.audio_url,
            "audio_attribution": self.audio_attribution,
            "source_title": self.source_title,
            "source_license": self.source_license,
            "examples": self.examples,
        }


#: Meme repli que `fold_alphabet`, exprime en SQL. `translate` gere les
#: substitutions de meme longueur ; ŋ -> ng exige un `replace` a part.
_SQL_FOLD = (
    "replace(replace(translate(lower(v.lemma_toneless), "
    "'ɓƁɛƐɔƆǝə', 'bbeeooee'), "
    "'ŋg', 'ng'), 'ŋ', 'ng')"
)

_SELECT = """
    SELECT v.id, v.lemma, v.meaning_fr,
           v.grammatical_category::text AS grammatical_category,
           CASE WHEN a.id IS NULL THEN NULL ELSE '/api/v1/audio/' || a.id END AS audio_url,
           a.attribution AS audio_attribution,
           s.title AS source_title, s.license::text AS source_license,
           {score} AS score
    FROM corpus.vocabulary_items v
    LEFT JOIN audio.audio_assets a ON a.id = v.primary_audio_id
    LEFT JOIN prov.sources s ON s.id = v.source_id
    WHERE v.language_id = :lang
      AND v.status = 'PUBLISHED'
      AND {condition}
    ORDER BY score DESC, v.lemma
    LIMIT :limit
"""


async def _query(
    db: AsyncSession, *, score: str, condition: str, params: dict
) -> list:
    rows = await db.execute(
        text(_SELECT.format(score=score, condition=condition)), params
    )
    return list(rows)


async def _examples_for(db: AsyncSession, vocabulary_id) -> list[dict]:
    """Phrases publiees qui emploient ce mot, pour montrer un usage atteste."""
    rows = await db.execute(
        text(
            """
            SELECT text, translation_fr FROM corpus.example_sentences
            WHERE status = 'PUBLISHED' AND :id = ANY(vocabulary_item_ids)
            LIMIT 3
            """
        ),
        {"id": vocabulary_id},
    )
    return [{"text": r.text, "translation_fr": r.translation_fr} for r in rows]


async def search(
    db: AsyncSession,
    *,
    language_id,
    query: str,
    into_french: bool,
    limit: int = 10,
) -> list[Match]:
    """Cherche `query` dans le corpus publie d'une langue.

    `into_french` = True  : on saisit un mot de la langue nationale.
    `into_french` = False : on saisit un mot francais, on cherche sa forme locale.
    """
    cleaned = normalize(query)
    if not cleaned:
        return []

    params = {"lang": language_id, "limit": limit, "q": cleaned}
    found: dict[str, Match] = {}

    async def collect(rows, kind: MatchKind) -> None:
        for row in rows:
            key = str(row.id)
            if key in found:
                continue
            confidence = CONFIDENCE.get(kind, float(row.score))
            found[key] = Match(
                vocabulary_id=key,
                lemma=row.lemma,
                meaning_fr=row.meaning_fr,
                grammatical_category=row.grammatical_category,
                kind=kind,
                confidence=confidence,
                audio_url=row.audio_url,
                audio_attribution=row.audio_attribution,
                source_title=row.source_title,
                source_license=row.source_license,
                examples=await _examples_for(db, row.id),
            )

    if into_french:
        await collect(
            await _query(
                db, score="1.0", condition="v.lemma = :q", params=params
            ),
            MatchKind.EXACT,
        )
        if len(found) < limit:
            params["toneless"] = strip_tones(cleaned).lower()
            await collect(
                await _query(
                    db,
                    score="0.8",
                    condition="lower(v.lemma_toneless) = :toneless",
                    params=params,
                ),
                MatchKind.TONELESS,
            )
        if len(found) < limit:
            params["folded"] = fold_alphabet(cleaned)
            await collect(
                await _query(
                    db,
                    score="0.7",
                    condition=f"{_SQL_FOLD} = :folded",
                    params=params,
                ),
                MatchKind.FOLDED,
            )
        if len(found) < limit:
            params["threshold"] = SIMILARITY_THRESHOLD
            await collect(
                await _query(
                    db,
                    score="similarity(v.lemma_toneless, :q)",
                    condition="similarity(v.lemma_toneless, :q) >= :threshold",
                    params=params,
                ),
                MatchKind.FUZZY,
            )
    else:
        # Sens francais -> forme locale. La glose doit exister : une entree sans
        # traduction validee ne peut evidemment pas repondre.
        await collect(
            await _query(
                db,
                score="1.0",
                condition="lower(v.meaning_fr) = lower(:q)",
                params=params,
            ),
            MatchKind.EXACT,
        )
        if len(found) < limit:
            params["threshold"] = SIMILARITY_THRESHOLD
            await collect(
                await _query(
                    db,
                    score="similarity(v.meaning_fr, :q)",
                    condition=(
                        "v.meaning_fr IS NOT NULL "
                        "AND similarity(v.meaning_fr, :q) >= :threshold"
                    ),
                    params=params,
                ),
                MatchKind.FUZZY,
            )

    return sorted(found.values(), key=lambda m: -m.confidence)[:limit]


def explain(matches: list[Match], *, into_french: bool, language_name: str) -> str:
    """Message affiche a l'utilisateur, honnete sur ce qui a ete fait."""
    if not matches:
        return (
            "Aucune correspondance dans le corpus validé. "
            "MBOA ne propose que des mots vérifiés par des locuteurs : "
            "ce mot n'a pas encore été documenté."
        )

    best = matches[0]
    if best.kind is MatchKind.EXACT:
        return f"{len(matches)} correspondance(s) trouvée(s) dans le corpus {language_name}."
    if best.kind is MatchKind.TONELESS:
        return (
            "Correspondance trouvée en ignorant les tons. "
            "Vérifiez les diacritiques : elles changent le sens."
        )
    if best.kind is MatchKind.FOLDED:
        return (
            f"Correspondance trouvée : l'orthographe exacte s'écrit « {best.lemma} ». "
            "Les lettres ɓ, ɛ, ɔ, ŋ ne sont pas de simples variantes de b, e, o, n."
        )
    return (
        "Aucune correspondance exacte. Voici les formes les plus proches du corpus — "
        "à confirmer avant de les employer."
    )
