"""Tests du Culture Hub (SS20, SS21).

Le patrimoine obeit aux memes regles que la langue : une fiche sans source ni
validation humaine ne peut pas etre publiee, et chaque fiche publiee expose
d'ou elle vient.
"""

import uuid

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError

from tests.test_cms import _make_user, client  # noqa: F401

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def apprenant(client, session):
    return await _make_user(client, session, role="LEARNER")


@pytest_asyncio.fixture
async def rubrique(session):
    """Une rubrique du Culture Hub."""
    existing = (
        await session.execute(
            text("SELECT id FROM culture.cultural_categories WHERE code = 'TALES'")
        )
    ).scalar_one_or_none()
    if existing:
        return existing
    category_id = uuid.uuid4()
    await session.execute(
        text(
            """
            INSERT INTO culture.cultural_categories (id, code, name_fr, position)
            VALUES (:id, 'TALES', 'Contes', 3)
            """
        ),
        {"id": category_id},
    )
    await session.commit()
    return category_id


@pytest_asyncio.fixture
async def creer_fiche(session, fixture_ids, rubrique):
    """Cree une fiche culturelle au statut voulu."""
    counter = {"n": 0}

    async def _make(status: str = "DRAFT", *, with_source: bool = True, **overrides):
        counter["n"] += 1
        content_id = uuid.uuid4()
        await session.execute(
            text(
                """
                INSERT INTO culture.cultural_contents
                    (id, category_id, title_fr, summary_fr, body_fr, language_id,
                     status, source_id, created_by, validated_by)
                VALUES (:id, :cat, :title, :summary, :body, :lang,
                        CAST(:status AS shared.content_status), :src, :by, :val)
                """
            ),
            {
                "id": content_id,
                "cat": rubrique,
                "title": f"Fiche de test {counter['n']}",
                "summary": f"Resume de test {counter['n']}",
                "body": "Corps de la fiche.",
                "lang": fixture_ids["language"],
                "status": status,
                "src": fixture_ids["source"] if with_source else None,
                "by": overrides.get("created_by", fixture_ids["author"]),
                "val": overrides.get("validated_by"),
            },
        )
        await session.commit()
        return content_id

    return _make


async def _publish(session, fixture_ids, content_id):
    """Fait passer une fiche par tout le circuit de validation."""
    for step in ("TO_VERIFY", "HUMAN_REVIEW"):
        await session.execute(
            text(
                "UPDATE culture.cultural_contents "
                "SET status = CAST(:s AS shared.content_status) WHERE id = :id"
            ),
            {"s": step, "id": content_id},
        )
    await session.execute(
        text(
            """
            INSERT INTO prov.content_validations
                (id, target_type, target_id, validator_contributor_id, decision, decided_at)
            VALUES (:id, 'cultural_contents', :target, :v, 'ACCEPT', now())
            """
        ),
        {"id": uuid.uuid4(), "target": content_id, "v": fixture_ids["validator"]},
    )
    await session.execute(
        text(
            "UPDATE culture.cultural_contents SET status='VALIDATED', validated_by=:v "
            "WHERE id = :id"
        ),
        {"v": fixture_ids["validator"], "id": content_id},
    )
    await session.execute(
        text("UPDATE culture.cultural_contents SET status='PUBLISHED' WHERE id = :id"),
        {"id": content_id},
    )
    await session.commit()


# ---------------------------------------------------------------------------
# Les regles de provenance s'appliquent aussi a la culture
# ---------------------------------------------------------------------------
async def test_une_fiche_sans_source_ne_peut_pas_etre_validee(
    session, fixture_ids, creer_fiche
):
    fiche = await creer_fiche(status="DRAFT", with_source=False)
    with pytest.raises(DBAPIError) as exc:
        await _publish(session, fixture_ids, fiche)
    assert "source_manquante" in str(exc.value)
    await session.rollback()


async def test_publication_directe_d_une_fiche_refusee(session, creer_fiche):
    with pytest.raises(DBAPIError) as exc:
        await creer_fiche(status="PUBLISHED")
    assert "publication_directe" in str(exc.value)
    await session.rollback()


