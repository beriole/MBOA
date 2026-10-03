"""Rendu PDF d'une attestation de parcours.

Deux exigences tiennent ce fichier :

1. **Dire la verite et rien de plus.** L'attestation enonce ce qui a ete fait -
   des lecons terminees, un score, des dates - et porte, au meme corps que le
   reste, la phrase qui dit ce qu'elle n'atteste pas. Une attestation dont les
   limites sont ecrites en petit est une attestation qui trompe.

2. **Ecrire les langues correctement.** Les polices integrees a PDF ne couvrent
   pas l'alphabet general des langues camerounaises. On embarque donc Inter,
   dont la couverture de ɓ ɛ ɔ ŋ ǝ et des tons a ete verifiee. Sans cela, un
   nom de langue s'imprimerait avec des carres vides.
"""

from __future__ import annotations

import io
from datetime import datetime
from pathlib import Path

from reportlab.lib.colors import Color
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

FONT_PATH = Path(__file__).resolve().parents[2] / "assets" / "fonts" / "Inter-Variable.ttf"
FONT_NAME = "MboaInter"

#: Jetons du design system (livrable K), convertis pour reportlab.
FOREST_900 = Color(0x0F / 255, 0x3D / 255, 0x2E / 255)
FOREST_500 = Color(0x1B / 255, 0x7A / 255, 0x57 / 255)
TERRE_700 = Color(0x99 / 255, 0x3A / 255, 0x22 / 255)
ENCRE_900 = Color(0x1A / 255, 0x16 / 255, 0x13 / 255)
ENCRE_500 = Color(0x6B / 255, 0x61 / 255, 0x57 / 255)
IVOIRE = Color(0xFD / 255, 0xFB / 255, 0xF6 / 255)
SABLE_600 = Color(0x9A / 255, 0x87 / 255, 0x69 / 255)

#: La phrase qui empeche l'attestation de dire plus qu'elle ne sait.
DISCLAIMER = (
    "Cette attestation certifie un parcours accompli dans l’application MBOA. "
    "Elle ne constitue pas une certification de niveau de langue : MBOA "
    "n’organise aucun examen et n’évalue pas la production orale."
)

_MONTHS = (
    "janvier", "février", "mars", "avril", "mai", "juin",
    "juillet", "août", "septembre", "octobre", "novembre", "décembre",
)


def _register_font() -> str:
    """Enregistre Inter une seule fois ; retombe sur Helvetica si le fichier manque.

    Le repli est volontairement silencieux cote rendu mais visible ici : mieux
    vaut une attestation en Helvetica qu'une erreur 500, meme si les caracteres
    speciaux y seraient perdus.
    """
    if FONT_NAME in pdfmetrics.getRegisteredFontNames():
        return FONT_NAME
    if not FONT_PATH.exists():
        return "Helvetica"
    pdfmetrics.registerFont(TTFont(FONT_NAME, str(FONT_PATH)))
    return FONT_NAME


def french_date(value: datetime) -> str:
    return f"{value.day} {_MONTHS[value.month - 1]} {value.year}"


def _wrap(text: str, font: str, size: float, width: float) -> list[str]:
    """Decoupe un paragraphe a la largeur donnee, en points."""
    lines: list[str] = []
    current = ""
    for word in text.split():
        candidate = f"{current} {word}".strip()
        if pdfmetrics.stringWidth(candidate, font, size) <= width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def render(certificate: dict, *, verification_url: str) -> bytes:
    """Produit le PDF d'une attestation, a partir des champs figes en base."""
    font = _register_font()
    buffer = io.BytesIO()
    width, height = landscape(A4)
    pdf = canvas.Canvas(buffer, pagesize=landscape(A4))
    pdf.setTitle(f"Attestation MBOA {certificate['code']}")
    pdf.setAuthor("MBOA")
    pdf.setSubject(
        f"Parcours {certificate['section_title']} - {certificate['language_name']}"
    )

    # Fond et cadre.
    pdf.setFillColor(IVOIRE)
    pdf.rect(0, 0, width, height, stroke=0, fill=1)
    pdf.setStrokeColor(SABLE_600)
    pdf.setLineWidth(1)
    pdf.rect(12 * mm, 12 * mm, width - 24 * mm, height - 24 * mm, stroke=1, fill=0)
    pdf.setStrokeColor(FOREST_500)
    pdf.setLineWidth(3)
    pdf.line(12 * mm, height - 12 * mm, width - 12 * mm, height - 12 * mm)

    centre = width / 2

    pdf.setFont(font, 11)
    pdf.setFillColor(ENCRE_500)
    pdf.drawCentredString(centre, height - 28 * mm, "M B O A")

    pdf.setFont(font, 26)
    pdf.setFillColor(FOREST_900)
    pdf.drawCentredString(centre, height - 44 * mm, "Attestation de parcours")

    pdf.setFont(font, 12)
    pdf.setFillColor(ENCRE_500)
    pdf.drawCentredString(centre, height - 54 * mm, "délivrée à")

    pdf.setFont(font, 30)
    pdf.setFillColor(ENCRE_900)
    pdf.drawCentredString(centre, height - 72 * mm, certificate["learner_name"])

    pdf.setFont(font, 12)
    pdf.setFillColor(ENCRE_500)
    pdf.drawCentredString(centre, height - 86 * mm, "pour avoir terminé")

    pdf.setFont(font, 18)
    pdf.setFillColor(FOREST_900)
    pdf.drawCentredString(centre, height - 99 * mm, certificate["section_title"])

    pdf.setFont(font, 13)
    pdf.setFillColor(ENCRE_900)
    pdf.drawCentredString(
        centre,
        height - 110 * mm,
        f"{certificate['course_title']}  ·  {certificate['language_name']} "
        f"({certificate['language_iso']})",
    )

    # Les chiffres, sans arrondi flatteur.
    score = round(certificate["average_score"] * 100)
    done = certificate["lessons_completed"]
    answered = certificate["exercises_answered"]
    faits = (
        f"{done} leçon{'s' if done > 1 else ''} sur {certificate['lessons_total']}   ·   "
        f"{answered} réponse{'s' if answered > 1 else ''} d’exercices   ·   "
        f"score moyen {score} %"
    )
    pdf.setFont(font, 12)
    pdf.setFillColor(TERRE_700)
    pdf.drawCentredString(centre, height - 124 * mm, faits)

    completed = certificate["completed_at"]
    pdf.setFont(font, 11)
    pdf.setFillColor(ENCRE_500)
    pdf.drawCentredString(
        centre, height - 134 * mm, f"Parcours achevé le {french_date(completed)}"
    )

    # Ce que l'attestation n'atteste pas, au meme corps que le reste.
    pdf.setFont(font, 10)
    pdf.setFillColor(ENCRE_500)
    y = 44 * mm
    for line in _wrap(DISCLAIMER, font, 10, width - 70 * mm):
        pdf.drawCentredString(centre, y, line)
        y -= 5 * mm

    # Verification.
    pdf.setFont(font, 12)
    pdf.setFillColor(ENCRE_900)
    pdf.drawCentredString(centre, 28 * mm, certificate["code"])
    pdf.setFont(font, 9)
    pdf.setFillColor(ENCRE_500)
    pdf.drawCentredString(
        centre, 22 * mm, f"Vérifiable sur {verification_url}"
    )

    pdf.showPage()
    pdf.save()
    return buffer.getvalue()
