"""Schema `admin` : administration de la plateforme (SS43, SS44).

Trois objets, et une regle commune a tous : un acte administratif laisse une
trace motivee. Changer le role d'un compte, l'habiliter sur une langue,
desactiver un acces ou modifier un parametre sont des decisions qui engagent le
contenu publie ; elles sont donc consignees avec leur motif, au meme titre
qu'une decision de validation linguistique (SS5).

La contrainte `ck_audit_log_reason_not_blank` rend cette regle inviolable :
la base refuse une entree de journal sans motif, y compris si du code
applicatif l'oubliait.
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    ARRAY,
    Boolean,
    CheckConstraint,
    DateTime,
    Enum as SAEnum,
    ForeignKey,
    Index,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, Timestamped, UUIDPrimaryKey
from app.shared.enums import ApplicationStatus


class AuditLog(UUIDPrimaryKey, Base):
    """Journal des actes d'administration.

    Aucune API ne permet d'en supprimer une ligne : c'est une piece du dossier,
    pas une note de travail.
    """

    __tablename__ = "audit_log"
    __table_args__ = (
        CheckConstraint("length(btrim(reason)) >= 5", name="reason_not_blank"),
        Index("ix_audit_log_target", "target_type", "target_id"),
        Index("ix_audit_log_created_at", "created_at"),
        {"schema": "admin"},
    )

    #: Le compte qui agit. Conserve meme si le compte disparait ensuite...
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="SET NULL"), nullable=True
    )
    #: ... grace a cette copie figee de son identite au moment de l'acte.
    actor_label: Mapped[str] = mapped_column(Text, nullable=False)

    #: Verbe court : USER_ROLE_CHANGED, USER_DEACTIVATED, HABILITATION_GRANTED...
    action: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    target_type: Mapped[str] = mapped_column(String(64), nullable=False)
    target_id: Mapped[uuid.UUID | None] = mapped_column(PGUUID(as_uuid=True), nullable=True)
    target_label: Mapped[str | None] = mapped_column(Text, nullable=True)

    reason: Mapped[str] = mapped_column(Text, nullable=False)
    #: Etat avant / apres, pour que le journal se lise sans recoupement.
    details: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default="now()"
    )


class SpecialistApplication(UUIDPrimaryKey, Timestamped, Base):
    """Demande d'habilitation comme specialiste culturel (SS43).

    Le cahier des charges parle de KYC. Ici la verification ne porte pas sur une
    identite bancaire mais sur la legitimite a valider une langue : qui est la
    personne, quel est son rapport a la langue, et qui peut en repondre. C'est
    cette habilitation qui ouvre le droit de faire passer un contenu a VALIDATED.

    Le dossier reste attache a la decision : on sait, des annees apres, sur quelle
    base un validateur a ete habilite.
    """

    __tablename__ = "specialist_applications"
    __table_args__ = (
        Index("ix_specialist_applications_status", "status"),
        {"schema": "admin"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="CASCADE"), nullable=False
    )
    language_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("ref.languages.id", ondelete="CASCADE"), nullable=False
    )

    #: LINGUIST, NATIVE_SPEAKER, TEACHER, RECORDIST, EDITOR (cf. prov.contributors.role)
    claimed_role: Mapped[str] = mapped_column(String(32), nullable=False)
    #: Rapport declare a la langue : langue maternelle, apprise, etudiee...
    relationship_fr: Mapped[str] = mapped_column(Text, nullable=False)
    affiliation: Mapped[str | None] = mapped_column(Text, nullable=True)
    #: Personnes ou institutions capables de confirmer la declaration.
    referees_fr: Mapped[str | None] = mapped_column(Text, nullable=True)
    evidence_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    #: Perimetre demande : LEXICON, GRAMMAR, AUDIO, CULTURE, EXERCISE
    requested_scope: Mapped[list[str]] = mapped_column(
        ARRAY(Text), default=list, server_default="{}", nullable=False
    )

    status: Mapped[ApplicationStatus] = mapped_column(
        SAEnum(ApplicationStatus, name="application_status", schema="shared", create_type=False),
        default=ApplicationStatus.PENDING,
        server_default="PENDING",
        nullable=False,
    )
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="SET NULL"), nullable=True
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    review_note: Mapped[str | None] = mapped_column(Text, nullable=True)


class PlatformSetting(Timestamped, Base):
    """Parametres de la plateforme, modifiables sans redeploiement.

    Volontairement peu nombreux : un parametre ici est un choix de politique
    (objectif quotidien propose, ouverture des inscriptions...), pas un reglage
    technique, qui reste dans la configuration du serveur.
    """

    __tablename__ = "platform_settings"
    __table_args__ = {"schema": "admin"}

    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    value: Mapped[dict] = mapped_column(JSONB, nullable=False)
    description_fr: Mapped[str] = mapped_column(Text, nullable=False)
    is_editable: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False
    )
    updated_by: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("iam.users.id", ondelete="SET NULL"), nullable=True
    )
