from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import date
from decimal import Decimal
from typing import TYPE_CHECKING
from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import PayoutStatus
from app.db.models import Gym, Payout
from app.realtime import publish as realtime_publish
from app.repositories.payout_repo import PayoutLedgerRepository, PayoutRepository
from app.repositories.gym_repo import GymRepository
from app.services.audit_service import Actor, AuditService
from app.utils.time import utcnow

if TYPE_CHECKING:
    from redis.asyncio import Redis


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
        redis: "Redis | None" = None,
    ) -> None:
        self.payouts = payouts
        self.ledger = ledger
        self.gyms = gyms
        self.audit = audit
        self.redis = redis

    @asynccontextmanager
    async def _generate_lock(self, period_start: date, period_end: date):
        """Redis-backed mutual-exclusion lock for `generate`.

        Without this, two admins clicking Generate concurrently both call
        `aggregate_for_period` before either runs `attach_ledger_to_payout`,
        creating duplicate Payout rows for the same gym (one of which
        carries the real amount, the other zero — the second `attach`
        finds the ledger rows already taken). Per-period key so distinct
        windows never block each other.
        """
        if self.redis is None:
            yield
            return
        key = (
            f"admin:payout:generate:"
            f"{period_start.isoformat()}:{period_end.isoformat()}"
        )
        # 10-minute lock — generation is fast but the aggregation can
        # take seconds on a big window; this leaves comfortable head-
        # room while ensuring a crashed worker doesn't leave the lock
        # held forever.
        acquired = await self.redis.set(key, "1", nx=True, ex=600)
        if not acquired:
            raise AppError(
                ErrorCode.RATE_LIMITED,
                "A payout generation is already in progress for this "
                "period. Retry in a moment.",
            )
        try:
            yield
        finally:
            try:
                await self.redis.delete(key)
            except Exception:  # noqa: BLE001 — lock TTL is the backstop
                pass

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
        # Cap the window so an off-by-typo "2026-01-01..2099-12-31" can't
        # be processed in one shot. 31 days is the largest legitimate
        # monthly window; quarterly batches must be split.
        if (period_end - period_start).days > 31:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Payout window cannot exceed 31 days.",
            )
        async with self._generate_lock(period_start, period_end):
            return await self._generate_inner(
                period_start=period_start,
                period_end=period_end,
                actor=actor,
            )

    async def _generate_inner(
        self, *, period_start: date, period_end: date, actor: Actor
    ) -> list[Payout]:
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
    ) -> tuple[Payout, Gym]:
        """Return the (payout, gym) pair so the admin response can render
        the gym name without a second fetch. Idempotent for already-paid
        payouts (returns the existing state)."""
        payout = await self.payouts.get(payout_id)
        if payout is None:
            raise AppError(ErrorCode.NOT_FOUND, "Payout not found.")
        gym = await self.gyms.get(payout.gym_id)
        if gym is None:
            raise AppError(ErrorCode.NOT_FOUND, "Gym not found.")
        if payout.status == PayoutStatus.PAID:
            return payout, gym
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
        return payout, gym

    async def pending_total(self) -> Decimal:
        return await self.payouts.pending_total()

    async def get_with_gym(self, payout_id: UUID) -> tuple[Payout, Gym]:
        """Fetch a single payout joined to its gym for the admin
        detail page. Raises 404 cleanly if either is missing —
        cheaper than papering over with a redirect to the list.
        """
        payout = await self.payouts.get(payout_id)
        if payout is None:
            raise AppError(ErrorCode.NOT_FOUND, "Payout not found.")
        gym = await self.gyms.get(payout.gym_id)
        if gym is None:
            # Should be impossible given the FK, but the operator
            # gets a clear error rather than a partial render.
            raise AppError(ErrorCode.NOT_FOUND, "Gym not found.")
        return payout, gym

    async def list_entries(
        self, payout_id: UUID, *, limit: int = 200, offset: int = 0
    ):
        """Constituent ledger entries for the drill-down view —
        the admin's reconciliation lens onto a payout. Paginated to
        protect against very large month-long payouts on busy gyms.
        Returns (rows, total).
        """
        return await self.ledger.list_for_payout(
            payout_id, limit=limit, offset=offset
        )
