"""Correction des reponses, cote serveur exclusivement (SS39).

Le client Flutter ne recoit jamais `answer_spec`. Il envoie une reponse, le
serveur tranche. Cela vaut aussi en mode hors-ligne : les tentatives locales
sont rejouees et re-corrigees par le serveur lors de la synchronisation.
"""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass
from typing import Any

from app.shared.enums import ExerciseType


@dataclass(frozen=True)
class CheckResult:
    is_correct: bool
    correct_answer: Any
    detail: str | None = None


class UnsupportedExerciseType(NotImplementedError):
    pass


def _normalize_text(value: str, *, strip_tones: bool = False) -> str:
    """Normalise une saisie pour comparaison.

    Toujours en NFC. `strip_tones` retire les diacritiques combinantes : la
    tolerance aux tons est un reglage pedagogique (elle est activee aux premiers
    niveaux, desactivee ensuite), jamais une approximation silencieuse.
    """
    text = unicodedata.normalize("NFC", value.strip().casefold())
    if strip_tones:
        decomposed = unicodedata.normalize("NFD", text)
        text = "".join(c for c in decomposed if not unicodedata.combining(c))
        text = unicodedata.normalize("NFC", text)
    return text


def _check_single_choice(answer: dict, answer_spec: dict) -> CheckResult:
    chosen = answer.get("choice_id")
    expected = answer_spec["correct_id"]
    return CheckResult(is_correct=chosen == expected, correct_answer=expected)


def _check_memory_game(answer: dict, answer_spec: dict) -> CheckResult:
    expected = set(answer_spec["pairs"])
    matched = set(answer.get("matched_ids") or [])
    return CheckResult(
        is_correct=matched == expected,
        correct_answer=sorted(expected),
        detail=f"{len(matched & expected)}/{len(expected)} paires trouvees",
    )


def _check_typed_text(answer: dict, answer_spec: dict) -> CheckResult:
    expected = answer_spec["correct_text"]
    tolerate_tones = bool(answer_spec.get("tolerate_tones", False))
    given = _normalize_text(answer.get("text", ""), strip_tones=tolerate_tones)
    target = _normalize_text(expected, strip_tones=tolerate_tones)
    return CheckResult(is_correct=given == target, correct_answer=expected)


def _check_ordered_tokens(answer: dict, answer_spec: dict) -> CheckResult:
    expected = answer_spec["correct_order"]
    given = answer.get("order") or []
    return CheckResult(is_correct=list(given) == list(expected), correct_answer=expected)


def _check_boolean(answer: dict, answer_spec: dict) -> CheckResult:
    expected = bool(answer_spec["correct_value"])
    return CheckResult(is_correct=bool(answer.get("value")) is expected, correct_answer=expected)


def _check_always_accepted(answer: dict, answer_spec: dict) -> CheckResult:
    """SPEAK : l'apprenant s'ecoute et se compare a la reference.

    Aucun score de prononciation n'est calcule tant qu'aucun modele fiable ne le
    justifie (SS19). L'exercice est donc toujours valide : il sert a produire,
    pas a juger.
    """
    return CheckResult(
        is_correct=True,
        correct_answer=answer_spec.get("reference_audio_url"),
        detail="Aucun score de prononciation n'est calcule a ce stade.",
    )


CHECKERS = {
    ExerciseType.MULTIPLE_CHOICE: _check_single_choice,
    ExerciseType.IMAGE_CHOICE: _check_single_choice,
    ExerciseType.LISTEN_AND_CHOOSE: _check_single_choice,
    ExerciseType.WORD_TO_AUDIO: _check_single_choice,
    ExerciseType.AUDIO_TO_WORD: _check_single_choice,
    ExerciseType.FILL_BLANK: _check_single_choice,
    ExerciseType.DIALOGUE: _check_single_choice,
    ExerciseType.TRUE_FALSE: _check_boolean,
    ExerciseType.MEMORY_GAME: _check_memory_game,
    ExerciseType.WORD_MATCHING: _check_memory_game,
    ExerciseType.LISTEN_AND_TYPE: _check_typed_text,
    ExerciseType.TRANSLATION: _check_typed_text,
    ExerciseType.ORDER_WORDS: _check_ordered_tokens,
    ExerciseType.SPEAK: _check_always_accepted,
    ExerciseType.PRONUNCIATION: _check_always_accepted,
}


def check_answer(
    exercise_type: ExerciseType, answer: dict, answer_spec: dict
) -> CheckResult:
    checker = CHECKERS.get(exercise_type)
    if checker is None:
        raise UnsupportedExerciseType(f"aucun correcteur pour {exercise_type}")
    return checker(answer or {}, answer_spec)