async def test_l_auteur_d_une_fiche_ne_la_valide_pas(session, fixture_ids, creer_fiche):
    fiche = await creer_fiche(status="HUMAN_REVIEW", created_by=fixture_ids["author"])
    await session.execute(
        text(
            """
            INSERT INTO prov.content_validations
                (id, target_type, target_id, validator_contributor_id, decision, decided_at)
            VALUES (:id, 'cultural_contents', :t, :v, 'ACCEPT', now())
            """
        ),
        {"id": uuid.uuid4(), "t": fiche, "v": fixture_ids["author"]},
    )
    await session.commit()

    with pytest.raises(DBAPIError) as exc:
        await session.execute(
            text(
                "UPDATE culture.cultural_contents SET status='VALIDATED', validated_by=:v "
                "WHERE id = :id"
            ),
            {"v": fixture_ids["author"], "id": fiche},
        )
        await session.commit()
    assert "auto_validation" in str(exc.value)
    await session.rollback()


# ---------------------------------------------------------------------------
# Consultation
# ---------------------------------------------------------------------------
async def test_les_rubriques_vides_restent_visibles(client, apprenant):
    """Montrer ce qui reste a documenter fait partie du propos."""
    rubriques = (await client.get("/api/v1/culture/categories")).json()
    assert rubriques, "les rubriques doivent exister"
    assert any(r["published_count"] == 0 for r in rubriques), (
        "les rubriques sans fiche doivent apparaitre quand meme"
    )
    # Les rubriques remplies passent devant.
    counts = [r["published_count"] for r in rubriques]
    assert counts == sorted(counts, reverse=True)


async def test_seules_les_fiches_publiees_sortent(
    client, session, fixture_ids, apprenant, creer_fiche
):
    brouillon = await creer_fiche(status="HUMAN_REVIEW")
    publiee = await creer_fiche(status="DRAFT")
    await _publish(session, fixture_ids, publiee)

    ids = {f["id"] for f in (await client.get("/api/v1/culture")).json()["items"]}
    assert str(publiee) in ids
    assert str(brouillon) not in ids

    assert (await client.get(f"/api/v1/culture/{brouillon}")).status_code == 404


async def test_le_detail_expose_les_sources(
    client, session, fixture_ids, apprenant, creer_fiche
):
    fiche = await creer_fiche(status="DRAFT")
    await session.execute(
        text(
            """
            INSERT INTO prov.source_references
                (id, source_id, target_type, target_id, locator, consulted_at)
            VALUES (:id, :src, 'cultural_contents', :t, 'page de test', now())
            """
        ),
        {"id": uuid.uuid4(), "src": fixture_ids["source"], "t": fiche},
    )
    await session.commit()
    await _publish(session, fixture_ids, fiche)

    data = (await client.get(f"/api/v1/culture/{fiche}")).json()
    assert data["sources"], "une fiche publiee cite toujours ses sources"
    assert data["sources"][0]["locator"] == "page de test"
    assert data["sources"][0]["license"] == "CC0"
    assert data["validated_by"] is not None


async def test_filtrage_par_rubrique(client, session, fixture_ids, apprenant, creer_fiche):
    fiche = await creer_fiche(status="DRAFT")
    await _publish(session, fixture_ids, fiche)

    data = (await client.get("/api/v1/culture?category=TALES")).json()
    assert all(f["category_code"] == "TALES" for f in data["items"])

    vide = (await client.get("/api/v1/culture?category=FESTIVALS")).json()
    assert vide["count"] == 0, "une rubrique sans fiche renvoie une liste vide, pas une erreur"


