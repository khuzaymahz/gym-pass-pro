from __future__ import annotations

from collections.abc import AsyncIterator
from functools import lru_cache

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.ext.asyncio.engine import AsyncEngine

from app.config import get_settings


@lru_cache
def get_engine() -> AsyncEngine:
    settings = get_settings()
    return create_async_engine(
        settings.sqlalchemy_url(),
        pool_size=settings.db_pool_size,
        max_overflow=settings.db_max_overflow,
        pool_pre_ping=True,
        future=True,
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
