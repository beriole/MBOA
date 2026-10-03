"""Tests de la repetition espacee (SS14).

Exigence du cahier des charges : "Une erreur ne doit pas disparaitre apres la
fin d'une lecon." et "Les elements faibles doivent reapparaitre."
"""

from datetime import UTC, datetime, timedelta

from app.modules.review.srs import (
    INTERVALS,
    MASTERY_THRESHOLD,
    apply_answer,
    compute_mastery,
)
from app.shared.enums import MasteryState

NOW = datetime(2026, 9, 18, 10, 0, tzinfo=UTC)


def test_premiere_bonne_reponse_passe_en_apprentissage():
    state = apply_answer(None, is_correct=True, now=NOW)
    assert state.state is MasteryState.LEARNING
    assert state.times_seen == 1
    assert state.correct_count == 1
    assert state.interval_days == INTERVALS[0]
    assert state.next_review_at == NOW + timedelta(days=1)


def test_premiere_erreur_passe_en_faible():
    state = apply_answer(None, is_correct=False, now=NOW)
    assert state.state is MasteryState.WEAK
    assert state.wrong_count == 1
    assert state.lapses == 1
    #: L'element revient des le lendemain : il ne disparait pas.
    assert state.next_review_at == NOW + timedelta(days=1)


def test_les_intervalles_s_allongent_avec_les_succes():
    state = None
    observed = []
    for _ in range(6):
        state = apply_answer(state, is_correct=True, now=NOW)
        observed.append(state.interval_days)

    assert observed == [1, 3, 7, 14, 30, 30], observed
    assert observed == sorted(observed), "les intervalles ne doivent jamais reculer"


def test_une_erreur_annule_la_progression_des_intervalles():
    state = None
    for _ in range(4):
        state = apply_answer(state, is_correct=True, now=NOW)
    assert state.interval_days == 14

    state = apply_answer(state, is_correct=False, now=NOW)
    assert state.state is MasteryState.WEAK
    assert state.interval_days == 1, "apres une erreur, l'element revient le lendemain"


def test_maitrise_apres_plusieurs_succes_sans_erreur():
    state = None
    for _ in range(MASTERY_THRESHOLD):
        state = apply_answer(state, is_correct=True, now=NOW)
    assert state.state is MasteryState.MASTERED
    assert state.mastery_score == 1.0


def test_un_element_deja_rate_ne_devient_pas_maitrise_trop_vite():
    """Un element rate une fois doit etre reconquis, pas simplement revu."""
    state = apply_answer(None, is_correct=False, now=NOW)
    for _ in range(MASTERY_THRESHOLD):
        state = apply_answer(state, is_correct=True, now=NOW)

    assert state.state is not MasteryState.MASTERED
    assert state.wrong_count == 1


def test_score_de_maitrise_penalise_les_erreurs():
    assert compute_mastery(0, 0) == 0.0
    assert compute_mastery(5, 0) == 1.0
    #: 3 bonnes et 2 mauvaises : penalisation, donc score faible.
    assert compute_mastery(3, 2) == 0.0
    assert 0.0 < compute_mastery(9, 1) < 1.0
