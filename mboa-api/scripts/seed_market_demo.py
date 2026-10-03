"""Cree des boutiques et des objets de **demonstration** dans la place de marche.

**Pourquoi.** Le catalogue comptait une boutique et un objet. On ne peut pas
juger une grille de place de marche, une recherche ni des filtres sur si peu : il
faut du volume pour voir si la mise en page tient.

**Ou est la limite.** Un artisan est une personne, et un objet artisanal porte
souvent une affirmation culturelle — « masque de danse », « pagne ndop ». Inventer
l'un ou l'autre en silence serait exactement ce que la regle fondatrice interdit.
Ce script s'y tient de quatre facons :

1. **Tout est marque.** Boutiques et comptes portent `is_demo`, et le drapeau
   voyage jusqu'a l'ecran : la carte d'un objet de demonstration le dit.
2. **Aucune affirmation culturelle.** `cultural_claim_fr` reste nul sur tous les
   objets. Les titres decrivent une matiere et une forme — « panier en raphia,
   grand format » — jamais une origine, un peuple ni un usage rituel.
3. **Aucun nom de personne.** Les boutiques portent des noms d'atelier, pas des
   noms d'artisans qui n'existent pas.
4. **Effacable d'une commande.** `--purge` retire tout ce que ce script a cree,
   sans toucher a ce qui est reel.

Les photographies viennent de la mediatheque Commons, deja rapatriee avec auteur
et licence : ce sont de vraies images d'artisanat camerounais, creditees. Elles
illustrent un objet de demonstration, et l'ecran ne pretend pas qu'elles
montrent l'objet vendu.

Usage :
    python -m scripts.seed_market_demo
    python -m scripts.seed_market_demo --purge
"""

from __future__ import annotations

import argparse
import asyncio
import random
import sys
import uuid

from sqlalchemy import text

from app.core.db import SessionLocal, engine
from app.core.security import hash_password

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

#: Marqueur des comptes de demonstration : il rend la purge sure.
DOMAINE_DEMO = "demo.mboa.invalid"

#: Les ateliers. Nom, ville, region, et ce qu'ils travaillent.
#: Aucun nom de personne : ce sont des ateliers, pas des artisans inventes.
ATELIERS: list[tuple[str, str, str, str, tuple[str, ...]]] = [
    (
        "Atelier du raphia",
        "Edéa",
        "LT",
        "Vannerie tressée à la main : paniers, corbeilles, nattes.",
        ("VANNERIE",),
    ),
    (
        "Terre de Foumban",
        "Foumban",
        "OU",
        "Poterie tournée et cuite au four traditionnel.",
        ("POTERIE",),
    ),
    (
        "Tissage de Maroua",
        "Maroua",
        "EN",
        "Tissage de coton et teintures végétales.",
        ("TEXTILE",),
    ),
    (
        "Bois de Bafoussam",
        "Bafoussam",
        "OU",
        "Sculpture sur bois : tabourets, plateaux, statuettes.",
        ("SCULPTURE",),
    ),
    (
        "Perles de Douala",
        "Douala",
        "LT",
        "Bijoux en perles, graines et laiton.",
        ("BIJOUX",),
    ),
    (
        "Percussions du Mungo",
        "Nkongsamba",
        "LT",
        "Tambours, balafons et hochets, montés à la main.",
        ("INSTRUMENT",),
    ),
    (
        "Saveurs de Kribi",
        "Kribi",
        "SU",
        "Épices, poivres et préparations séchées.",
        ("GASTRONOMIE",),
    ),
    (
        "Couleurs de Bamenda",
        "Bamenda",
        "NW",
        "Peinture sur toile et sur tissu.",
        ("PEINTURE",),
    ),
]

