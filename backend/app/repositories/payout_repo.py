from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import PayoutStatus
from app.db.models import Gym, Payout, PayoutLedger
from app.utils.ids import uuid7


class PayoutLedgerRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def record(
        self,
        *,
        gym_id: UUID,
        checkin_id: UUID,
        rate: Decimal,
    ) -> PayoutLedger:
        row = PayoutLedger(
            id=uuid7(),
            gym_id=gym_id,
            checkin_id=checkin_id,
            amount_jod=rate,
            rate_applied=rate,
        )
        self.session.add(row)
        await self.session.flush()
        return row

    async def unpaid_sum(self) -> Decimal:
        stmt = select(func.coalesce(func.sum(PayoutLedger.amount_jod), 0)).where(
            PayoutLedger.payout_id.is_(None)
        )
        return Decimal(str((await self.session.execute(stmt)).scalar_one()))

    async def sum_for_gym_since(
        self, gym_id: UUID, *, since: datetime
    ) -> Decimal:
        """Total ledger amount accrued by `gym_id` since `since`. Used
        by partner metrics to surface "what we owe you" earned on
        successful checkins regardless of payout aggregation state."""
        stmt = (
            select(func.coalesce(func.sum(PayoutLedger.amount_jod), 0))
            .where(
                PayoutLedger.gym_id == gym_id,
                PayoutLedger.created_at >= since,
            )
        )
        return Decimal(str((await self.session.execute(stmt)).scalar_one()))

    async def sum_per_day_for_gym_since(
        self, gym_id: UUID, *, since: datetime
    ) -> list[tuple[str, Decimal]]:
        stmt = (
            select(
                func.date_trunc("day", PayoutLedger.created_at).label("day"),
                func.coalesce(func.sum(PayoutLedger.amount_jod), 0),
            )
            .where(
                PayoutLedger.gym_id == gym_id,
                PayoutLedger.created_at >= since,
            )
            .group_by("day")
            .order_by("day")
        )
        rows = (await self.session.execute(stmt)).all()
        return [(d.date().isoformat(), Decimal(str(t))) for d, t in rows]

    async def aggregate_for_period(
        self, *, period_start: date, period_end: date
    ) -> list[tuple[UUID, Decimal, int]]:
        stmt = (
            select(
                PayoutLedger.gym_id,
                func.coalesce(func.sum(PayoutLedger.amount_jod), 0).label("total"),
                func.count().label("entries"),
            )
            .where(
                PayoutLedger.payout_id.is_(None),
                PayoutLedger.created_at >= _start_of_day(period_start),
                PayoutLedger.created_at < _start_of_day_after(period_end),
            )
            .group_by(PayoutLedger.gym_id)
        )
        rows = (await self.session.execute(stmt)).all()
        return [(gym_id, Decimal(str(total)), int(entries)) for gym_id, total, entries in rows]

    async def attach_ledger_to_payout(
        self, *, gym_id: UUID, period_start: date, period_end: date, payout_id: UUID
    ) -> int:
        stmt = (
            update(PayoutLedger)
            .where(
                PayoutLedger.gym_id == gym_id,
                PayoutLedger.payout_id.is_(None),
                PayoutLedger.created_at >= _start_of_day(period_start),
                PayoutLedger.created_at < _start_of_day_after(period_end),
            )
            .values(payout_id=payout_id)
        )
        result = await self.session.execute(stmt)
        return int(result.rowcount or 0)


class PayoutRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, payout_id: UUID) -> Payout | None:
        return await self.session.get(Payout, payout_id)

    async def create(
        self,
        *,
        gym_id: UUID,
        period_start: date,
        period_end: date,
        total_amount_jod: Decimal,
        entry_count: int,
    ) -> Payout:
        row = Payout(
            id=uuid7(),
            gym_id=gym_id,
            period_start=period_start,
            period_end=period_end,
            total_amount_jod=total_amount_jod,
            entry_count=entry_count,
            status=PayoutStatus.PENDING,
        )
        self.session.add(row)
        await self.session.flush()
        return row

    async def mark_paid(self, payout: Payout, *, now: datetime, notes: str | None) -> None:
        payout.status = PayoutStatus.PAID
        payout.paid_at = now
        if notes is not None:
            payout.notes = notes
        await self.session.flush()

    async def list_paginated(
        self,
        *,
        status: PayoutStatus | None = None,
        gym_id: UUID | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[tuple[Payout, Gym]], int]:
        conditions: list = []
        if status is not None:
            conditions.append(Payout.status == status)
        if gym_id is not None:
            conditions.append(Payout.gym_id == gym_id)

        count_stmt = select(func.count()).select_from(Payout)
        if conditions:
            count_stmt = count_stmt.where(*conditions)
        total = (await self.session.execute(count_stmt)).scalar_one()

        stmt = select(Payout, Gym).join(Gym, Gym.id == Payout.gym_id)
        if conditions:
            stmt = stmt.where(*conditions)
        stmt = (
            stmt.order_by(Payout.period_end.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.session.execute(stmt)).all()
        return [(p, g) for p, g in rows], int(total)

    async def pending_total(self) -> Decimal:
        stmt = select(func.coalesce(func.sum(Payout.total_amount_jod), 0)).where(
            Payout.status == PayoutStatus.PENDING
        )
        return Decimal(str((await self.session.execute(stmt)).scalar_one()))

    async def pending_total_for_gym(self, gym_id: UUID) -> Decimal:
        stmt = (
            select(func.coalesce(func.sum(Payout.total_amount_jod), 0))
            .where(
                Payout.gym_id == gym_id,
                Payout.status == PayoutStatus.PENDING,
            )
        )
        return Decimal(str((await self.session.execute(stmt)).scalar_one()))

    async def paid_total_for_gym_since(
        self, gym_id: UUID, *, since: datetime
    ) -> Decimal:
        stmt = (
            select(func.coalesce(func.sum(Payout.total_amount_jod), 0))
            .where(
                Payout.gym_id == gym_id,
                Payout.status == PayoutStatus.PAID,
                Payout.paid_at >= since,
            )
        )
        return Decimal(str((await self.session.execute(stmt)).scalar_one()))


def _start_of_day(d: date) -> datetime:
    from datetime import datetime, time, timezone

    return datetime.combine(d, time.min).replace(tzinfo=timezone.utc)


def _start_of_day_after(d: date) -> datetime:
    from datetime import datetime, time, timedelta, timezone

    return datetime.combine(d + timedelta(days=1), time.min).replace(tzinfo=timezone.utc)
