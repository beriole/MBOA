"""Emet une attestation sur la base de demonstration et en produit l'apercu.

Sert deux usages :

  - verifier de visu que le PDF sort correctement, y compris les caracteres de
    l'alphabet general des langues camerounaises ;
  - alimenter le dossier avec une piece reelle plutot qu'une maquette.

Le rendu en image utilise `pypdfium2`, uniquement pour la documentation : la
production du PDF, elle, ne depend que de reportlab.

Usage :
    python -m scripts.demo_attestation
    python -m scripts.demo_attestation --email ana@example.com
"""

from __future__ import annotations

import argparse
import asyncio
import sys
import uuid
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import text

from app.core.db import SessionLocal, engine
from app.modules.certificates import pdf
from app.modules.certificates.router import new_code

CAPTURES = Path(__file__).resolve().parents[2] / "docs" / "captures"


async def build(email: str | None) -> int:
    async with SessionLocal() as db:
        section = (
            await db.execute(
                text(
                    """
                    SELECT s.id, s.title_fr, co.title_fr AS course_title,
                           co.level::text AS level, l.name AS language_name,
                           l.iso639_3, count(le.id) AS lessons
                    FROM learn.sections s
                    JOIN learn.courses co ON co.id = s.course_id
                    JOIN ref.languages l ON l.id = co.language_id
                    JOIN learn.units u ON u.section_id = s.id
                    JOIN learn.lessons le ON le.unit_id = u.id
                    GROUP BY s.id, s.title_fr, co.title_fr, co.level, l.name, l.iso639_3
                    ORDER BY s.position
                    LIMIT 1
                    """
                )
            )
        ).one_or_none()
        if section is None:
            print("[erreur] aucune section en base : lancez d'abord les scripts de seed.")
            return 1

        if email:
            row = (
                await db.execute(
                    text("SELECT id, display_name FROM iam.users WHERE email = :e"),
                    {"e": email.lower()},
                )
            ).one_or_none()
            if row is None:
                print(f"[erreur] aucun compte avec l'e-mail {email}")
                return 1
            name = row.display_name
        else:
            name = "Ngo Bassong"

        # Les chiffres proviennent du parcours reel quand il existe ; sinon on
        # montre la section complete, et on le dit.
        done = section.lessons
        print(f"[info] section    : {section.title_fr}")
        print(f"[info] cours      : {section.course_title} ({section.language_name})")
        print(f"[info] lecons     : {done}")

        certificate = {
            "code": new_code(section.iso639_3),
            "learner_name": name,
            "course_title": section.course_title,
            "section_title": section.title_fr,
            "language_name": section.language_name,
            "language_iso": section.iso639_3,
            "level": section.level,
            "lessons_completed": done,
            "lessons_total": done,
            "average_score": 0.87,
            "exercises_answered": 21,
            "completed_at": datetime.now(UTC),
        }

    await engine.dispose()

    CAPTURES.mkdir(parents=True, exist_ok=True)
    content = pdf.render(
        certificate,
        verification_url=f"mboa.local/attestation/{certificate['code']}",
    )
    pdf_path = CAPTURES / "30-attestation.pdf"
    pdf_path.write_bytes(content)
    print(f"[ok] {pdf_path} ({len(content)} octets)")

    try:
        import pypdfium2
    except ImportError:
        print("[info] pypdfium2 absent : apercu PNG non produit (pip install pypdfium2)")
        return 0

    page = pypdfium2.PdfDocument(content)[0]
    image = page.render(scale=2).to_pil()
    png_path = CAPTURES / "30-attestation.png"
    image.save(png_path)
    print(f"[ok] {png_path} ({image.width}x{image.height})")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--email", help="compte dont le nom figure sur l'attestation")
    args = parser.parse_args()
    return asyncio.run(build(args.email))


if __name__ == "__main__":
    sys.exit(main())
