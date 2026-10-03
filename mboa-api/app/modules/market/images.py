"""Les photos des produits : depot, service, suppression.

Une place de marche se regarde avant de se lire. Tant qu'un produit n'a pas
d'image, une grille n'est qu'une liste de titres - c'est ce que la boutique
donnait a voir jusqu'ici.

Deux regles encadrent ce module :

1. **Aucune image n'est fournie par MBOA pour un objet reellement en vente.** Pas
   de photo de remplissage : un objet artisanal est unique, et montrer autre
   chose a sa place tromperait l'acheteur. Un produit sans photo s'affiche sans
   photo, et le dit.

   La seule exception est encadree : les boutiques de **demonstration**
   (`market.shops.is_demo`) sont illustrees par des photographies de la
   mediatheque Commons, creditees, et chaque ligne porte une legende qui dit
   que ce n'est pas l'objet vendu. La boutique elle-meme s'affiche comme une
   demonstration. Voir `scripts/seed_market_demo.py`.

2. **On verifie ce qui est depose.** Le type est lu dans les premiers octets du
   fichier, pas dans le nom ni dans l'en-tete annonce par le navigateur : les
   deux se falsifient. Un fichier qui n'est pas une image reconnue est refuse.
"""

from __future__ import annotations

import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.modules.market.router import get_shop

router = APIRouter(prefix="/shop/products", tags=["market"])
public_router = APIRouter(prefix="/market", tags=["market"])

MEDIA_ROOT = Path(__file__).resolve().parents[3] / "media"
PRODUCTS_ROOT = MEDIA_ROOT / "products"

#: Poids maximal accepte. Au-dela, c'est une photo non redimensionnee : elle
#: coute cher a servir et n'apporte rien sur une grille.
MAX_BYTES = 3 * 1024 * 1024

#: Signatures reconnues, lues dans les premiers octets. Le nom du fichier et le
#: content-type annonce ne sont pas des preuves.
SIGNATURES: list[tuple[bytes, str, str]] = [
    (b"\xff\xd8\xff", "image/jpeg", ".jpg"),
    (b"\x89PNG\r\n\x1a\n", "image/png", ".png"),
    (b"GIF87a", "image/gif", ".gif"),
    (b"GIF89a", "image/gif", ".gif"),
]

#: Le maximum de vues par produit. Au-dela, personne ne regarde.
MAX_IMAGES = 6


def sniff(donnees: bytes) -> tuple[str, str]:
    """Reconnait le format d'apres le contenu, ou refuse."""
    for signature, media_type, extension in SIGNATURES:
        if donnees.startswith(signature):
            return media_type, extension
    # WEBP : « RIFF » puis la taille, puis « WEBP ».
    if donnees[:4] == b"RIFF" and donnees[8:12] == b"WEBP":
        return "image/webp", ".webp"
    raise HTTPException(
        status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
        detail="Format non reconnu. Attendu : JPEG, PNG, GIF ou WebP.",
    )


async def _own_product(db: AsyncSession, shop_id: uuid.UUID, product_id: uuid.UUID) -> None:
    trouve = (
        await db.execute(
            text("SELECT 1 FROM market.products WHERE id = :p AND shop_id = :s"),
            {"p": product_id, "s": shop_id},
        )
    ).scalar_one_or_none()
    if trouve is None:
        raise HTTPException(
            status_code=404, detail="Produit introuvable dans votre boutique."
        )


@router.post("/{product_id}/images", status_code=status.HTTP_201_CREATED)
async def upload_image(
    product_id: uuid.UUID,
    file: UploadFile = File(...),
    shop=Depends(get_shop),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Depose une photo sur un produit de sa propre boutique."""
    await _own_product(db, shop.id, product_id)

    deja = (
        await db.execute(
            text("SELECT count(*) FROM market.product_images WHERE product_id = :p"),
            {"p": product_id},
        )
    ).scalar_one()
    if deja >= MAX_IMAGES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Ce produit a déjà {MAX_IMAGES} photos. Retirez-en une d'abord.",
        )

    donnees = await file.read()
    if not donnees:
        raise HTTPException(status_code=422, detail="Fichier vide.")
    if len(donnees) > MAX_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Photo trop lourde ({len(donnees) // 1024} Ko). "
            f"Maximum {MAX_BYTES // 1024} Ko.",
        )
    _, extension = sniff(donnees)

    dossier = PRODUCTS_ROOT / str(product_id)
    dossier.mkdir(parents=True, exist_ok=True)
    nom = f"{uuid.uuid4()}{extension}"
    (dossier / nom).write_bytes(donnees)
    cle = f"products/{product_id}/{nom}"

    row = (
        await db.execute(
            text(
                """
                INSERT INTO market.product_images (id, product_id, file_key, position)
                VALUES (gen_random_uuid(), :p, :k, :pos)
                RETURNING id
                """
            ),
            {"p": product_id, "k": cle, "pos": deja},
        )
    ).one()
    await db.commit()

    return {
        "id": str(row.id),
        "url": f"/api/v1/market/images/{cle}",
        "position": deja,
        "restantes": MAX_IMAGES - deja - 1,
    }


@router.delete("/{product_id}/images/{image_id}")
async def delete_image(
    product_id: uuid.UUID,
    image_id: uuid.UUID,
    shop=Depends(get_shop),
    db: AsyncSession = Depends(get_session),
) -> dict:
    """Retire une photo, et le fichier avec elle."""
    await _own_product(db, shop.id, product_id)

    cle = (
        await db.execute(
            text(
                "DELETE FROM market.product_images WHERE id = :i AND product_id = :p "
                "RETURNING file_key"
            ),
            {"i": image_id, "p": product_id},
        )
    ).scalar_one_or_none()
    if cle is None:
        raise HTTPException(status_code=404, detail="Photo introuvable.")
    await db.commit()

    fichier = (MEDIA_ROOT / cle).resolve()
    # On ne supprime que sous `media/products/` : une cle trafiquee en base ne
    # doit pas pouvoir faire effacer un fichier ailleurs.
    if fichier.is_relative_to(PRODUCTS_ROOT.resolve()) and fichier.is_file():
        fichier.unlink()
    return {"supprime": True}


#: Les deux dossiers d'ou une photo de produit peut venir.
#:
#: `products/` : ce que l'artisan a depose lui-meme.
#: `culture/` : une photographie de la mediatheque Commons, utilisee comme
#: illustration par les boutiques de demonstration. Elle est creditee, et la
#: legende de la ligne dit qu'elle ne montre pas l'objet vendu.
RACINES = (PRODUCTS_ROOT, MEDIA_ROOT / "culture")


@public_router.get("/images/{chemin:path}")
async def get_image(chemin: str) -> FileResponse:
    """Sert une photo de produit, deposee ou d'illustration."""
    fichier = (MEDIA_ROOT / chemin).resolve()
    autorise = any(fichier.is_relative_to(racine.resolve()) for racine in RACINES)
    if not autorise or not fichier.is_file():
        raise HTTPException(status_code=404, detail="Photo introuvable.")

    media_type, _ = sniff(fichier.read_bytes()[:16])
    return FileResponse(
        fichier,
        media_type=media_type,
        headers={"Cache-Control": "public, max-age=604800, immutable"},
    )
