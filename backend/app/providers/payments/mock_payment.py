from __future__ import annotations

import asyncio
from decimal import Decimal
from uuid import uuid4

from app.providers.payments import PaymentResult


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
