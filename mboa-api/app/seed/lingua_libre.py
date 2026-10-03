"""Classification des enregistrements Lingua Libre basaa recuperes sur Wikimedia Commons.

Categorie : https://commons.wikimedia.org/wiki/Category:Lingua_Libre_pronunciation-bas
Licence   : CC BY-SA 4.0, attribution du locuteur obligatoire.
Consulte  : 2026-09-18.

IMPORTANT - constat de qualite des donnees
-------------------------------------------
Les 123 fichiers proviennent de deux contributeurs aux conventions differentes :

* `Misnograder` (105 fichiers) : les etiquettes sont des mots FRANCAIS
  (Amer, Ananas, Antilope...). La convention Lingua Libre veut que l'etiquette
  soit la transcription dans la langue enregistree. Impossible de trancher sans
  ecoute par un locuteur natif : ces fichiers sont importes au statut TO_VERIFY
  et ne sont JAMAIS promus automatiquement.

* `Bile rene` (18 fichiers) : contient de vraies formes basaa, dont plusieurs
  portent les caracteres specifiques de l'orthographe (ɓ, ɛ, ŋ) et les
  diacritiques tonales. La forme `ɓasaá` correspond a la transcription donnee
  par Hyman 2003 pour l'autonyme de la langue.

Aucune signification n'est attribuee ici : MBOA n'invente pas de traduction.
Les gloses francaises restent NULL jusqu'a saisie par un locuteur natif.
"""

#: Formes basaa exploitables, relevees dans les fichiers de `Bile rene`.
#: Ce sont les etiquettes telles qu'ecrites par le contributeur, sans aucune
#: interpretation de notre part.
BASAA_FORMS: tuple[str, ...] = (
    "ɓasaá",
    "màlep",
    "mààŋgɛ",
    "bìjɛk",
    "bidjèck",
    "litowa",
    "mitoumba",
    "mbombo",
    "ngweha",
    "soulouk",
    "manguè",
    "ndi laa",
    "mbongo tchobi",
)

#: Etiquettes francaises presentes dans le meme lot : ce sont des amorces de
#: consigne, pas des formes basaa. Elles ne sont pas importees comme lexique.
FRENCH_PROMPTS: tuple[str, ...] = (
    "Bonjour",
    "Bonne nuit",
    "C'est comment?",
    "Comment vas-tu?",
    "Que se passe t-il?",
)

#: Paires d'ecritures qui semblent designer la meme unite dans deux graphies
#: differentes. A confirmer par un locuteur natif : signale, jamais fusionne
#: automatiquement.
ORTHOGRAPHY_VARIANTS_TO_REVIEW: tuple[tuple[str, str], ...] = (
    ("bìjɛk", "bidjèck"),
    ("mààŋgɛ", "manguè"),
)

#: Locuteurs, pour l'attribution exigee par CC BY-SA.
SPEAKERS: dict[str, dict[str, str]] = {
    "Bile rene": {
        "display_code": "BAS-LL-01",
        "lingualibre_id": "Q590173",
        "profile": "https://lingualibre.org/wiki/Q590173",
    },
    "Misnograder": {
        "display_code": "BAS-LL-02",
        "lingualibre_id": "Q57074",
        "profile": "https://lingualibre.org/wiki/Q57074",
    },
}

COMMONS_CATEGORY_URL = (
    "https://commons.wikimedia.org/wiki/Category:Lingua_Libre_pronunciation-bas"
)
LICENSE_URL = "https://creativecommons.org/licenses/by-sa/4.0/"


def attribution_for(speaker: str) -> str:
    """Mention d'attribution affichee dans l'application (exigence CC BY-SA)."""
    meta = SPEAKERS.get(speaker, {})
    profile = meta.get("profile", "lingualibre.org")
    return f"{speaker} (Lingua Libre, {profile}) - CC BY-SA 4.0"
