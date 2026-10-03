"""Application FastAPI MBOA."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.core.config import settings
from app.core.db import SessionLocal
from app.modules.admin.router import candidate_router as admin_candidate_router
from app.modules.admin.router import router as admin_router
from app.modules.audio.router import router as audio_router
from app.modules.auth.router import router as auth_router
from app.modules.certificates.router import admin_router as certificates_admin_router
from app.modules.certificates.router import public_router as certificates_public_router
from app.modules.certificates.router import router as certificates_router
from app.modules.cms.router import router as cms_router
from app.modules.culture.media import favorites_router as culture_favorites_router
from app.modules.culture.feed import router as culture_feed_router
from app.modules.culture.gallery import router as culture_gallery_router
from app.modules.culture.media import router as culture_media_router
from app.modules.culture.regions import router as culture_regions_router
from app.modules.culture.router import router as culture_router
from app.modules.culture.social import router as culture_social_router
from app.modules.onboarding.router import router as onboarding_router
from app.modules.learning.router import router as learning_router
from app.modules.market.images import public_router as market_images_router
from app.modules.market.images import router as market_product_images_router
from app.modules.market.logistics import courier_router, order_router, shop_orders_router
from app.modules.market.router import admin_router as market_admin_router
from app.modules.market.router import application_router as market_application_router
from app.modules.market.router import public_router as market_public_router
from app.modules.market.router import shop_router
from app.modules.progress.router import router as progress_router
from app.modules.translation.router import router as translation_router

app = FastAPI(
    title="MBOA API",
    version="0.1.0",
    description=(
        "Plateforme d'apprentissage des langues et du patrimoine camerounais.\n\n"
        "Principe non negociable : aucun contenu linguistique n'est publie sans "
        "source identifiee ni validation par un locuteur habilite. Ces regles sont "
        "appliquees par PostgreSQL, pas seulement par cette API."
    ),
)

# En local uniquement : l'application Flutter web tourne sur un autre port.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.environment == "local" else [],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

API_PREFIX = "/api/v1"
app.include_router(auth_router, prefix=API_PREFIX)
app.include_router(audio_router, prefix=API_PREFIX)
app.include_router(learning_router, prefix=API_PREFIX)
app.include_router(progress_router, prefix=API_PREFIX)
app.include_router(cms_router, prefix=API_PREFIX)
app.include_router(translation_router, prefix=API_PREFIX)
# Les routes nommees passent avant `/culture/{content_id}`, qui prendrait
# sinon « regions » et « quiz » pour des identifiants.
app.include_router(culture_feed_router, prefix=API_PREFIX)
app.include_router(culture_gallery_router, prefix=API_PREFIX)
app.include_router(culture_media_router, prefix=API_PREFIX)
app.include_router(culture_social_router, prefix=API_PREFIX)
app.include_router(culture_regions_router, prefix=API_PREFIX)
app.include_router(culture_favorites_router, prefix=API_PREFIX)
app.include_router(culture_router, prefix=API_PREFIX)
app.include_router(onboarding_router, prefix=API_PREFIX)
app.include_router(admin_router, prefix=API_PREFIX)
app.include_router(admin_candidate_router, prefix=API_PREFIX)
app.include_router(certificates_router, prefix=API_PREFIX)
app.include_router(certificates_public_router, prefix=API_PREFIX)
app.include_router(certificates_admin_router, prefix=API_PREFIX)
app.include_router(market_images_router, prefix=API_PREFIX)
app.include_router(market_product_images_router, prefix=API_PREFIX)
app.include_router(market_public_router, prefix=API_PREFIX)
app.include_router(market_application_router, prefix=API_PREFIX)
app.include_router(market_admin_router, prefix=API_PREFIX)
# Les commandes de la boutique passent avant la boutique elle-meme :
# /me/shop/orders ne doit pas etre capture par /me/shop.
app.include_router(shop_orders_router, prefix=API_PREFIX)
app.include_router(shop_router, prefix=API_PREFIX)
app.include_router(order_router, prefix=API_PREFIX)
app.include_router(courier_router, prefix=API_PREFIX)

if settings.environment == "local":
    from app.modules.dev.router import router as dev_router

    app.include_router(dev_router, prefix=API_PREFIX)


@app.get("/health", tags=["systeme"])
async def health() -> dict:
    """Verifie l'API et la connexion a la base."""
    async with SessionLocal() as db:
        await db.execute(text("SELECT 1"))
        counts = (
            await db.execute(
                text(
                    """
                    SELECT
                        (SELECT count(*) FROM ref.languages) AS langues,
                        (SELECT count(*) FROM corpus.vocabulary_items
                          WHERE status = 'PUBLISHED') AS mots_publies,
                        (SELECT count(*) FROM learn.exercises
                          WHERE status = 'PUBLISHED') AS exercices_publies,
                        (SELECT count(*) FROM corpus.vocabulary_items
                          WHERE status NOT IN ('PUBLISHED','REJECTED')) AS en_attente_validation
                    """
                )
            )
        ).one()

    return {
        "status": "ok",
        "environment": settings.environment,
        "database": settings.db_name,
        "contenu": dict(counts._mapping),
    }
