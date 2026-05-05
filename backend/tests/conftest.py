from __future__ import annotations

import os
from collections.abc import AsyncIterator

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

os.environ.setdefault("APP_ENV", "development")
os.environ.setdefault("POSTGRES_HOST", "localhost")
# Force the test DB name regardless of what's exported in the shell. The
# engine fixture below does drop_all + create_all and the tests sign up real
# users via `/auth/phone/start`, so a dev who happened to have
# POSTGRES_DB=gympass exported would otherwise wipe and pollute the dev DB.
os.environ["POSTGRES_DB"] = "gympass_test"
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/15")
os.environ.setdefault("JWT_SECRET", "test-secret-long-random-string")

from app.api.deps import db_session, redis_client  # noqa: E402
from app.config import get_settings  # noqa: E402
from app.db.base import Base  # noqa: E402
from app.main import create_app  # noqa: E402


# All async fixtures and tests share the session-scoped loop (see
# pyproject.toml). The shared loop is required because the engine is
# session-scoped: asyncpg protocol state is bound to the loop that created
# the connection, so a per-function loop would fault on the next fixture
# teardown with "Future attached to a different loop".
@pytest_asyncio.fixture(scope="session", loop_scope="session")
async def _engine():
    settings = get_settings()
    # Defensive: drop_all/create_all is destructive. If anything ever resolves
    # the test DB to something that isn't clearly a test database, refuse to
    # run rather than nuke real data.
    if not settings.postgres_db.endswith("_test"):
        raise RuntimeError(
            f"Refusing to run tests against non-test DB '{settings.postgres_db}'. "
            "Test DB name must end with '_test'."
        )
    engine = create_async_engine(settings.sqlalchemy_url())
    async with engine.begin() as conn:
        # Import models so metadata is populated.
        from app.db import models  # noqa: F401

        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest_asyncio.fixture(loop_scope="session")
async def db(_engine) -> AsyncIterator[AsyncSession]:
    factory = async_sessionmaker(_engine, expire_on_commit=False)
    async with factory() as session:
        yield session
        await session.rollback()


class _FakeRedis:
    def __init__(self) -> None:
        self.store: dict[str, int] = {}

    def pipeline(self) -> "_FakePipeline":
        return _FakePipeline(self)


class _FakePipeline:
    def __init__(self, parent: _FakeRedis) -> None:
        self.parent = parent
        self.ops: list[tuple[str, tuple]] = []

    def incr(self, key: str) -> "_FakePipeline":
        self.ops.append(("incr", (key,)))
        return self

    def expire(self, key: str, seconds: int) -> "_FakePipeline":
        self.ops.append(("expire", (key, seconds)))
        return self

    async def execute(self) -> list:
        results = []
        for op, args in self.ops:
            if op == "incr":
                k = args[0]
                self.parent.store[k] = self.parent.store.get(k, 0) + 1
                results.append(self.parent.store[k])
            else:
                results.append(True)
        self.ops.clear()
        return results


@pytest_asyncio.fixture(loop_scope="session")
async def client(_engine, db):
    app = create_app()

    async def _override_session():
        yield db

    fake = _FakeRedis()

    async def _override_redis():
        return fake

    app.dependency_overrides[db_session] = _override_session
    app.dependency_overrides[redis_client] = _override_redis

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
