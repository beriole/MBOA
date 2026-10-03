"""Tableau de bord d'administration : ce que la plateforme contient reellement.

Deux familles de chiffres, et la seconde compte plus que la premiere :

1. l'ACTIVITE (comptes, corpus, lecons, traductions) ;
2. l'INTEGRITE : le nombre de contenus publies qui echappent aux regles du
   cahier des charges. Ces compteurs doivent valoir zero. S'ils ne valent pas
   zero, c'est que quelque chose a contourne les triggers, et l'administrateur
   doit le voir en premier, pas le chercher.
"""

from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

#: Chaque controle est une requete qui compte les anomalies. Le libelle est
#: redige pour etre lu par un humain non technique.
INTEGRITY_CHECKS: tuple[tuple[str, str, str], ...] = (
    (
        "lexique_publie_sans_source",
        "Mots publiés sans source identifiée",
        "SELECT count(*) FROM corpus.vocabulary_items "
        "WHERE status = 'PUBLISHED' AND source_id IS NULL",
    ),
    (
        "lexique_publie_sans_validateur",
        "Mots publiés sans validateur humain",
        "SELECT count(*) FROM corpus.vocabulary_items "
        "WHERE status = 'PUBLISHED' AND validated_by IS NULL",
    ),
    (
        "lexique_auto_valide",
        "Mots validés par leur propre rédacteur",
        "SELECT count(*) FROM corpus.vocabulary_items "
        "WHERE validated_by IS NOT NULL AND validated_by = created_by",
    ),
    (
        "exercices_publies_sans_origine",
        "Exercices publiés sans mot d'origine",
        "SELECT count(*) FROM learn.exercises WHERE status = 'PUBLISHED' "
        "AND jsonb_array_length(coalesce(generated_from, '[]'::jsonb)) = 0",
    ),
    (
        "fiches_publiees_sans_source",
        "Fiches culturelles publiées sans source",
        "SELECT count(*) FROM culture.cultural_contents "
        "WHERE status = 'PUBLISHED' AND source_id IS NULL",
    ),
    (
        "fiches_auto_validees",
        "Fiches culturelles validées par leur propre auteur",
        "SELECT count(*) FROM culture.cultural_contents "
        "WHERE validated_by IS NOT NULL AND validated_by = created_by",
    ),
    (
        "habilitations_sans_perimetre",
        "Habilitations actives sans périmètre défini",
        "SELECT count(*) FROM prov.validation_assignments "
        "WHERE is_active AND cardinality(scope) = 0",
    ),
    (
        "sources_sans_licence",
        "Sources utilisées dont la licence reste inconnue",
        "SELECT count(DISTINCT s.id) FROM prov.sources s "
        "WHERE s.license = 'UNKNOWN' AND EXISTS ("
        "  SELECT 1 FROM corpus.vocabulary_items v WHERE v.source_id = s.id"
        "  UNION ALL SELECT 1 FROM culture.cultural_contents c WHERE c.source_id = s.id)",
    ),
)

#: Ce que l'administration ne couvre pas encore, et pourquoi. Affiche tel quel :
#: une console d'administration qui pretend tout gerer se decouvre en reunion.
OPEN_WORK: tuple[dict[str, str], ...] = (
    {
        "domaine": "Paiements et abonnements",
        "etat": "non implémenté",
        "raison": "aucune entité juridique ni compte marchand à ce stade du projet",
    },
    {
        "domaine": "Vérification d'identité des artisans et livreurs",
        "etat": "non implémenté",
        "raison": "la place de marché n'est pas ouverte ; cette vérification portera sur "
        "des pièces d'identité et relève d'un traitement de données à déclarer",
    },
    {
        "domaine": "Examen des signalements",
        "etat": "partiellement implémenté",
        "raison": "un commentaire signalé est bien masqué immédiatement "
        "(POST /social/comments/{id}/report), mais aucun écran ne permet encore "
        "de relire ce qui a été signalé ni de trancher : le masquage est donc "
        "définitif de fait, ce qui n'est pas la règle voulue",
    },
)


async def _scalar(db: AsyncSession, sql: str) -> int:
    return int((await db.execute(text(sql))).scalar_one())


async def accounts(db: AsyncSession) -> dict:
    rows = await db.execute(
        text(
            """
            SELECT role::text AS role,
                   count(*) AS total,
                   count(*) FILTER (WHERE is_active) AS actifs
            FROM iam.users GROUP BY role ORDER BY count(*) DESC
            """
        )
    )
    par_role = [dict(r._mapping) for r in rows]
    recents = await db.execute(
        text(
            """
            SELECT
                count(*) FILTER (WHERE last_login_at > now() - interval '7 days') AS connectes_7j,
                count(*) FILTER (WHERE created_at > now() - interval '30 days') AS inscrits_30j,
                count(*) FILTER (WHERE last_login_at IS NULL) AS jamais_connectes
            FROM iam.users
            """
        )
    )
    return {
        "total": sum(r["total"] for r in par_role),
        "par_role": par_role,
        **dict(recents.one()._mapping),
    }


