"""Enumerations partagees.

Les valeurs sont celles imposees par le cahier des charges (SS2, SS12, SS14).
Elles sont creees comme types ENUM natifs PostgreSQL afin que les contraintes
soient verifiees par la base, et pas seulement par le code Python.
"""

from enum import StrEnum


class ContentStatus(StrEnum):
    """Cycle de vie impose au SS2 du cahier des charges.

    Aucun contenu genere automatiquement ne peut passer directement a PUBLISHED :
    la transition est verrouillee par un trigger (cf. migration 0002).
    """

    DRAFT = "DRAFT"
    SOURCE_FOUND = "SOURCE_FOUND"
    TO_VERIFY = "TO_VERIFY"
    HUMAN_REVIEW = "HUMAN_REVIEW"
    VALIDATED = "VALIDATED"
    PUBLISHED = "PUBLISHED"
    REJECTED = "REJECTED"


#: Statuts a partir desquels un contenu est exploitable pedagogiquement.
USABLE_STATUSES = (ContentStatus.VALIDATED, ContentStatus.PUBLISHED)


class UserRole(StrEnum):
    LEARNER = "LEARNER"
    CULTURAL_SPECIALIST = "CULTURAL_SPECIALIST"
    ARTISAN = "ARTISAN"
    COURIER = "COURIER"
    ADMIN = "ADMIN"


class SourceKind(StrEnum):
    BOOK = "BOOK"
    ARTICLE = "ARTICLE"
    THESIS = "THESIS"
    DICTIONARY_ONLINE = "DICTIONARY_ONLINE"
    DATASET = "DATASET"
    RECORDING = "RECORDING"
    INSTITUTION = "INSTITUTION"
    ORAL_INFORMANT = "ORAL_INFORMANT"
    MBOA_ORIGINAL = "MBOA_ORIGINAL"


class SourceLicense(StrEnum):
    CC0 = "CC0"
    CC_BY = "CC_BY"
    CC_BY_SA = "CC_BY_SA"
    CC_BY_NC = "CC_BY_NC"
    NOODL = "NOODL"
    COPYRIGHT_AGREEMENT = "COPYRIGHT_AGREEMENT"
    COPYRIGHT_NO_AGREEMENT = "COPYRIGHT_NO_AGREEMENT"
    PUBLIC_DOMAIN = "PUBLIC_DOMAIN"
    UNKNOWN = "UNKNOWN"


class ValidationDecision(StrEnum):
    ACCEPT = "ACCEPT"
    REJECT = "REJECT"
    REQUEST_CHANGES = "REQUEST_CHANGES"


class GrammaticalCategory(StrEnum):
    NOUN = "NOUN"
    VERB = "VERB"
    ADJ = "ADJ"
    ADV = "ADV"
    PRON = "PRON"
    NUM = "NUM"
    PREP = "PREP"
    CONJ = "CONJ"
    INTERJ = "INTERJ"
    EXPR = "EXPR"
    OTHER = "OTHER"


class ExerciseType(StrEnum):
    """Les 15 types imposes au SS12."""

    MULTIPLE_CHOICE = "MULTIPLE_CHOICE"
    IMAGE_CHOICE = "IMAGE_CHOICE"
    WORD_MATCHING = "WORD_MATCHING"
    TRANSLATION = "TRANSLATION"
    ORDER_WORDS = "ORDER_WORDS"
    FILL_BLANK = "FILL_BLANK"
    LISTEN_AND_CHOOSE = "LISTEN_AND_CHOOSE"
    LISTEN_AND_TYPE = "LISTEN_AND_TYPE"
    SPEAK = "SPEAK"
    PRONUNCIATION = "PRONUNCIATION"
    WORD_TO_AUDIO = "WORD_TO_AUDIO"
    AUDIO_TO_WORD = "AUDIO_TO_WORD"
    TRUE_FALSE = "TRUE_FALSE"
    DIALOGUE = "DIALOGUE"
    MEMORY_GAME = "MEMORY_GAME"


class LessonKind(StrEnum):
    LESSON = "LESSON"
    REVIEW = "REVIEW"
    CHECKPOINT = "CHECKPOINT"


class LessonBlockKind(StrEnum):
    INTRO = "INTRO"
    TEACH = "TEACH"
    PRACTICE = "PRACTICE"
    CULTURE_CARD = "CULTURE_CARD"
    RECAP = "RECAP"


class ProgressStatus(StrEnum):
    LOCKED = "LOCKED"
    AVAILABLE = "AVAILABLE"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"


