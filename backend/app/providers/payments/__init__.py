from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Any, Literal, Protocol


@dataclass(frozen=True)
class PaymentResult:
    status: Literal["succeeded", "failed"]
    gateway_txn_id: str
    raw: dict[str, Any]


class PaymentProvider(Protocol):
    async def charge(
        self, *, amount_jod: Decimal, method: str, idempotency_key: str
    ) -> PaymentResult: ...


def build_payment_provider() -> PaymentProvider:
    from app.config import get_settings

    settings = get_settings()
    if settings.payment_provider == "mock":
        from app.providers.payments.mock_payment import MockPaymentProvider

        return MockPaymentProvider(delay_ms=settings.payment_mock_delay_ms)
    raise RuntimeError(f"Payment provider not yet implemented: {settings.payment_provider}")
