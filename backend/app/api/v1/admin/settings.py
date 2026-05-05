"""System Settings — read-only operator surface.

Exposes the runtime configuration an admin can't otherwise see
without SSH'ing into the container: which SMS / payment / push
providers are wired, what the JWT TTLs are, what the rate-limit
thresholds resolve to, plus a quick liveness check on the
critical infra (Postgres, Redis).

Read-only by design. Mutating these values requires editing the
operator's `.env` and redeploying — making them editable from the
UI would invite the operator to check a "production" box on a dev
build and immediately get bitten by half-applied state.
"""

from __future__ import annotations

import time
from typing import Annotated

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict, Field
from redis.asyncio import Redis
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_admin, db_session, redis_client
from app.config import get_settings
from app.db.models import User

router = APIRouter(prefix="/admin/settings", tags=["admin", "settings"])


class HealthCheck(BaseModel):
    """One liveness probe result. `latency_ms` is None when the probe
    failed (timeout / connection refused / etc.); the UI renders
    that as a red dot.
    """

    name: str
    ok: bool
    latency_ms: float | None = Field(alias="latencyMs", default=None)
    detail: str | None = None

    model_config = ConfigDict(populate_by_name=True)


class ProviderInfo(BaseModel):
    """The currently-wired adapter for one external system."""

    kind: str
    name: str

    model_config = ConfigDict(populate_by_name=True)


class SettingsResponse(BaseModel):
    """Top-level shape returned to the admin Settings page.

    Nothing here is secret — values are either tags ("twilio") or
    integers (TTLs). Real secrets (API keys, JWT signing key)
    deliberately stay server-side.
    """

    app_env: str = Field(alias="appEnv")
    is_dev: bool = Field(alias="isDev")
    api_domain: str = Field(alias="apiDomain")
    admin_domain: str = Field(alias="adminDomain")
    media_url_prefix: str = Field(alias="mediaUrlPrefix")
    max_upload_mb: int = Field(alias="maxUploadMb")

    providers: list[ProviderInfo]

    jwt_access_ttl_seconds: int = Field(alias="jwtAccessTtlSeconds")
    jwt_refresh_ttl_seconds: int = Field(alias="jwtRefreshTtlSeconds")
    jwt_service_ttl_seconds: int = Field(alias="jwtServiceTtlSeconds")

    admin_exchange_max_skew_seconds: int = Field(
        alias="adminExchangeMaxSkewSeconds",
    )

    health: list[HealthCheck]

    model_config = ConfigDict(populate_by_name=True)


@router.get("", response_model=SettingsResponse)
async def get_settings_endpoint(
    _: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
    redis: Annotated[Redis, Depends(redis_client)],
) -> SettingsResponse:
    settings = get_settings()
    health: list[HealthCheck] = []

    # Postgres probe — `SELECT 1` is the cheapest possible query
    # that still exercises the connection pool round-trip. Wrapped
    # in try/except so a DB outage shows in the UI rather than
    # 500'ing the entire settings page.
    started = time.perf_counter()
    try:
        await session.execute(text("SELECT 1"))
        health.append(
            HealthCheck(
                name="postgres",
                ok=True,
                latencyMs=round((time.perf_counter() - started) * 1000, 1),
            )
        )
    except Exception as exc:  # noqa: BLE001 — surface anything to the UI
        health.append(
            HealthCheck(
                name="postgres",
                ok=False,
                detail=type(exc).__name__,
            )
        )

    # Redis probe — PING is the canonical liveness check.
    started = time.perf_counter()
    try:
        pong = await redis.ping()
        ok = bool(pong)
        health.append(
            HealthCheck(
                name="redis",
                ok=ok,
                latencyMs=round((time.perf_counter() - started) * 1000, 1)
                if ok
                else None,
            )
        )
    except Exception as exc:  # noqa: BLE001
        health.append(
            HealthCheck(
                name="redis",
                ok=False,
                detail=type(exc).__name__,
            )
        )

    return SettingsResponse(
        appEnv=settings.app_env,
        isDev=settings.is_dev,
        apiDomain=settings.api_domain,
        adminDomain=settings.admin_domain,
        mediaUrlPrefix=settings.media_url_prefix,
        maxUploadMb=settings.max_upload_mb,
        providers=[
            ProviderInfo(kind="sms", name=settings.sms_provider),
            ProviderInfo(kind="payment", name=settings.payment_provider),
        ],
        jwtAccessTtlSeconds=settings.jwt_access_ttl_seconds,
        jwtRefreshTtlSeconds=settings.jwt_refresh_ttl_seconds,
        jwtServiceTtlSeconds=settings.jwt_service_ttl_seconds,
        adminExchangeMaxSkewSeconds=settings.admin_exchange_max_skew_seconds,
        health=health,
    )
