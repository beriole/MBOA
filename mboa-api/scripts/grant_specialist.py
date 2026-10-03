"""Donne a un compte le role de specialiste culturel et l'habilite sur une langue.

En attendant l'espace d'administration, c'est la porte d'entree de l'espace
contributeur. Le geste est volontairement manuel : accorder le droit de publier
du contenu linguistique n'est pas une action anodine.

Usage :
    python -m scripts.grant_specialist --email ana@example.com --language bas
    python -m scripts.grant_specialist --email ana@example.com --language bas --name "Ana M."
    python -m scripts.grant_specialist --list
"""

from __future__ import annotations

import argparse
import asyncio
import sys
import uuid

from sqlalchemy import text

from app.core.db import SessionLocal, engine


async def list_contributors() -> None:
    async with SessionLocal() as db:
        rows = await db.execute(
            text(
                """
                SELECT u.email, u.display_name, u.role::text AS role,
                       c.display_name AS contributor,
                       COALESCE(string_agg(l.iso639_3, ', ' ORDER BY l.iso639_3), '-') AS langues
                FROM iam.users u
                LEFT JOIN prov.contributors c ON c.user_id = u.id
                LEFT JOIN prov.validation_assignments a
                       ON a.contributor_id = c.id AND a.is_active
                LEFT JOIN ref.languages l ON l.id = a.language_id
                GROUP BY u.email, u.display_name, u.role, c.display_name
                ORDER BY u.role, u.email
                """
            )
        )
        print(f"\n{'e-mail':<34}{'role':<22}{'contributeur':<28}langues")
        print("-" * 96)
        for r in rows:
            print(
                f"{r.email:<34}{r.role:<22}{(r.contributor or '-'):<28}{r.langues}"
            )
        print()
    await engine.dispose()


async def grant(email: str, iso: str, display_name: str | None) -> int:
    async with SessionLocal() as db:
        user = (
            await db.execute(
                text("SELECT id, display_name FROM iam.users WHERE email = :e"),
                {"e": email.lower()},
            )
        ).one_or_none()
        if user is None:
            print(f"[erreur] aucun compte avec l'e-mail {email}")
            return 1

        language = (
            await db.execute(
                text("SELECT id, name FROM ref.languages WHERE iso639_3 = :i"),
                {"i": iso},
            )
        ).one_or_none()
        if language is None:
            print(f"[erreur] aucune langue avec le code ISO {iso}")
            return 1

        await db.execute(
            text("UPDATE iam.users SET role = 'CULTURAL_SPECIALIST' WHERE id = :id"),
            {"id": user.id},
        )

        contributor = (
            await db.execute(
                text("SELECT id FROM prov.contributors WHERE user_id = :uid"),
                {"uid": user.id},
            )
        ).scalar_one_or_none()

        if contributor is None:
            contributor = uuid.uuid4()
            await db.execute(
                text(
                    """
                    INSERT INTO prov.contributors (id, user_id, display_name, role)
                    VALUES (:id, :uid, :name, 'NATIVE_SPEAKER')
                    """
                ),
                {
                    "id": contributor,
                    "uid": user.id,
                    "name": display_name or user.display_name,
                },
            )
            created = True
        else:
            created = False

        await db.execute(
            text(
                """
                INSERT INTO prov.validation_assignments
                    (id, contributor_id, language_id, scope, is_active)
                VALUES (:id, :cid, :lang, ARRAY['LEXICON','AUDIO','EXERCISE'], true)
                ON CONFLICT (contributor_id, language_id)
                DO UPDATE SET is_active = true
                """
            ),
            {"id": uuid.uuid4(), "cid": contributor, "lang": language.id},
        )
        await db.commit()

        print(f"[ok] {email}")
        print(f"     role        : CULTURAL_SPECIALIST")
        print(f"     contributeur: {'cree' if created else 'existant'} ({contributor})")
        print(f"     habilitation: {language.name} [{iso}]")

    await engine.dispose()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--email", help="compte a promouvoir")
    parser.add_argument("--language", help="code ISO 639-3 de la langue, ex. bas")
    parser.add_argument("--name", help="nom affiche du contributeur")
    parser.add_argument("--list", action="store_true", help="liste les comptes et habilitations")
    args = parser.parse_args()

    if args.list:
        asyncio.run(list_contributors())
        return 0
    if not args.email or not args.language:
        parser.error("--email et --language sont requis")
    return asyncio.run(grant(args.email, args.language, args.name))


if __name__ == "__main__":
    sys.exit(main())
