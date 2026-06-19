from __future__ import annotations

import asyncio
from decimal import Decimal
from uuid import uuid4

from app.providers.payments import PaymentResult, RefundResult


class MockPaymentProvider:
    """In-memory mock of a real payment gateway.

    The `_charges` / `_refunds` dicts give the mock **real idempotency
    replay** — calling `charge(idempotency_key="X")` twice returns the
    same `PaymentResult` (same `gateway_txn_id`, same status, same raw
    payload). A real PSP behaves this way; without the cache the mock
    minted a fresh txn id every call, so the subscription saga's retry
    path was never exercised in tests and an in-the-wild retry would
    have double-charged the member.

    Magic `idempotency_key` values exercise failure modes the saga
    needs to handle:
      - `decline`              → `status='failed'` on charge
      - `*:decline` suffix     → `status='failed'` on refund
      - `timeout`              → raises `asyncio.TimeoutError`
      - `network`              → raises `OSError("network unreachable")`
    """

    def __init__(self, delay_ms: int = 0) -> None:
        self._delay_s = max(0, delay_ms) / 1000.0
        self._charges: dict[str, PaymentResult] = {}
        self._refunds: dict[str, RefundResult] = {}

    async def charge(
        self, *, amount_jod: Decimal, method: str, idempotency_key: str
    ) -> PaymentResult:
        if self._delay_s:
            await asyncio.sleep(self._delay_s)

        if idempotency_key == "timeout":
            raise asyncio.TimeoutError("mock payment provider: timeout")
        if idempotency_key == "network":
            raise OSError("mock payment provider: network unreachable")

        cached = self._charges.get(idempotency_key)
        if cached is not None:
            return cached

        if idempotency_key == "decline":
            result = PaymentResult(
                status="failed",
                gateway_txn_id=f"mock-{uuid4()}",
                raw={"mock": True, "reason": "declined"},
            )
        else:
            result = PaymentResult(
                status="succeeded",
                gateway_txn_id=f"mock-{uuid4()}",
                raw={
                    "mock": True,
                    "amount": str(amount_jod),
                    "method": method,
                },
            )
        self._charges[idempotency_key] = result
        return result

    async def refund(
        self,
        *,
        gateway_txn_id: str,
        amount_jod: Decimal,
        idempotency_key: str,
    ) -> RefundResult:
        if self._delay_s:
            await asyncio.sleep(self._delay_s)

        cached = self._refunds.get(idempotency_key)
        if cached is not None:
            return cached

        if idempotency_key.endswith(":decline"):
            result = RefundResult(
                status="failed",
                refund_txn_id=None,
                raw={"mock": True, "reason": "refund_declined"},
            )
        else:
            result = RefundResult(
                status="succeeded",
                refund_txn_id=f"mock-refund-{uuid4()}",
                raw={
                    "mock": True,
                    "amount": str(amount_jod),
                    "original_txn": gateway_txn_id,
                },
            )
        self._refunds[idempotency_key] = result
        return result
