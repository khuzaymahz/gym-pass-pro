from __future__ import annotations

import structlog

log = structlog.get_logger(__name__)


class MockSmsProvider:
    async def send_otp(self, phone: str, code: str) -> None:
        # In dev, fall back to stdout so devs can actually read the OTP —
        # the structlog redactor strips any key containing "code".
        print(f"[mock-sms] phone={phone} otp={code}", flush=True)
        log.info("sms.otp.dispatch", phone=phone)
