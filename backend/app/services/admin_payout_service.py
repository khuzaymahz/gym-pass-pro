from __future__ import annotations

from datetime import date
from decimal import Decimal
from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import PayoutStatus
from app.db.models import Gym, Payout
from app.realtime import publish as realtime_publish
from app.repositories.payout_repo import PayoutLedgerRepository, PayoutRepository
from app.repositories.gym_repo import GymRepository
from app.services.audit_service import Actor, AuditService
from app.utils.time import utcnow


class AdminPayoutService:
    """Aggregates pending payout ledger entries into per-gym `Payout` rows.

    Only ledger rows not already attached to a payout (payout_id IS NULL)
    are considered — which prevents double-counting when the admin runs the
    generator multiple times. A payout row is created per gym that has
    entries in the period.
    """

    def __init__(
        self,
        payouts: PayoutRepository,
        ledger: PayoutLedgerRepository,
        gyms: GymRepository,
        audit: AuditService,
    ) -> None:
        self.payouts = payouts
        self.ledger = ledger
        self.gyms = gyms
        self.audit = audit

    async def list(
        self,
        *,
        status: PayoutStatus | None,
        gym_id: UUID | None,
        page: int,
        page_size: int,
    ) -> tuple[list[tuple[Payout, Gym]], int]:
        return await self.payouts.list_paginated(
            status=status, gym_id=gym_id, page=page, page_size=page_size
        )

    async def generate(
        self, *, period_start: date, period_end: date, actor: Actor
    ) -> list[Payout]:
        if period_start > period_end:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "period_start must be on or before period_end.",
            )
        buckets = await self.ledger.aggregate_for_period(
            period_start=period_start, period_end=period_end
        )
        created: list[Payout] = []
        for gym_id, total, entries in buckets:
            payout = await self.payouts.create(
                gym_id=gym_id,
                period_start=period_start,
                period_end=period_end,
                total_amount_jod=total,
                entry_count=entries,
            )
            await self.ledger.attach_ledger_to_payout(
                gym_id=gym_id,
                period_start=period_start,
                period_end=period_end,
                payout_id=payout.id,
            )
            await self.audit.log(
                actor=actor,
                action="payout.create",
                entity_type="payout",
                entity_id=payout.id,
                diff={
                    "after": {
                        "gym_id": str(gym_id),
                        "period_start": period_start.isoformat(),
                        "period_end": period_end.isoformat(),
                        "total": str(total),
                        "entries": entries,
                    }
                },
            )
            created.append(payout)
        return created

    async def mark_paid(
        self, payout_id: UUID, *, notes: str | None, actor: Actor
    ) -> Payout:
        payout = await self.payouts.get(payout_id)
        if payout is None:
            raise AppError(ErrorCode.NOT_FOUND, "Payout not found.")
        if payout.status == PayoutStatus.PAID:
            return payout
        await self.payouts.mark_paid(payout, now=utcnow(), notes=notes)
        await self.audit.log(
            actor=actor,
            action="payout.mark_paid",
            entity_type="payout",
            entity_id=payout.id,
            diff={"after": {"notes": notes}},
        )
        # Live fan-out — partner dashboard's payouts list re-fetches
        # so the row flips from "Pending" to "Paid" without a manual
        # reload. `partner/<gym_id>` is where partners listen (vs
        # `user/<user_id>`) so the event shape matches the rest of
        # the partner-only stream.
        await realtime_publish(
            f"partner/{payout.gym_id}",
            {
                "type": "payout.paid",
                "payoutId": str(payout.id),
                "gymId": str(payout.gym_id),
            },
        )
        return payout

    async def pending_total(self) -> Decimal:
        return await self.payouts.pending_total()
