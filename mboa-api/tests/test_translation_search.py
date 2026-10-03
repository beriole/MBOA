"""Tests des fonctions pures de la recherche lexicale."""

from app.modules.translation import service


def test_retrait_des_tons():
    assert service.strip_tones("màlep") == "malep"
    assert service.strip_tones("mààŋgɛ") == "maaŋgɛ"
    # Les lettres propres a l'alphabet camerounais ne sont pas des diacritiques
    # combinantes : elles sont conservees telles quelles.
    assert service.strip_tones("ɓasaá") == "ɓasaa"
    assert service.strip_tones("bìjɛk") == "bijɛk"


def test_normalisation_nfc():
    assert service.normalize("  élep  ") == "élep"
    assert service.normalize("") == ""


def test_seuil_de_similarite_documente():
    """Sous ce seuil, une suggestion serait plus trompeuse qu'utile."""
    assert 0 < service.SIMILARITY_THRESHOLD < 0.5


def test_confiance_decroissante_selon_le_type():
    from app.modules.translation.service import CONFIDENCE, MatchKind

    assert CONFIDENCE[MatchKind.EXACT] > CONFIDENCE[MatchKind.TONELESS]


def test_repli_des_lettres_de_l_alphabet():
    """Personne ne tape ɓ, ɛ, ɔ ou ŋ sur un clavier de telephone."""
    assert service.fold_alphabet("ɓasaá") == "basaa"
    assert service.fold_alphabet("bìjɛk") == "bijek"
    assert service.fold_alphabet("màlep") == "malep"


def test_le_groupe_prenasalise_ng_ne_double_pas_le_g():
    """« ŋg » se tape « ng » : le repli ne doit pas produire « ngg »."""
    assert service.fold_alphabet("mààŋgɛ") == "maange"
    # Un ŋ isole devient bien « ng ».
    assert service.fold_alphabet("ngɔŋ") == "ngong"


def test_le_repli_ne_touche_jamais_la_forme_stockee():
    """C'est une aide a la recherche, pas une reecriture du corpus."""
    forme = "ɓasaá"
    assert service.normalize(forme) == forme
    assert service.fold_alphabet(forme) != forme