# ---------------------------------------------------------------------------
# Lien avec l'apprentissage (SS21)
# ---------------------------------------------------------------------------
@pytest_asyncio.fixture
async def unite_avec_lecon(session, fixture_ids):
    ids = {k: uuid.uuid4() for k in ("course", "section", "unit", "lesson")}
    params = {**ids, "lang": fixture_ids["language"], "src": fixture_ids["source"]}
    await session.execute(
        text(
            """
            INSERT INTO learn.courses (id, language_id, level, title_fr, status, source_id)
            VALUES (:course, :lang, 'N0', 'Cours', 'DRAFT', :src)
            """
        ),
        params,
    )
    await session.execute(
        text(
            """
            INSERT INTO learn.sections (id, course_id, position, title_fr, status, source_id)
            VALUES (:section, :course, 0, 'Section', 'DRAFT', :src)
            """
        ),
        params,
    )
    await session.execute(
        text(
            """
            INSERT INTO learn.units
                (id, section_id, position, title_fr, objective_fr, status, source_id)
            VALUES (:unit, :section, 0, 'Unite', 'Objectif', 'DRAFT', :src)
            """
        ),
        params,
    )
    await session.execute(
        text(
            """
            INSERT INTO learn.lessons
                (id, unit_id, position, kind, title_fr, status, source_id)
            VALUES (:lesson, :unit, 0, 'LESSON', 'Lecon', 'DRAFT', :src)
            """
        ),
        params,
    )
    # Publication rapide de la structure pedagogique.
    for table, key in (
        ("courses", "course"),
        ("sections", "section"),
        ("units", "unit"),
        ("lessons", "lesson"),
    ):
        for step in ("TO_VERIFY", "HUMAN_REVIEW"):
            await session.execute(
                text(
                    f"UPDATE learn.{table} SET status = CAST(:s AS shared.content_status) "
                    "WHERE id = :id"
                ),
                {"s": step, "id": ids[key]},
            )
        await session.execute(
            text(
                """
                INSERT INTO prov.content_validations
                    (id, target_type, target_id, validator_contributor_id, decision, decided_at)
                VALUES (:id, :tt, :t, :v, 'ACCEPT', now())
                """
            ),
            {"id": uuid.uuid4(), "tt": table, "t": ids[key], "v": fixture_ids["validator"]},
        )
        await session.execute(
            text(f"UPDATE learn.{table} SET status='VALIDATED', validated_by=:v WHERE id=:id"),
            {"v": fixture_ids["validator"], "id": ids[key]},
        )
        await session.execute(
            text(f"UPDATE learn.{table} SET status='PUBLISHED' WHERE id=:id"), {"id": ids[key]}
        )
    await session.commit()
    return ids


async def test_la_carte_apparait_dans_la_lecon(
    client, session, fixture_ids, apprenant, creer_fiche, unite_avec_lecon
):
    """La culture s'affiche la ou l'on apprend, pas dans un menu separe."""
    fiche = await creer_fiche(status="DRAFT")
    await _publish(session, fixture_ids, fiche)
    await session.execute(
        text(
            """
            INSERT INTO culture.cultural_links
                (id, cultural_content_id, target_type, target_id, placement)
            VALUES (:id, :content, 'UNIT', :unit, 'DID_YOU_KNOW')
            """
        ),
        {"id": uuid.uuid4(), "content": fiche, "unit": unite_avec_lecon["unit"]},
    )
    await session.commit()

    lesson = (
        await client.get(
            f"/api/v1/lessons/{unite_avec_lecon['lesson']}", headers=apprenant
        )
    ).json()

    assert lesson["culture_card"] is not None
    assert lesson["culture_card"]["id"] == str(fiche)
    assert lesson["culture_card"]["source_title"] is not None


async def test_une_unite_sans_fiche_n_invente_pas_de_carte(
    client, apprenant, unite_avec_lecon
):
    lesson = (
        await client.get(
            f"/api/v1/lessons/{unite_avec_lecon['lesson']}", headers=apprenant
        )
    ).json()
    assert lesson["culture_card"] is None


async def test_une_fiche_non_publiee_ne_devient_jamais_une_carte(
    client, session, fixture_ids, apprenant, creer_fiche, unite_avec_lecon
):
    fiche = await creer_fiche(status="HUMAN_REVIEW")
    await session.execute(
        text(
            """
            INSERT INTO culture.cultural_links
                (id, cultural_content_id, target_type, target_id, placement)
            VALUES (:id, :content, 'UNIT', :unit, 'DID_YOU_KNOW')
            """
        ),
        {"id": uuid.uuid4(), "content": fiche, "unit": unite_avec_lecon["unit"]},
    )
    await session.commit()

    lesson = (
        await client.get(
            f"/api/v1/lessons/{unite_avec_lecon['lesson']}", headers=apprenant
        )
    ).json()
    assert lesson["culture_card"] is None


async def test_endpoint_dedie_de_la_carte(
    client, session, fixture_ids, apprenant, creer_fiche, unite_avec_lecon
):
    fiche = await creer_fiche(status="DRAFT")
    await _publish(session, fixture_ids, fiche)
    await session.execute(
        text(
            """
            INSERT INTO culture.cultural_links
                (id, cultural_content_id, target_type, target_id, placement)
            VALUES (:id, :content, 'UNIT', :unit, 'DID_YOU_KNOW')
            """
        ),
        {"id": uuid.uuid4(), "content": fiche, "unit": unite_avec_lecon["unit"]},
    )
    await session.commit()

    # La route « cards » ne doit pas etre confondue avec un identifiant de fiche.
    response = await client.get(f"/api/v1/culture/cards/unit/{unite_avec_lecon['unit']}")
    assert response.status_code == 200
    assert response.json()["id"] == str(fiche)
