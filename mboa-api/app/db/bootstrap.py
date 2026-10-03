"""Creation des schemas et des types ENUM natifs PostgreSQL.

Doit s'executer AVANT la creation des tables : les colonnes referencent ces types.
"""

from sqlalchemy import text

from app.db.models import SCHEMAS
from app.shared.enums import (
    ApplicationStatus,
    AudioQuality,
    HumanValidation,
    ContentStatus,
    CourseLevel,
    CourierVehicle,
    CulturalClaimStatus,
    CulturalCategoryCode,
    CulturalLinkPlacement,
    CulturalMediaKind,
    DeliveryStatus,
    ExerciseType,
    GrammaticalCategory,
    LessonBlockKind,
    MarketRoleRequest,
    LessonKind,
    MasteryState,
    OrderStatus,
    PaymentMode,
    ProductStatus,
    ProgressStatus,
    ReviewTargetType,
    ShopStatus,
    SourceKind,
    SourceLicense,
    TranslationMode,
    UserRole,
    ValidationDecision,
)

ENUM_TYPES: dict[str, type] = {
    "content_status": ContentStatus,
    "user_role": UserRole,
    "source_kind": SourceKind,
    "source_license": SourceLicense,
    "validation_decision": ValidationDecision,
    "grammatical_category": GrammaticalCategory,
    "exercise_type": ExerciseType,
    "lesson_kind": LessonKind,
    "lesson_block_kind": LessonBlockKind,
    "progress_status": ProgressStatus,
    "mastery_state": MasteryState,
    "course_level": CourseLevel,
    "review_target_type": ReviewTargetType,
    "audio_quality": AudioQuality,
    "translation_mode": TranslationMode,
    "human_validation": HumanValidation,
    "cultural_category_code": CulturalCategoryCode,
    "cultural_media_kind": CulturalMediaKind,
    "cultural_link_placement": CulturalLinkPlacement,
    "application_status": ApplicationStatus,
    "shop_status": ShopStatus,
    "product_status": ProductStatus,
    "cultural_claim_status": CulturalClaimStatus,
    "order_status": OrderStatus,
    "payment_mode": PaymentMode,
    "delivery_status": DeliveryStatus,
    "courier_vehicle": CourierVehicle,
    "market_role_request": MarketRoleRequest,
}


def schema_statements() -> list[str]:
    return [f'CREATE SCHEMA IF NOT EXISTS "{name}"' for name in SCHEMAS]


def enum_statements() -> list[str]:
    """Genere les CREATE TYPE, idempotents."""
    statements: list[str] = []
    for type_name, enum_cls in ENUM_TYPES.items():
        labels = ", ".join(f"'{member.value}'" for member in enum_cls)
        statements.append(
            f"""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_type t
                    JOIN pg_namespace n ON n.oid = t.typnamespace
                    WHERE t.typname = '{type_name}' AND n.nspname = 'shared'
                ) THEN
                    CREATE TYPE shared.{type_name} AS ENUM ({labels});
                END IF;
            END $$;
            """
        )
        # Un type deja cree ne suit pas l'evolution du code : sans ceci, ajouter
        # un membre a un StrEnum laisse la base en arriere, et l'erreur ne
        # remonte qu'a l'insertion. On ajoute donc les valeurs manquantes.
        for member in enum_cls:
            statements.append(
                f"ALTER TYPE shared.{type_name} ADD VALUE IF NOT EXISTS '{member.value}'"
            )
    return statements


async def bootstrap_schemas_and_types(connection) -> None:
    """Applique extensions, schemas puis types ENUM sur une connexion ouverte."""
    # pg_trgm : recherche tolerante aux fautes de frappe et aux tons oublies.
    await connection.execute(text("CREATE EXTENSION IF NOT EXISTS pg_trgm"))
    for statement in schema_statements():
        await connection.execute(text(statement))
    for statement in enum_statements():
        await connection.execute(text(statement))
