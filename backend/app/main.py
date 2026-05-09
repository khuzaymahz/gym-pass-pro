from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path
from typing import AsyncIterator

import structlog
from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.redis_client import get_redis
from app.db.session import get_engine

from app.api.v1 import auth as auth_router
from app.api.v1 import checkins as checkins_router
from app.api.v1 import gyms as gyms_router
from app.api.v1 import invoices as invoices_router
from app.api.v1 import me as me_router
from app.api.v1 import notifications as notifications_router
from app.api.v1 import pauses as pauses_router
from app.api.v1 import payment_methods as payment_methods_router
from app.api.v1 import realtime as realtime_router
from app.api.v1 import referrals as referrals_router
from app.api.v1 import subscriptions as subscriptions_router
from app.api.v1 import tickets as tickets_router
from app.api.v1.admin import audit as admin_audit_router
from app.api.v1.admin import checkins as admin_checkins_router
from app.api.v1.admin import gyms as admin_gyms_router
from app.api.v1.admin import metrics as admin_metrics_router
from app.api.v1.admin import notifications as admin_notifications_router
from app.api.v1.admin import owners as admin_owners_router
from app.api.v1.admin import payouts as admin_payouts_router
from app.api.v1.admin import plans as admin_plans_router
from app.api.v1.admin import settings as admin_settings_router
from app.api.v1.admin import subscriptions as admin_subscriptions_router
from app.api.v1.admin import support as admin_support_router
from app.api.v1.admin import users as admin_users_router
from app.api.v1.partner import checkins as partner_checkins_router
from app.api.v1.partner import me as partner_me_router
from app.api.v1.partner import metrics as partner_metrics_router
from app.api.v1.partner import payouts as partner_payouts_router
from app.api.v1.partner import photos as partner_photos_router
from app.api.v1.partner import profile as partner_profile_router
from app.config import get_settings
from app.core.error_handlers import (
    app_error_handler,
    http_exception_handler,
    unhandled_error_handler,
    validation_error_handler,
)
from app.core.exceptions import AppError
from app.core.logging import configure_logging
from app.core.middleware import RequestContextMiddleware


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    configure_logging()
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    settings.validate_production_safety()
    app = FastAPI(
        title="GymPass API",
        version="0.1.0",
        lifespan=lifespan,
        docs_url="/docs" if settings.is_dev else None,
        redoc_url=None,
        openapi_url="/openapi.json" if settings.is_dev else None,
    )

    app.add_middleware(RequestContextMiddleware)
    # GZip on responses ≥ 500 bytes. Most JSON list endpoints
    # (admin checkins, partner metrics) compress to ~20% of their
    # raw size; the CPU cost on the API side is dwarfed by the
    # transfer-time win on slow mobile networks. The 500-byte
    # floor avoids spending cycles on tiny payloads where the
    # gzip header itself can be larger than the saving.
    app.add_middleware(GZipMiddleware, minimum_size=500)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins(),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.add_exception_handler(AppError, app_error_handler)
    app.add_exception_handler(RequestValidationError, validation_error_handler)
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(Exception, unhandled_error_handler)

    v1_prefix = "/api/v1"
    app.include_router(auth_router.router, prefix=v1_prefix)
    app.include_router(me_router.router, prefix=v1_prefix)
    app.include_router(referrals_router.router, prefix=v1_prefix)
    app.include_router(gyms_router.router, prefix=v1_prefix)
    app.include_router(subscriptions_router.router, prefix=v1_prefix)
    app.include_router(checkins_router.router, prefix=v1_prefix)
    app.include_router(notifications_router.router, prefix=v1_prefix)
    app.include_router(tickets_router.router, prefix=v1_prefix)
    app.include_router(payment_methods_router.router, prefix=v1_prefix)
    app.include_router(invoices_router.router, prefix=v1_prefix)
    app.include_router(pauses_router.router, prefix=v1_prefix)
    app.include_router(admin_gyms_router.router, prefix=v1_prefix)
    app.include_router(admin_users_router.router, prefix=v1_prefix)
    app.include_router(admin_plans_router.router, prefix=v1_prefix)
    app.include_router(admin_subscriptions_router.router, prefix=v1_prefix)
    app.include_router(admin_checkins_router.router, prefix=v1_prefix)
    app.include_router(admin_payouts_router.router, prefix=v1_prefix)
    app.include_router(admin_audit_router.router, prefix=v1_prefix)
    app.include_router(admin_metrics_router.router, prefix=v1_prefix)
    app.include_router(admin_notifications_router.router, prefix=v1_prefix)
    app.include_router(admin_support_router.router, prefix=v1_prefix)
    app.include_router(admin_settings_router.router, prefix=v1_prefix)
    app.include_router(admin_owners_router.router, prefix=v1_prefix)
    app.include_router(partner_me_router.router, prefix=v1_prefix)
    app.include_router(partner_profile_router.router, prefix=v1_prefix)
    app.include_router(partner_photos_router.router, prefix=v1_prefix)
    app.include_router(partner_checkins_router.router, prefix=v1_prefix)
    app.include_router(partner_payouts_router.router, prefix=v1_prefix)
    app.include_router(partner_metrics_router.router, prefix=v1_prefix)
    # WebSocket fan-out for live updates. Lives at /api/v1/realtime/ws.
    # Behind nginx in prod, the upgrade headers must be passed through
    # — see nginx/conf.d/api.conf for the `proxy_set_header Upgrade`
    # block keyed off `$http_upgrade`.
    app.include_router(realtime_router.router, prefix=v1_prefix)

    media_dir = Path(settings.media_root)
    media_dir.mkdir(parents=True, exist_ok=True)
    app.mount(
        settings.media_url_prefix,
        StaticFiles(directory=str(media_dir), check_dir=False),
        name="media",
    )

    log = structlog.get_logger("health")

    @app.get("/health", tags=["health"])
    async def health() -> dict[str, str]:
        """Liveness probe — process is up.

        Deliberately does NOT touch DB or Redis. Liveness asks
        "is this container worth keeping alive"; flipping it on a
        transient DB blip would cause the orchestrator to restart
        the pod and amplify a downstream incident into a rolling
        outage. Use `/readyz` for the deps-aware check.
        """
        return {"status": "ok"}

    @app.get("/readyz", tags=["health"])
    async def readyz() -> JSONResponse:
        """Readiness probe — every backing dep responsive.

        Returns 200 only when the DB accepts a `SELECT 1` and Redis
        responds to PING. Fails closed (503) on either side so the
        orchestrator pulls the pod out of rotation while it can't
        serve real traffic. Each check is wrapped in its own
        try/except so we can report which side is broken instead of
        a generic "not ready".
        """
        checks: dict[str, str] = {}
        ok = True
        try:
            async with get_engine().connect() as conn:
                await conn.execute(text("SELECT 1"))
            checks["db"] = "ok"
        except Exception as exc:
            ok = False
            checks["db"] = "error"
            log.error("readyz_db_failed", error=str(exc))
        try:
            pong = await get_redis().ping()
            checks["redis"] = "ok" if pong else "error"
            ok = ok and bool(pong)
        except Exception as exc:
            ok = False
            checks["redis"] = "error"
            log.error("readyz_redis_failed", error=str(exc))
        return JSONResponse(
            status_code=200 if ok else 503,
            content={"status": "ok" if ok else "degraded", "checks": checks},
        )

    return app


app = create_app()