#: Les objets, par categorie. Chaque entree : (titre, description, prix, stock).
#: Les titres decrivent une matiere et une forme. Aucun ne dit « traditionnel »,
#: « rituel », ni n'attribue l'objet a un peuple : ce seraient des affirmations.
OBJETS: dict[str, list[tuple[str, str, int, int]]] = {
    "VANNERIE": [
        ("Panier en raphia, grand format", "Environ 40 cm de diamètre, anses tressées.", 12000, 4),
        ("Corbeille à pain en raphia", "Environ 22 cm, fond plat.", 5500, 9),
        ("Natte tressée, deux places", "Environ 180 × 120 cm, bords cousus.", 18000, 3),
        ("Panier de marché à couvercle", "Environ 35 cm, couvercle emboîtant.", 14500, 2),
        ("Set de trois corbeilles gigognes", "Trois tailles, 15 à 28 cm.", 21000, 2),
    ],
    "POTERIE": [
        ("Jarre à eau, 5 litres", "Terre cuite non émaillée, col étroit.", 16000, 3),
        ("Plat à service, 30 cm", "Terre cuite, intérieur lissé.", 9000, 6),
        ("Pot à épices avec couvercle", "Environ 12 cm de haut.", 4500, 12),
        ("Brûle-encens en terre cuite", "Environ 10 cm, ajouré.", 3800, 8),
        ("Ensemble de quatre bols", "Environ 13 cm chacun.", 11000, 4),
    ],
    "TEXTILE": [
        ("Pagne tissé, coton écru", "Environ 180 × 110 cm, tissé à la main.", 22000, 3),
        ("Écharpe en coton teint à l'indigo", "Environ 180 × 45 cm.", 8500, 7),
        ("Coussin en coton tissé", "Housse 45 × 45 cm, sans garnissage.", 6000, 10),
        ("Chemin de table tissé", "Environ 140 × 40 cm.", 7500, 5),
    ],
    "SCULPTURE": [
        ("Tabouret bas en bois d'iroko", "Environ 30 cm de haut, monobloc.", 28000, 2),
        ("Plateau de service en bois", "Environ 45 × 30 cm, bords relevés.", 13000, 4),
        ("Statuette en ébène, 25 cm", "Bois sombre, poli à la main.", 19000, 3),
        ("Mortier et pilon en bois", "Mortier 20 cm, pilon 30 cm.", 10500, 5),
        ("Porte-encens sculpté", "Environ 18 cm.", 4200, 9),
    ],
    "BIJOUX": [
        ("Collier de perles de verre", "Longueur réglable, fermoir laiton.", 7500, 8),
        ("Bracelet en laiton martelé", "Diamètre réglable.", 5200, 14),
        ("Boucles d'oreilles en graines", "Environ 4 cm, montage acier.", 3500, 20),
        ("Parure collier et bracelet", "Perles assorties.", 12500, 4),
    ],
    "INSTRUMENT": [
        ("Tambour à peau tendue, 30 cm", "Fût en bois, peau lacée.", 32000, 2),
        ("Balafon à onze lames", "Lames en bois, caisses en calebasse.", 65000, 1),
        ("Hochet en calebasse", "Environ 20 cm, graines sèches.", 4800, 11),
        ("Sanza à huit lames", "Planche en bois, lames en acier.", 15000, 3),
    ],
    "GASTRONOMIE": [
        ("Poivre de Penja, 100 g", "Grains entiers, sachet refermable.", 4500, 25),
        ("Mélange d'épices pour sauce, 80 g", "Composition indiquée au dos.", 3200, 30),
        ("Gingembre séché en lamelles, 120 g", "Sachet kraft.", 2800, 18),
        ("Miel de forêt, 500 g", "Pot en verre, récolte de l'année.", 6500, 9),
    ],
    "PEINTURE": [
        ("Toile acrylique, 60 × 40 cm", "Châssis en bois, signée au dos.", 45000, 1),
        ("Aquarelle encadrée, 30 × 24 cm", "Cadre bois, sous verre.", 22000, 2),
        ("Tissu peint à la main, 100 × 70 cm", "Pigments sur coton.", 18000, 3),
    ],
}


async def purger(db) -> None:
    """Retire tout ce que ce script a cree, et rien d'autre."""
    comptes = [
        r[0]
        for r in await db.execute(
            text("SELECT id FROM iam.users WHERE email LIKE :motif"),
            {"motif": f"%@{DOMAINE_DEMO}"},
        )
    ]
    if not comptes:
        print("[MBOA] rien a purger.")
        return

    boutiques = [
        r[0]
        for r in await db.execute(
            text("SELECT id FROM market.shops WHERE owner_user_id = ANY(:u) AND is_demo"),
            {"u": comptes},
        )
    ]
    # Une commande reelle sur un objet de demonstration empecherait la purge :
    # on la signale plutot que de la contourner.
    if boutiques:
        commandes = (
            await db.execute(
                text("SELECT count(*) FROM market.orders WHERE shop_id = ANY(:s)"),
                {"s": boutiques},
            )
        ).scalar_one()
        if commandes:
            print(
                f"[MBOA] {commandes} commande(s) portent sur ces boutiques. "
                "Elles seront supprimees avec elles."
            )
            await db.execute(
                text("DELETE FROM market.orders WHERE shop_id = ANY(:s)"), {"s": boutiques}
            )

    await db.execute(text("DELETE FROM iam.users WHERE id = ANY(:u)"), {"u": comptes})
    await db.commit()
    print(f"[MBOA] purge : {len(boutiques)} boutique(s), {len(comptes)} compte(s).")


