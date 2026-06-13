from __future__ import annotations

import asyncio
from decimal import Decimal
from uuid import uuid4

from app.providers.payments import PaymentResult, RefundResult


class MockPaymentProvider:
    def __init__(self, delay_ms: int = 0) -> None:
        self._delay_s = max(0, delay_ms) / 1000.0

    async def charge(
        self, *, amount_jod: Decimal, method: str, idempotency_key: str
    ) -> PaymentResult:
        if self._delay_s:
            await asyncio.sleep(self._delay_s)
        # Always succeed in dev; declined flow can be tested by passing a
        # magic idempotency_key="decline" — keeps the mock usable in tests.
        if idempotency_key == "decline":
            return PaymentResult(
                status="failed",
                gateway_txn_id=f"mock-{uuid4()}",
                raw={"mock": True, "reason": "declined"},
            )
        return PaymentResult(
            status="succeeded",
            gateway_txn_id=f"mock-{uuid4()}",
            raw={"mock": True, "amount": str(amount_jod), "method": method},
        )

    async def refund(
        self,
        *,
        gateway_txn_id: str,
        amount_jod: Decimal,
        idempotency_key: str,
    ) -> RefundResult:
        if self._delay_s:
            await asyncio.sleep(self._delay_s)
        # `refund-decline` magic key lets tests exercise the
        # "money charged AND refund refused" worst case so we
        # can verify the audit trail records both events.
        if idempotency_key.endswith(":decline"):
            return RefundResult(
                status="failed",
                refund_txn_id=None,
                raw={"mock": True, "reason": "refund_declined"},
            )
        return RefundResult(
            status="succeeded",
            refund_txn_id=f"mock-refund-{uuid4()}",
            raw={
                "mock": True,
                "amount": str(amount_jod),
                "original_txn": gateway_txn_id,
            },
        )
