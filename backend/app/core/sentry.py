"""Sentry init for the FastAPI backend.

Single-call setup intended for `create_app()` — wires up:
  - HTTP error capture via the FastAPI integration
  - Async-task error capture via the asyncio integration
  - SQLAlchemy span tracking for slow-query investigations
  - Environment tag (`development` / `staging` / `production`)
    so DSN dashboards stay separable across deploys
  - `traces_sample_rate` defaulted off in dev (0.0) and gradually
    sampled in staging (0.1) / production (0.05)

The DSN comes from the `SENTRY_DSN` env var. Leave it unset to
disable Sentry entirely — `init` short-circuits and no breadcrumbs
are emitted. This matches CLAUDE.md §15 ("Sentry deferred"): we
ship the wiring now so flipping it on later is one env-var flip
on the VM, not a code change.
"""

from __future__ import annotations

import logging
from typing import Any

import structlog

from app.config import get_settings

log = structlog.get_logger(__name__)


def configure_sentry() -> bool:
    """Initialise Sentry SDK if `SENTRY_DSN` is set.

    Returns True when Sentry is live, False when disabled. Safe to
    call from `create_app()` even when the dependency isn't
    installed — it logs a one-line warning and short-circuits.
    """
    settings = get_settings()
    # Read DSN directly off the environment rather than through the
    # Settings class so we don't have to plumb it through Pydantic
    # for a feature that's optional everywhere.
    import os

    dsn = os.environ.get("SENTRY_DSN", "").strip()
    if not dsn:
        # Quiet — Sentry-off is the default in dev. No need to spam
        # the logs every boot.
        return False

    try:
        import sentry_sdk
        from sentry_sdk.integrations.fastapi import FastApiIntegration
        from sentry_sdk.integrations.starlette import StarletteIntegration
        from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration
        from sentry_sdk.integrations.asyncio import AsyncioIntegration
        from sentry_sdk.integrations.logging import LoggingIntegration
    except ImportError:
        log.warning(
            "sentry.dsn_set_but_sdk_missing",
            hint="add `sentry-sdk[fastapi]` to backend deps",
        )
        return False

    # Trace sampling: dev = 0 (don't spam the personal DSN), staging
    # = 0.1 (10% of requests get a span — enough for slow-query
    # investigations without burning quota), production = 0.05.
    # Override via SENTRY_TRACES_SAMPLE_RATE if the defaults bite.
    default_rate = (
        0.0
        if settings.is_dev
        else 0.1
        if settings.is_staging
        else 0.05
    )
    rate_env = os.environ.get("SENTRY_TRACES_SAMPLE_RATE")
    traces_rate: float = default_rate
    if rate_env:
        try:
            traces_rate = float(rate_env)
        except ValueError:
            log.warning(
                "sentry.invalid_traces_rate",
                value=rate_env,
                falling_back_to=default_rate,
            )

    sentry_sdk.init(
        dsn=dsn,
        environment=settings.app_env,
        release=os.environ.get("APP_RELEASE", "gympass-backend@0.1.0"),
        traces_sample_rate=traces_rate,
        # Send PII (user emails, etc.) — gated to non-prod since
        # production payloads should be scrubbed at the SDK level.
        send_default_pii=settings.is_dev,
        integrations=[
            StarletteIntegration(),
            FastApiIntegration(transaction_style="endpoint"),
            SqlalchemyIntegration(),
            AsyncioIntegration(),
            # WARN-level structlog events become breadcrumbs; ERROR
            # and above become events. Matches the conventional split.
            LoggingIntegration(
                level=logging.INFO,
                event_level=logging.ERROR,
            ),
        ],
    )
    log.info("sentry.configured", env=settings.app_env, traces_rate=traces_rate)
    return True


def capture_exception(exc: BaseException, **extra: Any) -> None:
    """Convenience wrapper — caller doesn't have to know whether
    Sentry is loaded. No-op when SDK isn't installed / DSN is unset.
    """
    try:
        import sentry_sdk
    except ImportError:
        return
    if extra:
        with sentry_sdk.push_scope() as scope:
            for k, v in extra.items():
                scope.set_extra(k, v)
            sentry_sdk.capture_exception(exc)
    else:
        sentry_sdk.capture_exception(exc)
