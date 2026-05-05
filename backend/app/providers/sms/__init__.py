from __future__ import annotations

from typing import Protocol


class SmsProvider(Protocol):
    async def send_otp(self, phone: str, code: str) -> None: ...


def build_sms_provider() -> SmsProvider:
    from app.config import get_settings

    settings = get_settings()
    if settings.sms_provider == "mock":
        from app.providers.sms.mock_sms import MockSmsProvider

        return MockSmsProvider()
    raise RuntimeError(f"SMS provider not yet implemented: {settings.sms_provider}")
