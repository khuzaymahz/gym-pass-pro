from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Any, Literal, Protocol


@dataclass(frozen=True)
class PaymentResult:
    status: Literal["succeeded", "failed"]
    gateway_txn_id: str
    raw: dict[str, Any]


@dataclass(frozen=True)
class RefundResult:
    """Outcome of a refund attempt against the provider.

    `status='succeeded'` means the provider acknowledged the
    reversal. `status='failed'` means the gateway refused (real
    gateways sometimes refuse if the charge is too old, already
    refunded, or the merchant has insufficient funds for a
    chargeback). Callers must persist a compensation-required
    audit entry in either case so ops can reconcile manually.
    """

    status: Literal["succeeded", "failed"]
    refund_txn_id: str | None
    raw: dict[str, Any]


class PaymentProvider(Protocol):
    async def charge(
        self, *, amount_jod: Decimal, method: str, idempotency_key: str
    ) -> PaymentResult: ...

    async def refund(
        self,
        *,
        gateway_txn_id: str,
        amount_jod: Decimal,
        idempotency_key: str,
    ) -> RefundResult:
        """Reverse a previously-succeeded charge.

        Used by services when post-charge activation fails (DB
        constraint hits, audit-log write fails, etc.) — money has
        already left the member; we must put it back. Idempotency
        key is the originating mutation's id (subscription / day-
        pass) prefixed with `refund:`, so a retried refund call
        doesn't double-credit.
        """
        ...


def build_payment_provider() -> PaymentProvider:
    from app.config import get_settings

    settings = get_settings()
    if settings.payment_provider == "mock":
        from app.providers.payments.mock_payment import MockPaymentProvider

        return MockPaymentProvider(delay_ms=settings.payment_mock_delay_ms)
    raise RuntimeError(f"Payment provider not yet implemented: {settings.payment_provider}")