async def corpus(db: AsyncSession) -> dict:
    """Etat du corpus, langue par langue.

    `en_attente` regroupe tout ce qui n'est ni publie ni rejete : c'est la
    charge de travail reelle des specialistes culturels.
    """
    rows = await db.execute(
        text(
            """
            SELECT l.id, l.iso639_3, l.name,
                   count(v.id) AS total,
                   count(v.id) FILTER (WHERE v.status = 'PUBLISHED') AS publies,
                   count(v.id) FILTER (WHERE v.status = 'VALIDATED') AS valides,
                   count(v.id) FILTER (
                       WHERE v.status NOT IN ('PUBLISHED','REJECTED')) AS en_attente,
                   count(v.id) FILTER (WHERE v.meaning_fr IS NULL) AS sans_glose
            FROM ref.languages l
            LEFT JOIN corpus.vocabulary_items v ON v.language_id = l.id
            GROUP BY l.id, l.iso639_3, l.name
            HAVING count(v.id) > 0
            ORDER BY count(v.id) DESC
            """
        )
    )
    statuts = await db.execute(
        text(
            """
            SELECT status::text AS statut, count(*) AS total
            FROM corpus.vocabulary_items GROUP BY status ORDER BY count(*) DESC
            """
        )
    )
    return {
        "par_langue": [dict(r._mapping) for r in rows],
        "par_statut": [dict(r._mapping) for r in statuts],
    }


async def licences(db: AsyncSession) -> list[dict]:
    """Repartition des licences des sources effectivement utilisees.

    Repond a la question que pose tout financeur : sous quelles licences ce
    contenu est-il diffuse, et qui faut-il crediter.
    """
    rows = await db.execute(
        text(
            """
            SELECT s.license::text AS licence,
                   count(DISTINCT s.id) AS sources,
                   count(v.id) AS mots,
                   count(v.id) FILTER (WHERE v.status = 'PUBLISHED') AS mots_publies
            FROM prov.sources s
            LEFT JOIN corpus.vocabulary_items v ON v.source_id = s.id
            GROUP BY s.license
            ORDER BY count(v.id) DESC, s.license::text
            """
        )
    )
    return [dict(r._mapping) for r in rows]


async def content(db: AsyncSession) -> dict:
    row = await db.execute(
        text(
            """
            SELECT
                (SELECT count(*) FROM learn.exercises
                  WHERE status = 'PUBLISHED') AS exercices_publies,
                (SELECT count(*) FROM learn.exercises
                  WHERE status NOT IN ('PUBLISHED','REJECTED')) AS exercices_en_attente,
                (SELECT count(*) FROM learn.lessons) AS lecons,
                (SELECT count(*) FROM culture.cultural_contents
                  WHERE status = 'PUBLISHED') AS fiches_publiees,
                (SELECT count(*) FROM culture.cultural_categories
                  WHERE is_active) AS rubriques,
                (SELECT count(*) FROM culture.cultural_categories cat
                  WHERE cat.is_active AND NOT EXISTS (
                    SELECT 1 FROM culture.cultural_contents c
                    WHERE c.category_id = cat.id AND c.status = 'PUBLISHED'
                  )) AS rubriques_vides,
                (SELECT count(*) FROM audio.audio_assets) AS enregistrements
            """
        )
    )
    return dict(row.one()._mapping)


async def activity(db: AsyncSession) -> dict:
    row = await db.execute(
        text(
            """
            SELECT
                (SELECT count(*) FROM progress.lesson_sessions) AS sessions,
                (SELECT count(*) FROM progress.exercise_attempts) AS tentatives,
                (SELECT count(*) FROM progress.exercise_attempts
                  WHERE created_at > now() - interval '7 days') AS tentatives_7j,
                (SELECT count(*) FROM translate.translation_requests) AS traductions,
                (SELECT count(*) FROM translate.translation_requests
                  WHERE match_count = 0) AS traductions_sans_reponse
            """
        )
    )
    return dict(row.one()._mapping)


async def integrity(db: AsyncSession) -> dict:
    """Les controles qui doivent tous valoir zero."""
    controles = []
    for code, label, sql in INTEGRITY_CHECKS:
        anomalies = await _scalar(db, sql)
        controles.append(
            {"code": code, "libelle": label, "anomalies": anomalies, "conforme": anomalies == 0}
        )
    return {
        "conforme": all(c["conforme"] for c in controles),
        "anomalies_totales": sum(c["anomalies"] for c in controles),
        "controles": controles,
    }


async def workload(db: AsyncSession) -> dict:
    """Ce qui attend une decision humaine."""
    row = await db.execute(
        text(
            """
            SELECT
                (SELECT count(*) FROM corpus.vocabulary_items
                  WHERE status IN ('SOURCE_FOUND','TO_VERIFY','HUMAN_REVIEW')) AS mots_a_relire,
                (SELECT count(*) FROM learn.exercises
                  WHERE status = 'HUMAN_REVIEW') AS exercices_a_relire,
                (SELECT count(*) FROM culture.cultural_contents
                  WHERE status IN ('SOURCE_FOUND','TO_VERIFY','HUMAN_REVIEW'))
                  AS fiches_a_relire,
                (SELECT count(*) FROM admin.specialist_applications
                  WHERE status = 'PENDING') AS demandes_habilitation,
                (SELECT count(*) FROM prov.validation_assignments
                  WHERE is_active) AS habilitations_actives
            """
        )
    )
    return dict(row.one()._mapping)


async def dashboard(db: AsyncSession) -> dict:
    return {
        "comptes": await accounts(db),
        "corpus": await corpus(db),
        "licences": await licences(db),
        "contenu": await content(db),
        "activite": await activity(db),
        "a_traiter": await workload(db),
        "integrite": await integrity(db),
        "chantiers_ouverts": [dict(item) for item in OPEN_WORK],
    }
