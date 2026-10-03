"""Point d'entree unique qui enregistre tous les modeles aupres de Base.metadata.

Alembic et les tests importent ce module pour connaitre l'ensemble du schema.
"""

from app.core.db import Base  # noqa: F401
from app.modules.admin.models import (  # noqa: F401
    AuditLog,
    PlatformSetting,
    SpecialistApplication,
)
from app.modules.audio.models import (  # noqa: F401
    AudioAsset,
    RecordingSession,
    Speaker,
)
from app.modules.culture.models import (  # noqa: F401
    CulturalCategory,
    CulturalContent,
    CulturalLink,
    CulturalMedia,
    Favorite,
)
from app.modules.certificates.models import Certificate  # noqa: F401
from app.modules.corpus.models import (  # noqa: F401
    ExampleSentence,
    GrammarRule,
    ImportBatch,
    RawRecord,
    VocabularyItem,
)
from app.modules.iam.models import (  # noqa: F401
    LearnerPreferences,
    RefreshToken,
    User,
)
from app.modules.languages.models import (  # noqa: F401
    Community,
    CulturalArea,
    Language,
    LanguageVariant,
    Region,
)
from app.modules.market.models import (  # noqa: F401
    CourierProfile,
    Delivery,
    MarketApplication,
    Order,
    OrderItem,
    Product,
    Shop,
)
from app.modules.learning.models import (  # noqa: F401
    ContentRelease,
    Course,
    Exercise,
    Lesson,
    LessonBlock,
    Section,
    Unit,
)
from app.modules.progress.models import (  # noqa: F401
    Achievement,
    ExerciseAttempt,
    LessonProgress,
    LessonSession,
    ReviewItem,
    Streak,
    UserAchievement,
    XpLedger,
)
from app.modules.translation.models import TranslationRequest  # noqa: F401
from app.modules.provenance.models import (  # noqa: F401
    ContentValidation,
    Contributor,
    Source,
    SourceDocument,
    SourceReference,
    ValidationAssignment,
)

#: Schemas PostgreSQL utilises par l'application.
SCHEMAS = (
    "shared",
    "iam",
    "ref",
    "prov",
    "corpus",
    "audio",
    "learn",
    "progress",
    "game",
    "translate",
    "culture",
    "admin",
    "market",
)

__all__ = ["Base", "SCHEMAS"]
