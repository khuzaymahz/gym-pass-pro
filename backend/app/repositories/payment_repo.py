from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import PaymentMethod, PaymentStatus
from app.db.models import Payment, Subscription
from app.utils.ids import uuid7


class PaymentRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, payment_id: UUID) -> Payment | None:
        return await self.session.get(Payment, payment_id)

    async def mark_refunded(
        self,
        payment: Payment,
        *,
        refund_txn_id: str | None,
        raw_refund: dict[str, Any],
        refund_failed: bool,
    ) -> None:
        """Flip a successful payment to REFUNDED (or keep as
        SUCCEEDED with a flag if the refund itself failed).

        Mutates the existing payment row in place — we don't
        write a second sibling row because the financial reality
        is "this payment was reversed", not "two separate
        payments happened". The refund txn id + raw response
        are merged into `raw_response` for reconciliation.

        `refund_failed=True` is the worst case: charge succeeded,
        activation failed, refund attempt also failed. We leave
        the status at SUCCEEDED (because the money DID change
        hands) but stamp the row with the refund attempt detail
        so ops can chase down the manual reversal. The matching
        audit-log entry (written by the calling service) is the
        ops trigger.
        """
        merged = dict(payment.raw_response or {})
        merged["refund"] = {
            "refund_txn_id": refund_txn_id,
            "raw": raw_refund,
            "succeeded": not refund_failed,
        }
        payment.raw_response = merged
        if not refund_failed:
            payment.status = PaymentStatus.REFUNDED
        await self.session.flush()

    async def create(
        self,
        *,
        subscription_id: UUID | None,
        amount_jod: Decimal,
        method: PaymentMethod,
        gateway_txn_id: str | None,
        status: PaymentStatus,
        raw_response: dict[str, Any],
        processed_at: datetime | None,
    ) -> Payment:
        """Create a payment row.

        `subscription_id` may be NULL for day-pass payments; the
        day-pass row carries the back-pointer in that case. For
        subscription purchases it remains the FK that anchors
        `list_for_user` / `history_for_user`.
        """
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

    async def history_for_user(
        self, user_id: UUID, *, limit: int = 100
    ) -> list[tuple[Payment, Subscription]]:
        """Admin user-detail view: the payment ledger for `user_id`.

        Same shape as `list_for_user` but with a different default
        limit so the admin detail page can show a longer trail without
        the mobile invoice list bloating to match.
        """
        stmt = (
            select(Payment, Subscription)
            .join(Subscription, Subscription.id == Payment.subscription_id)
            .where(Subscription.user_id == user_id)
            .order_by(Payment.created_at.desc())
            .limit(limit)
        )
        rows = (await self.session.execute(stmt)).all()
        return [(p, s) for p, s in rows]

    async def sum_succeeded_in_window(
        self, since: datetime, until: datetime | None = None
    ) -> Decimal:
        """Sum of SUCCEEDED payments in [since, until). `until=None` means open."""
        stmt = select(func.coalesce(func.sum(Payment.amount_jod), 0)).where(
            Payment.status == PaymentStatus.SUCCEEDED,
            Payment.created_at >= since,
        )
        if until is not None:
            stmt = stmt.where(Payment.created_at < until)
        return Decimal(str((await self.session.execute(stmt)).scalar_one()))

    async def succeeded_per_day_since(
        self, since: datetime
    ) -> list[tuple[str, Decimal]]:
        """Per-day SUCCEEDED revenue since `since` (inclusive)."""
        stmt = (
            select(
                func.date_trunc("day", Payment.created_at).label("day"),
                func.coalesce(func.sum(Payment.amount_jod), 0),
            )
            .where(
                Payment.status == PaymentStatus.SUCCEEDED,
                Payment.created_at >= since,
            )
            .group_by("day")
            .order_by("day")
        )
        rows = (await self.session.execute(stmt)).all()
        return [(d.date().isoformat(), Decimal(str(t))) for d, t in rows]
