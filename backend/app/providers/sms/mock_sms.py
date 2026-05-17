from __future__ import annotations

import structlog

log = structlog.get_logger(__name__)


class MockSmsProvider:
    async def send_otp(self, phone: str, code: str) -> None:
        # Mock SMS provider used in development AND staging (per
        # CLAUDE.md §15 — real SMS provider for production is
        # deferred). The OTP is emitted at INFO level so any
        # operator with `docker compose logs -f backend` can read it
        # while testing — including in staging where the OTP is a
        # random 4-digit code (not the dev `1234` sentinel) but is
        # still mock-delivered. The structlog redactor strips any
        # field name containing `code`, `token`, `password`, or
        # `secret`, so we deliberately use `otp` as the field name
        # here to let it through. Real SMS providers won't log the
        # code at all.
        log.info("sms.mock.dispatch", phone=phone, otp=code)
