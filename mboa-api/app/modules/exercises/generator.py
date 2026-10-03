"""Generation d'exercices a partir du corpus valide (SS13).

Regles appliquees :
  1. Seuls des objets VALIDATED ou PUBLISHED alimentent un exercice.
  2. Un distracteur est toujours une autre entree reelle du corpus, jamais une
     forme fabriquee : une mauvaise reponse n'enseigne donc jamais du faux.
  3. Un exercice qui exige une glose francaise n'est pas genere tant que la
     glose n'est pas validee.
  4. Chaque exercice conserve `generated_from` : la base refuse l'insertion si
     une origine n'est pas validee (trigger `trg_exercise_sources`).
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import Any

from app.shared.enums import ExerciseType


class GenerationError(RuntimeError):
    """Leve quand le corpus ne permet pas de generer l'exercice demande."""


@dataclass(frozen=True)
class CorpusWord:
    """Vue minimale d'une entree lexicale validee, telle qu'utilisee par le generateur."""

    id: str
    lemma: str
    meaning_fr: str | None
    audio_url: str | None
    audio_attribution: str | None = None

    @property
    def has_audio(self) -> bool:
        return bool(self.audio_url)

    @property
    def has_gloss(self) -> bool:
        return bool(self.meaning_fr)


@dataclass
class GeneratedExercise:
    type: ExerciseType
    payload: dict[str, Any]
    answer_spec: dict[str, Any]
    generated_from: list[dict[str, str]]
    explanation_fr: str | None = None
    difficulty: int = 1
    generator_version: str = field(default="1.0")


DEFAULT_CHOICE_COUNT = 4


def _pick_distractors(
    target: CorpusWord,
    pool: list[CorpusWord],
    count: int,
    *,
    require_audio: bool = False,
    require_gloss: bool = False,
    rng: random.Random,
) -> list[CorpusWord]:
    """Selectionne des distracteurs reels, issus du meme corpus valide."""
    candidates = [
        w
        for w in pool
        if w.id != target.id
        and (not require_audio or w.has_audio)
        and (not require_gloss or w.has_gloss)
        and w.lemma != target.lemma
    ]
    if len(candidates) < count:
        raise GenerationError(
            f"corpus insuffisant : {len(candidates)} distracteur(s) disponible(s), {count} requis"
        )
    return rng.sample(candidates, count)


def generate_listen_and_choose(
    target: CorpusWord, pool: list[CorpusWord], *, rng: random.Random
) -> GeneratedExercise:
    """Ecouter un mot, puis choisir sa forme ecrite.

    N'exige aucune traduction : exploitable des qu'un locuteur natif a enregistre
    la forme. C'est le premier exercice possible sur un corpus jeune.
    """
    if not target.has_audio:
        raise GenerationError(f"'{target.lemma}' n'a pas d'audio de reference")

    distractors = _pick_distractors(
        target, pool, DEFAULT_CHOICE_COUNT - 1, rng=rng
    )
    choices = [{"id": w.id, "text": w.lemma} for w in [target, *distractors]]
    rng.shuffle(choices)

    return GeneratedExercise(
        type=ExerciseType.LISTEN_AND_CHOOSE,
        payload={
            "prompt_fr": "Qu'as-tu entendu ?",
            "audio_url": target.audio_url,
            "audio_attribution": target.audio_attribution,
            "choices": choices,
        },
        answer_spec={"correct_id": target.id},
        generated_from=[{"type": "VOCAB", "id": w["id"]} for w in choices],
    )


def generate_word_to_audio(
    target: CorpusWord, pool: list[CorpusWord], *, rng: random.Random
) -> GeneratedExercise:
    """Voir une forme ecrite, puis reconnaitre l'enregistrement correspondant."""
    if not target.has_audio:
        raise GenerationError(f"'{target.lemma}' n'a pas d'audio de reference")

    distractors = _pick_distractors(
        target, pool, DEFAULT_CHOICE_COUNT - 1, require_audio=True, rng=rng
    )
    choices = [
        {"id": w.id, "audio_url": w.audio_url, "audio_attribution": w.audio_attribution}
        for w in [target, *distractors]
    ]
    rng.shuffle(choices)

    return GeneratedExercise(
        type=ExerciseType.WORD_TO_AUDIO,
        payload={
            "prompt_fr": "Quel enregistrement correspond a ce mot ?",
            "text": target.lemma,
            "choices": choices,
        },
        answer_spec={"correct_id": target.id},
        generated_from=[{"type": "VOCAB", "id": c["id"]} for c in choices],
    )


def generate_multiple_choice(
    target: CorpusWord, pool: list[CorpusWord], *, rng: random.Random
) -> GeneratedExercise:
    """Donner le sens d'un mot. Exige une glose validee pour la cible ET les distracteurs."""
    if not target.has_gloss:
        raise GenerationError(
            f"'{target.lemma}' n'a pas de glose validee : exercice de sens impossible"
        )

    distractors = _pick_distractors(
        target, pool, DEFAULT_CHOICE_COUNT - 1, require_gloss=True, rng=rng
    )
    choices = [{"id": w.id, "text": w.meaning_fr} for w in [target, *distractors]]
    rng.shuffle(choices)

    return GeneratedExercise(
        type=ExerciseType.MULTIPLE_CHOICE,
        payload={
            "prompt_fr": f"Que signifie « {target.lemma} » ?",
            "text": target.lemma,
            "audio_url": target.audio_url,
            "choices": choices,
        },
        answer_spec={"correct_id": target.id},
        generated_from=[{"type": "VOCAB", "id": c["id"]} for c in choices],
    )


def generate_memory_game(
    words: list[CorpusWord], *, rng: random.Random, size: int = 4
) -> GeneratedExercise:
    """Associer chaque forme ecrite a son enregistrement."""
    playable = [w for w in words if w.has_audio]
    if len(playable) < size:
        raise GenerationError(
            f"corpus insuffisant : {len(playable)} mot(s) avec audio, {size} requis"
        )

    selection = rng.sample(playable, size)
    return GeneratedExercise(
        type=ExerciseType.MEMORY_GAME,
        payload={
            "prompt_fr": "Retrouve les paires : mot et enregistrement.",
            "pairs": [
                {
                    "id": w.id,
                    "text": w.lemma,
                    "audio_url": w.audio_url,
                    "audio_attribution": w.audio_attribution,
                }
                for w in selection
            ],
        },
        answer_spec={"pairs": [w.id for w in selection]},
        generated_from=[{"type": "VOCAB", "id": w.id} for w in selection],
    )


def build_lesson_exercises(
    words: list[CorpusWord], *, seed: int = 20260918
) -> list[GeneratedExercise]:
    """Assemble une lecon : reconnaissance, puis association, puis jeu.

    Suit la progression du SS7 : ECOUTER -> ASSOCIER. Les etapes COMPRENDRE et
    PRODUIRE demandent des gloses validees et apparaissent automatiquement des
    que le corpus les contient.
    """
    rng = random.Random(seed)
    exercises: list[GeneratedExercise] = []

    playable = [w for w in words if w.has_audio]
    for word in playable:
        exercises.append(generate_listen_and_choose(word, playable, rng=rng))

    for word in playable[: max(1, len(playable) // 2)]:
        exercises.append(generate_word_to_audio(word, playable, rng=rng))

    # Les exercices de sens n'apparaissent que si le corpus porte des gloses validees.
    for word in (w for w in words if w.has_gloss):
        try:
            exercises.append(generate_multiple_choice(word, words, rng=rng))
        except GenerationError:
            continue

    if len(playable) >= 4:
        exercises.append(generate_memory_game(playable, rng=rng))

    return exercises