class MasteryState(StrEnum):
    """Etats de la repetition espacee (SS14)."""

    NEW = "NEW"
    LEARNING = "LEARNING"
    WEAK = "WEAK"
    REVIEW = "REVIEW"
    MASTERED = "MASTERED"


class CourseLevel(StrEnum):
    """Niveaux internes MBOA. Aucune correspondance CECRL n'est revendiquee (SS9)."""

    N0 = "N0"
    N1 = "N1"
    N2 = "N2"
    N3 = "N3"


class ReviewTargetType(StrEnum):
    VOCAB = "VOCAB"
    SENTENCE = "SENTENCE"
    GRAMMAR = "GRAMMAR"


class AudioQuality(StrEnum):
    REFERENCE = "REFERENCE"
    GOOD = "GOOD"
    ACCEPTABLE = "ACCEPTABLE"
    REJECTED = "REJECTED"


class TranslationMode(StrEnum):
    """Comment la traduction a ete obtenue (SS41).

    LEXICON  : recherche dans le corpus valide. Rien n'est genere.
    MODEL    : modele de traduction automatique. Pas encore disponible : aucun
               modele n'a ete entraine ni evalue pour l'ewondo ou le basaa.
    """

    LEXICON = "LEXICON"
    MODEL = "MODEL"


class HumanValidation(StrEnum):
    NONE = "NONE"
    REQUESTED = "REQUESTED"
    VALIDATED = "VALIDATED"
    CORRECTED = "CORRECTED"


class CulturalCategoryCode(StrEnum):
    """Les rubriques du Culture Hub, listees au SS20."""

    PEOPLES = "PEOPLES"
    HISTORY = "HISTORY"
    TALES = "TALES"
    PROVERBS = "PROVERBS"
    DANCES = "DANCES"
    MUSIC = "MUSIC"
    GASTRONOMY = "GASTRONOMY"
    ATTIRE = "ATTIRE"
    CRAFTS = "CRAFTS"
    RITES = "RITES"
    FESTIVALS = "FESTIVALS"
    SYMBOLS = "SYMBOLS"
    PERSONALITIES = "PERSONALITIES"
    ARCHITECTURE = "ARCHITECTURE"
    ORAL_TRADITIONS = "ORAL_TRADITIONS"
    LANGUAGE = "LANGUAGE"


class CulturalMediaKind(StrEnum):
    IMAGE = "IMAGE"
    AUDIO = "AUDIO"
    VIDEO = "VIDEO"


class CulturalLinkPlacement(StrEnum):
    """Ou la fiche apparait dans le parcours (SS21)."""

    DID_YOU_KNOW = "DID_YOU_KNOW"
    RELATED = "RELATED"
    INTRO = "INTRO"


class ApplicationStatus(StrEnum):
    """Cycle d'une demande d'habilitation de specialiste culturel (SS43)."""

    PENDING = "PENDING"
    NEEDS_INFO = "NEEDS_INFO"
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"


class ContributorRole(StrEnum):
    """Qualite declaree d'un contributeur (colonne `prov.contributors.role`)."""

    NATIVE_SPEAKER = "NATIVE_SPEAKER"
    LINGUIST = "LINGUIST"
    TEACHER = "TEACHER"
    RECORDIST = "RECORDIST"
    EDITOR = "EDITOR"


#: Perimetres d'habilitation possibles (colonne `prov.validation_assignments.scope`).
VALIDATION_SCOPES = ("LEXICON", "GRAMMAR", "AUDIO", "CULTURE", "EXERCISE")


class ShopStatus(StrEnum):
    """Cycle de vie d'une boutique d'artisan (SS45).

    Une boutique n'est visible qu'une fois son dossier accepte : le nom d'un
    artisan et son rattachement engagent la plateforme.
    """

    DRAFT = "DRAFT"
    PENDING_REVIEW = "PENDING_REVIEW"
    OPEN = "OPEN"
    SUSPENDED = "SUSPENDED"
    CLOSED = "CLOSED"


class ProductStatus(StrEnum):
    DRAFT = "DRAFT"
    PUBLISHED = "PUBLISHED"
    OUT_OF_STOCK = "OUT_OF_STOCK"
    WITHDRAWN = "WITHDRAWN"


class CulturalClaimStatus(StrEnum):
    """Statut d'une affirmation culturelle portee par une fiche produit (SS3).

    Un objet vendu comme « masque traditionnel » affirme un fait culturel. MBOA
    n'a pas le droit de le presenter comme verifie s'il ne l'est pas.
    """

    NONE = "NONE"
    ARTISAN_DECLARATION = "ARTISAN_DECLARATION"
    LINKED_TO_SOURCE = "LINKED_TO_SOURCE"


