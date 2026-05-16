from __future__ import annotations

import json
from collections.abc import AsyncIterator
from decimal import Decimal
from functools import lru_cache
from typing import Any
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.ext.asyncio.engine import AsyncEngine

from app.config import get_settings


def _json_default(value: Any) -> Any:
    """JSON fallback for types the stdlib encoder doesn't know about.

    Audit-log diffs in particular regularly contain Decimal (price /
    JOD amount) and UUID (entity_id, foreign keys) values that were
    raising `TypeError: Object of type Decimal is not JSON serializable`
    when asyncpg tried to encode the row, aborting the whole
    transaction. Decimal serialises to its canonical string so JOD
    amounts round-trip losslessly (`Decimal("45.00")` → `"45.00"`,
    not `45.0`). UUIDs and other types fall back to `str()`.
    """
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, UUID):
        return str(value)
    return str(value)


def _json_serializer(payload: Any) -> str:
    return json.dumps(payload, default=_json_default)


@lru_cache
def get_engine() -> AsyncEngine:
    settings = get_settings()
    return create_async_engine(
        settings.sqlalchemy_url(),
        pool_size=settings.db_pool_size,
        max_overflow=settings.db_max_overflow,
        pool_pre_ping=True,
        future=True,
        json_serializer=_json_serializer,
    )


def make_engine() -> AsyncEngine:
    """Build a fresh AsyncEngine bound to the caller's event loop.

    Celery workers run each task inside its own short-lived
    `asyncio.run(...)` loop. Reusing the process-cached engine across
    those loops fails with `RuntimeError: Future attached to a
    different loop` because asyncpg's connection pool tracks the loop
    that owned the first task. Tasks therefore call `make_engine()`
    inside their async entry-point and dispose it on the way out.
    """
    settings = get_settings()
    return create_async_engine(
        settings.sqlalchemy_url(),
        pool_size=settings.db_pool_size,
        max_overflow=settings.db_max_overflow,
        pool_pre_ping=True,
        future=True,
        json_serializer=_json_serializer,
    )


@lru_cache
def _session_factory() -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(
        bind=get_engine(),
        class_=AsyncSession,
        expire_on_commit=False,
        autoflush=False,
    )


def session_factory() -> async_sessionmaker[AsyncSession]:
    """Public accessor for the cached session factory.

    Most callers should depend on the FastAPI-managed `db_session` —
    one session per request, automatic rollback on error. The factory
    is for read-side parallelism cases where a service wants to run
    several independent queries via `asyncio.gather`: each task takes
    its own session from the factory, since `AsyncSession` is not
    safe for concurrent use within one session.
    """
    return _session_factory()


async def get_session() -> AsyncIterator[AsyncSession]:
    factory = _session_factory()
    async with factory() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
