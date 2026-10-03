"""Repetition espacee (SS14).

Variante simplifiee de SM-2, calculee exclusivement cote serveur.

Principe impose par le cahier des charges : "Une erreur ne doit pas disparaitre
apres la fin d'une lecon." Un echec ramene donc l'element a l'etat WEAK et a un
intervalle de 1 jour, quel que soit son historique.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from app.shared.enums import MasteryState

#: Progression des intervalles, en jours.
INTERVALS = (1, 3, 7, 14, 30)

#: Nombre de bonnes reponses consecutives a partir duquel un element est maitrise.
MASTERY_THRESHOLD = 5


@dataclass
class ReviewState:
    state: MasteryState
    times_seen: int
    correct_count: int
    wrong_count: int
    interval_days: int
    mastery_score: float
    lapses: int
    next_review_at: datetime


def _next_interval(current: int) -> int:
    for value in INTERVALS:
        if value > current:
            return value
    return INTERVALS[-1]


def compute_mastery(correct: int, wrong: int) -> float:
    """Score de maitrise dans [0, 1].

    Une reponse fausse pese plus lourd qu'une bonne : on ne veut pas qu'un
    element rate soit considere comme acquis parce qu'il a ete vu souvent.
    """
    total = correct + wrong
    if total == 0:
        return 0.0
    penalised = max(0.0, correct - 1.5 * wrong)
    return round(min(1.0, penalised / total), 3)


def apply_answer(
    previous: ReviewState | None, *, is_correct: bool, now: datetime | None = None
) -> ReviewState:
    """Calcule le nouvel etat d'un element apres une reponse."""
    now = now or datetime.now(UTC)

    if previous is None:
        previous = ReviewState(
            state=MasteryState.NEW,
            times_seen=0,
            correct_count=0,
            wrong_count=0,
            interval_days=0,
            mastery_score=0.0,
            lapses=0,
            next_review_at=now,
        )

    times_seen = previous.times_seen + 1
    correct = previous.correct_count + (1 if is_correct else 0)
    wrong = previous.wrong_count + (0 if is_correct else 1)
    lapses = previous.lapses + (0 if is_correct else 1)

    if is_correct:
        interval = _next_interval(previous.interval_days)
        if correct >= MASTERY_THRESHOLD and wrong == 0:
            state = MasteryState.MASTERED
        elif previous.state in (MasteryState.NEW, MasteryState.LEARNING):
            state = MasteryState.LEARNING if correct < 2 else MasteryState.REVIEW
        else:
            state = MasteryState.REVIEW
    else:
        # Une erreur ramene l'element en revision rapprochee.
        interval = INTERVALS[0]
        state = MasteryState.WEAK

    return ReviewState(
        state=state,
        times_seen=times_seen,
        correct_count=correct,
        wrong_count=wrong,
        interval_days=interval,
        mastery_score=compute_mastery(correct, wrong),
        lapses=lapses,
        next_review_at=now + timedelta(days=interval),
    )
