"""Tests du generateur d'exercices et des correcteurs serveur (SS12, SS13, SS19)."""

import random

import pytest

from app.modules.exercises.checker import check_answer
from app.modules.exercises.generator import (
    CorpusWord,
    GenerationError,
    build_lesson_exercises,
    generate_listen_and_choose,
    generate_multiple_choice,
)
from app.shared.enums import ExerciseType


def _words(n: int, *, gloss: bool = False, audio: bool = True) -> list[CorpusWord]:
    """Entrees techniques neutres : on teste la mecanique, pas du contenu linguistique."""
    return [
        CorpusWord(
            id=f"id-{i}",
            lemma=f"forme-{i}",
            meaning_fr=f"glose-{i}" if gloss else None,
            audio_url=f"https://example.org/{i}.wav" if audio else None,
        )
        for i in range(n)
    ]


# --------------------------------------------------------------------------- generateur
def test_distracteurs_issus_du_corpus_uniquement():
    words = _words(6)
    ex = generate_listen_and_choose(words[0], words, rng=random.Random(1))
    corpus_ids = {w.id for w in words}
    assert {c["id"] for c in ex.payload["choices"]} <= corpus_ids
    assert len(ex.payload["choices"]) == 4
    assert ex.answer_spec == {"correct_id": "id-0"}


def test_la_reponse_n_est_jamais_dans_le_payload():
    for ex in build_lesson_exercises(_words(6)):
        assert "correct_id" not in ex.payload
        assert "answer_spec" not in ex.payload


def test_generated_from_trace_tous_les_choix():
    words = _words(6)
    ex = generate_listen_and_choose(words[0], words, rng=random.Random(2))
    assert {g["id"] for g in ex.generated_from} == {c["id"] for c in ex.payload["choices"]}


def test_pas_d_exercice_de_sens_sans_glose_validee():
    """Sans glose, MBOA ne fabrique pas de traduction : l'exercice est refuse."""
    words = _words(6, gloss=False)
    with pytest.raises(GenerationError):
        generate_multiple_choice(words[0], words, rng=random.Random(3))

    types = {ex.type for ex in build_lesson_exercises(words)}
    assert ExerciseType.MULTIPLE_CHOICE not in types


def test_exercices_de_sens_apparaissent_avec_des_gloses():
    types = {ex.type for ex in build_lesson_exercises(_words(6, gloss=True))}
    assert ExerciseType.MULTIPLE_CHOICE in types


def test_corpus_insuffisant_refuse():
    with pytest.raises(GenerationError):
        generate_listen_and_choose(_words(2)[0], _words(2), rng=random.Random(4))


def test_pas_d_ecoute_sans_audio():
    words = _words(6, audio=False)
    with pytest.raises(GenerationError):
        generate_listen_and_choose(words[0], words, rng=random.Random(5))


# --------------------------------------------------------------------------- correcteurs
def test_choix_unique():
    spec = {"correct_id": "a"}
    assert check_answer(ExerciseType.LISTEN_AND_CHOOSE, {"choice_id": "a"}, spec).is_correct
    assert not check_answer(ExerciseType.LISTEN_AND_CHOOSE, {"choice_id": "b"}, spec).is_correct
    assert not check_answer(ExerciseType.LISTEN_AND_CHOOSE, {}, spec).is_correct


def test_memory_game_exige_toutes_les_paires():
    spec = {"pairs": ["a", "b", "c"]}
    assert check_answer(ExerciseType.MEMORY_GAME, {"matched_ids": ["c", "a", "b"]}, spec).is_correct
    result = check_answer(ExerciseType.MEMORY_GAME, {"matched_ids": ["a"]}, spec)
    assert not result.is_correct
    assert result.detail == "1/3 paires trouvees"


def test_saisie_normalisee_nfc_et_casse():
    spec = {"correct_text": "été"}  # forme precomposee
    nfd = "Été"  # meme texte, decompose, en majuscule
    assert check_answer(ExerciseType.LISTEN_AND_TYPE, {"text": nfd}, spec).is_correct


def test_tolerance_aux_tons_reglable():
    strict = {"correct_text": "àbá", "tolerate_tones": False}
    tolerant = {**strict, "tolerate_tones": True}
    assert not check_answer(ExerciseType.LISTEN_AND_TYPE, {"text": "aba"}, strict).is_correct
    assert check_answer(ExerciseType.LISTEN_AND_TYPE, {"text": "aba"}, tolerant).is_correct


def test_speak_ne_calcule_aucun_score_artificiel():
    """SS19 : pas de 'Prononciation 92 %' sans modele fiable."""
    result = check_answer(ExerciseType.SPEAK, {}, {"reference_audio_url": "x"})
    assert result.is_correct
    assert "Aucun score" in result.detail


def test_ordre_des_mots():
    spec = {"correct_order": ["t1", "t2", "t3"]}
    assert check_answer(ExerciseType.ORDER_WORDS, {"order": ["t1", "t2", "t3"]}, spec).is_correct
    assert not check_answer(ExerciseType.ORDER_WORDS, {"order": ["t2", "t1", "t3"]}, spec).is_correct


def test_tous_les_types_ont_un_correcteur():
    from app.modules.exercises.checker import CHECKERS

    assert set(CHECKERS) == set(ExerciseType)