class OrderStatus(StrEnum):
    """Cycle d'une commande.

    Le circuit va jusqu'au bout **sans qu'aucun argent ne transite par MBOA** :
    le reglement se fait en especes, au livreur, a la remise. C'est le mode
    dominant au Cameroun, et c'est le seul que la plateforme puisse honnetement
    proposer tant qu'elle n'a ni entite juridique ni compte marchand.

    `PAID` existe pour nommer ce que MBOA ne sait pas faire : un trigger interdit
    d'y parvenir. Encaisser suppose un encaissement, pas un changement de statut.
    """

    DRAFT = "DRAFT"
    PENDING_CONFIRMATION = "PENDING_CONFIRMATION"
    CONFIRMED = "CONFIRMED"
    PREPARING = "PREPARING"
    READY_FOR_PICKUP = "READY_FOR_PICKUP"
    IN_DELIVERY = "IN_DELIVERY"
    DELIVERED = "DELIVERED"
    CANCELLED = "CANCELLED"
    PAID = "PAID"


class PaymentMode(StrEnum):
    """Modes de reglement.

    Deux sont ouverts, et aucun des deux ne deplace d'argent :

    - `CASH_ON_DELIVERY` : l'acheteur paie le livreur a la remise. C'est le mode
      dominant au Cameroun, et le seul reglement reel que le circuit connaisse.
    - `SIMULATION` : une demonstration. Le parcours d'achat va jusqu'au bout sans
      qu'aucun franc ne change de main. Il existe pour montrer et essayer le
      circuit ; la commande en porte la marque de bout en bout, et chaque ecran
      qui l'affiche doit le dire. Un artisan ne doit jamais croire qu'il a ete
      paye.

    `MOBILE_MONEY` et `CARD` sont nommes parce qu'ils sont prevus, et refuses par
    la base tant qu'ils ne sont pas reellement branches : un mode de paiement
    affiche mais non fonctionnel ferait perdre de l'argent a quelqu'un.
    """

    CASH_ON_DELIVERY = "CASH_ON_DELIVERY"
    SIMULATION = "SIMULATION"
    MOBILE_MONEY = "MOBILE_MONEY"
    CARD = "CARD"


class DeliveryStatus(StrEnum):
    UNASSIGNED = "UNASSIGNED"
    ASSIGNED = "ASSIGNED"
    PICKED_UP = "PICKED_UP"
    IN_TRANSIT = "IN_TRANSIT"
    DELIVERED = "DELIVERED"
    FAILED = "FAILED"


class CourierVehicle(StrEnum):
    ON_FOOT = "ON_FOOT"
    BICYCLE = "BICYCLE"
    MOTORCYCLE = "MOTORCYCLE"
    CAR = "CAR"
    VAN = "VAN"


class MarketRoleRequest(StrEnum):
    """Role demande par un dossier de la place de marche."""

    ARTISAN = "ARTISAN"
    COURIER = "COURIER"


#: Familles d'objets acceptees. Volontairement courte : on n'ouvre pas une
#: brocante generaliste, mais un espace d'artisanat rattache au patrimoine.
PRODUCT_CATEGORIES = (
    "TEXTILE",
    "VANNERIE",
    "POTERIE",
    "SCULPTURE",
    "BIJOUX",
    "INSTRUMENT",
    "PEINTURE",
    "GASTRONOMIE",
    "AUTRE",
)


class LearningMotivation(StrEnum):
    """Pourquoi la personne apprend (lot 3, ecran 3).

    Sert a ordonner ce qu'on lui propose, jamais a restreindre l'acces : une
    motivation declaree n'est pas un profil figé.
    """

    DISCOVER_CULTURE = "DISCOVER_CULTURE"
    FAMILY = "FAMILY"
    TRAVEL = "TRAVEL"
    PROFESSIONAL = "PROFESSIONAL"
    PERSONAL = "PERSONAL"
    OTHER = "OTHER"


#: Reglages de notification proposes a la configuration (lot 3, ecran 8).
#: Aucun n'est branche a ce jour : ils enregistrent un consentement, ils ne
#: declenchent rien.
NOTIFICATION_KEYS = ("reminders", "new_content", "tips", "offers")

#: Correspondance entre les minutes annoncees et l'objectif en XP.
#: Une lecon dure 3 a 7 minutes (SS11) et rapporte 10 XP : deux XP par minute
#: annoncee, borne aux valeurs acceptees par le profil.
MINUTES_TO_XP = {5: 10, 10: 20, 15: 30, 30: 50}
