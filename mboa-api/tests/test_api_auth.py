"""Tests d'API : inscription, connexion, rotation des jetons, controle d'acces."""

import uuid

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.db import get_session
from app.main import app
from tests.conftest import TEST_SETTINGS

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def client():
    engine = create_async_engine(TEST_SETTINGS.database_url, poolclass=NullPool)
    maker = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async def _session():
        async with maker() as s:
            try:
                yield s
                await s.commit()
            except Exception:
                await s.rollback()
                raise

    app.dependency_overrides[get_session] = _session
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
    await engine.dispose()


def _email() -> str:
    return f"u-{uuid.uuid4().hex[:10]}@example.com"


async def _register(client, email, **extra):
    return await client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "motdepasse-solide", "display_name": "Test", **extra},
    )


async def test_inscription_impose_le_role_apprenant(client):
    """Le cahier des charges : role LEARNER attribue, sans possibilite d'en choisir un autre."""
    email = _email()
    response = await _register(client, email, role="ADMIN")  # tentative d'elevation
    assert response.status_code == 201

    token = response.json()["access_token"]
    me = await client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.json()["role"] == "LEARNER"


async def test_email_deja_utilise(client):
    email = _email()
    assert (await _register(client, email)).status_code == 201
    assert (await _register(client, email)).status_code == 409


async def test_mot_de_passe_trop_court_refuse(client):
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": _email(), "password": "court", "display_name": "T"},
    )
    assert response.status_code == 422


async def test_connexion_et_message_generique(client):
    email = _email()
    await _register(client, email)

    ok = await client.post(
        "/api/v1/auth/login", json={"email": email, "password": "motdepasse-solide"}
    )
    assert ok.status_code == 200

    bad_password = await client.post(
        "/api/v1/auth/login", json={"email": email, "password": "mauvais-mot"}
    )
    unknown = await client.post(
        "/api/v1/auth/login", json={"email": _email(), "password": "motdepasse-solide"}
    )
    # Meme reponse dans les deux cas : on ne revele pas l'existence d'un compte.
    assert bad_password.status_code == unknown.status_code == 401
    assert bad_password.json() == unknown.json()


async def test_rotation_du_refresh_token(client):
    tokens = (await _register(client, _email())).json()

    first = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert first.status_code == 200

    # L'ancien jeton a ete revoque : sa reutilisation est refusee.
    replay = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert replay.status_code == 401


async def test_routes_protegees_sans_jeton(client):
    assert (await client.get("/api/v1/auth/me")).status_code == 401
    assert (await client.get("/api/v1/progress")).status_code == 401
    bad = await client.get("/api/v1/progress", headers={"Authorization": "Bearer invalide"})
    assert bad.status_code == 401
