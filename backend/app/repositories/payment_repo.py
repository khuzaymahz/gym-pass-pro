from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import PaymentMethod, PaymentStatus
from app.db.models import Payment, Subscription
from app.utils.ids import uuid7


class PaymentRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        subscription_id: UUID,
        amount_jod: Decimal,
        method: PaymentMethod,
        gateway_txn_id: str | None,
        status: PaymentStatus,
        raw_response: dict[str, Any],
        processed_at: datetime | None,
    ) -> Payment:
        payment = Payment(
            id=uuid7(),
            subscription_id=subscription_id,
            amount_jod=amount_jod,
            method=method,
            gateway_txn_id=gateway_txn_id,
            status=status,
            raw_response=raw_response,
            processed_at=processed_at,
        )
        self.session.add(payment)
        await self.session.flush()
        return payment

    async def list_for_user(
        self, user_id: UUID, *, limit: int = 50
    ) -> list[tuple[Payment, Subscription]]:
        """Return the user's payments newest-first joined with the
        subscription they paid for. Used by `GET /me/invoices` so the
        mobile invoice ledger can render `tier`, `period`, and
        `amount` from the same row without a second round trip."""
        stmt = (
            select(Payment, Subscription)
            .join(Subscription, Subscription.id == Payment.subscription_id)
            .where(Subscription.user_id == user_id)
            .order_by(Payment.created_at.desc())
            .limit(limit)
        )
        rows = (await self.session.execute(stmt)).all()
        return [(p, s) for p, s in rows]
