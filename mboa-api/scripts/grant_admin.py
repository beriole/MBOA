"""Donne a un compte le role d'administrateur.

Le premier administrateur ne peut pas etre cree depuis la console : il faut bien
que quelqu'un ouvre la porte. Ce script est cette porte, et il est volontairement
en ligne de commande, sur la machine qui heberge la base.

L'acte est inscrit au journal comme n'importe quel autre, avec son motif et la
mention qu'il vient de la ligne de commande : le journal doit pouvoir expliquer
d'ou vient chaque administrateur.

Usage :
    python -m scripts.grant_admin --email ana@example.com --reason "Porteuse du projet"
    python -m scripts.grant_admin --list
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
import uuid

from sqlalchemy import text

from app.core.db import SessionLocal, engine


async def list_admins() -> None:
    async with SessionLocal() as db:
        rows = await db.execute(
            text(
                """
                SELECT email, display_name, is_active, last_login_at
                FROM iam.users WHERE role = 'ADMIN' ORDER BY email
                """
            )
        )
        found = list(rows)
        if not found:
            print("\nAucun administrateur. Utilisez --email pour en designer un.\n")
            return
        print(f"\n{'e-mail':<36}{'nom':<26}{'actif':<8}derniere connexion")
        print("-" * 92)
        for r in found:
            print(
                f"{r.email:<36}{r.display_name:<26}"
                f"{('oui' if r.is_active else 'NON'):<8}{r.last_login_at or '-'}"
            )
        print()
    await engine.dispose()


async def grant(email: str, reason: str) -> int:
    async with SessionLocal() as db:
        user = (
            await db.execute(
                text("SELECT id, display_name, role::text AS role FROM iam.users WHERE email = :e"),
                {"e": email.lower()},
            )
        ).one_or_none()
        if user is None:
            print(f"[erreur] aucun compte avec l'e-mail {email}")
            return 1
        if user.role == "ADMIN":
            print(f"[info] {email} est deja administrateur.")
            return 0

        await db.execute(
            text("UPDATE iam.users SET role = 'ADMIN' WHERE id = :id"), {"id": user.id}
        )
        await db.execute(
            text(
                """
                INSERT INTO admin.audit_log
                    (id, actor_user_id, actor_label, action, target_type, target_id,
                     target_label, reason, details)
                VALUES (:id, NULL, 'ligne de commande (scripts.grant_admin)',
                        'USER_ROLE_CHANGED', 'USER', :target, :label, :reason,
                        CAST(:details AS jsonb))
                """
            ),
            {
                "id": uuid.uuid4(),
                "target": user.id,
                "label": email.lower(),
                "reason": reason,
                "details": json.dumps({"avant": user.role, "apres": "ADMIN"}),
            },
        )
        await db.commit()
        print(f"[ok] {email} est administrateur.")
        print(f"     motif inscrit au journal : {reason}")

    await engine.dispose()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--email", help="compte a promouvoir")
    parser.add_argument(
        "--reason",
        help="motif, inscrit au journal (5 caracteres minimum)",
    )
    parser.add_argument("--list", action="store_true", help="liste les administrateurs")
    args = parser.parse_args()

    if args.list:
        asyncio.run(list_admins())
        return 0
    if not args.email or not args.reason:
        parser.error("--email et --reason sont requis")
    if len(args.reason.strip()) < 5:
        parser.error("le motif doit etre explicite (5 caracteres minimum)")
    return asyncio.run(grant(args.email, args.reason.strip()))


if __name__ == "__main__":
    sys.exit(main())