async def semer(db) -> None:
    regions = {
        r.code: r.id for r in await db.execute(text("SELECT code, id FROM ref.regions"))
    }
    if not regions:
        print("[MBOA] le referentiel des regions est vide : lancez d'abord seed_culture.")
        return

    # Les photographies de la mediatheque, par theme. Elles sont reelles et
    # creditees ; elles illustrent, elles ne representent pas l'objet vendu.
    photos: dict[str, list[str]] = {}
    for row in await db.execute(
        text(
            """
            SELECT theme, file_key FROM culture.media_library
            WHERE kind = 'IMAGE' ORDER BY random()
            """
        )
    ):
        photos.setdefault(row.theme, []).append(row.file_key)

    #: Quelle famille de photos illustre quelle categorie d'objet.
    illustration = {
        "VANNERIE": "artisanat",
        "POTERIE": "artisanat",
        "TEXTILE": "artisanat",
        "SCULPTURE": "sculpture",
        "BIJOUX": "artisanat",
        "INSTRUMENT": "musique",
        "GASTRONOMIE": "cuisine",
        "PEINTURE": "sculpture",
    }

    alea = random.Random(20260926)
    boutiques = produits = images = 0

    for index, (nom, ville, region, description, categories) in enumerate(ATELIERS):
        user_id = uuid.uuid4()
        await db.execute(
            text(
                """
                INSERT INTO iam.users
                    (id, email, password_hash, display_name, role, locale, timezone)
                VALUES (:id, :email, :hash, :nom,
                        CAST('ARTISAN' AS shared.user_role), 'fr', 'Africa/Douala')
                """
            ),
            {
                "id": user_id,
                "email": f"atelier{index + 1}@{DOMAINE_DEMO}",
                "hash": hash_password(uuid.uuid4().hex),
                "nom": nom,
            },
        )

        shop_id = uuid.uuid4()
        await db.execute(
            text(
                """
                INSERT INTO market.shops
                    (id, owner_user_id, name, description_fr, region_id, city,
                     phone, status, is_demo)
                VALUES (:id, :u, :nom, :desc, :region, :ville, NULL,
                        CAST('OPEN' AS shared.shop_status), true)
                """
            ),
            {
                "id": shop_id,
                "u": user_id,
                "nom": nom,
                "desc": description,
                "region": regions.get(region),
                "ville": ville,
            },
        )
        boutiques += 1

        for categorie in categories:
            for titre, desc, prix, stock in OBJETS[categorie]:
                product_id = uuid.uuid4()
                await db.execute(
                    text(
                        """
                        INSERT INTO market.products
                            (id, shop_id, title_fr, description_fr, category,
                             price_xaf, stock, cultural_claim_fr,
                             cultural_claim_status, status)
                        VALUES (:id, :shop, :titre, :desc, :cat, :prix, :stock,
                                NULL, CAST('NONE' AS shared.cultural_claim_status),
                                CAST('PUBLISHED' AS shared.product_status))
                        """
                    ),
                    {
                        "id": product_id,
                        "shop": shop_id,
                        "titre": titre,
                        "desc": desc,
                        "cat": categorie,
                        "prix": prix,
                        "stock": stock,
                    },
                )
                produits += 1

                famille = photos.get(illustration[categorie], [])
                if famille:
                    for position in range(min(2, len(famille))):
                        cle = alea.choice(famille)
                        await db.execute(
                            text(
                                """
                                INSERT INTO market.product_images
                                    (id, product_id, file_key, caption, position)
                                VALUES (:id, :p, :cle, :legende, :pos)
                                """
                            ),
                            {
                                "id": uuid.uuid4(),
                                "p": product_id,
                                # `culture/` : la photo est servie par la
                                # mediatheque, avec son auteur et sa licence.
                                "cle": cle,
                                "legende": "Photographie d'illustration (Wikimedia "
                                "Commons) — ce n'est pas l'objet vendu",
                                "pos": position,
                            },
                        )
                        images += 1

    await db.commit()
    print(
        f"[MBOA] demonstration : {boutiques} boutique(s), {produits} objet(s), "
        f"{images} illustration(s)."
    )
    print(
        "[MBOA] toutes marquees `is_demo`. Aucune affirmation culturelle n'est "
        "portee par ces objets. Retrait : python -m scripts.seed_market_demo --purge"
    )


async def executer(purge: bool) -> int:
    async with SessionLocal() as db:
        await purger(db)
        if not purge:
            await semer(db)
    await engine.dispose()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--purge", action="store_true", help="retire la demonstration sans la recreer"
    )
    return asyncio.run(executer(parser.parse_args().purge))


if __name__ == "__main__":
    sys.exit(main())
