from __future__ import annotations

import structlog

from app.config import get_settings

log = structlog.get_logger(__name__)


class MockSmsProvider:
    async def send_otp(self, phone: str, code: str) -> None:
        """Mock SMS provider used in development and staging (real SMS
        gateway for production is still deferred per CLAUDE.md §15).

        OTP plaintext logging is gated to **development only**. Staging
        runs a real random 4-digit code path that resembles production,
        and staging logs may be aggregated to a place the dev team
        doesn't fully control — leaking the OTP plaintext there gives a
        log-reader OTP-bypass for any staging member. In staging we
        log the dispatch metadata without the code; in development we
        log the code so an operator with `docker compose logs -f` can
        copy it. Real SMS providers never log the code at all.
        """
        settings = get_settings()
        if settings.is_dev:
            log.info("sms.mock.dispatch", phone=phone, otp=code)
        else:
            log.info("sms.mock.dispatch", phone=phone, mode="redacted")
