from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Any
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import CheckinStatus, PayoutStatus, SubscriptionStatus
from app.db.models import Checkin, Payout, PayoutLedger, Subscription, User


class PartnerMetricsService:
    """Per-gym aggregates for the partner dashboard.

    Every query is scoped on `gym_id` so the same backend can serve
    many partners without leakage. We deliberately skip caching here
    for the same reason as admin metrics — partners want to see the
    numbers move in real time when they walk a member in for a scan.
    """

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def overview(self, gym_id: UUID) -> dict[str, Any]:
        now = datetime.now(timezone.utc)
        start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        start_of_month = start_of_today.replace(day=1)
        thirty_days_ago = start_of_today - timedelta(days=29)

        checkins_today = await self._count_success(gym_id, since=start_of_today)
        checkins_mtd = await self._count_success(gym_id, since=start_of_month)
        checkins_30 = await self._count_success(gym_id, since=thirty_days_ago)

        unique_members_30 = await self._unique_members(
            gym_id, since=thirty_days_ago
        )

        revenue_mtd = await self._success_payout_sum(gym_id, since=start_of_month)
        pending_payout_total = await self._pending_payout_total(gym_id)
        paid_payout_mtd = await self._paid_payout_total(gym_id, since=start_of_month)

        checkins_per_day = await self._checkins_per_day_since(
            gym_id, since=thirty_days_ago
        )
        revenue_per_day = await self._revenue_per_day_since(
            gym_id, since=thirty_days_ago
        )
        tier_breakdown = await self._tier_breakdown(gym_id, since=thirty_days_ago)
        hour_breakdown = await self._hour_breakdown(gym_id, since=thirty_days_ago)
        recent_checkins = await self._recent_checkins(gym_id, limit=10)

        return {
            "checkinsToday": checkins_today,
            "checkinsThisMonth": checkins_mtd,
            "checkinsLast30Days": checkins_30,
            "uniqueMembersLast30Days": unique_members_30,
            "revenueMtdJod": revenue_mtd,
            "pendingPayoutTotalJod": pending_payout_total,
            "paidPayoutMtdJod": paid_payout_mtd,
            "checkinsPerDay": [
                {"day": d, "count": c} for d, c in checkins_per_day
            ],
            "revenuePerDay": [
                {"day": d, "total": str(t)} for d, t in revenue_per_day
            ],
            "tierBreakdown": tier_breakdown,
            "hourBreakdown": [
                {"hour": h, "count": c} for h, c in hour_breakdown
            ],
            "recentCheckins": recent_checkins,
        }

    # ----- private helpers -----

    async def _count_success(self, gym_id: UUID, *, since: datetime) -> int:
        stmt = (
            select(func.count())
            .select_from(Checkin)
            .where(
                Checkin.gym_id == gym_id,
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
            )
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def _unique_members(self, gym_id: UUID, *, since: datetime) -> int:
        stmt = (
            select(func.count(func.distinct(Checkin.user_id)))
            .where(
                Checkin.gym_id == gym_id,
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
            )
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def _success_payout_sum(
        self, gym_id: UUID, *, since: datetime
    ) -> Decimal:
        # Sum of per-visit payouts earned by this gym in the period —
        # this is "what we owe you" from a successful-checkin standpoint,
        # regardless of whether a Payout aggregation has been generated.
        stmt = (
            select(func.coalesce(func.sum(PayoutLedger.amount_jod), 0))
            .where(
                PayoutLedger.gym_id == gym_id,
                PayoutLedger.created_at >= since,
            )
        )
        return Decimal(str((await self.session.execute(stmt)).scalar_one()))

    async def _pending_payout_total(self, gym_id: UUID) -> Decimal:
        stmt = (
            select(func.coalesce(func.sum(Payout.total_amount_jod), 0))
            .where(
                Payout.gym_id == gym_id,
                Payout.status == PayoutStatus.PENDING,
            )
        )
        return Decimal(str((await self.session.execute(stmt)).scalar_one()))

    async def _paid_payout_total(
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

    async def _checkins_per_day_since(
        self, gym_id: UUID, *, since: datetime
    ) -> list[tuple[str, int]]:
        stmt = (
            select(
                func.date_trunc("day", Checkin.scanned_at).label("day"),
                func.count(),
            )
            .where(
                Checkin.gym_id == gym_id,
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
            )
            .group_by("day")
            .order_by("day")
        )
        rows = (await self.session.execute(stmt)).all()
        return [(d.date().isoformat(), int(c)) for d, c in rows]

    async def _revenue_per_day_since(
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

    async def _tier_breakdown(
        self, gym_id: UUID, *, since: datetime
    ) -> dict[str, int]:
        # Subscription tier captured at scan time = subscription on the
        # checkin row. Members on a paused subscription with a
        # scheduled tier-down don't get scanned through anyway, so the
        # tier here is the active one. NULL subscription_id means a
        # failed scan; we filter to success-only above.
        stmt = (
            select(Subscription.tier, func.count(Checkin.id))
            .join(Subscription, Subscription.id == Checkin.subscription_id)
            .where(
                Checkin.gym_id == gym_id,
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
            )
            .group_by(Subscription.tier)
        )
        rows = (await self.session.execute(stmt)).all()
        return {tier.value: int(count) for tier, count in rows}

    async def _hour_breakdown(
        self, gym_id: UUID, *, since: datetime
    ) -> list[tuple[int, int]]:
        # Per-hour-of-day distribution so partners can see when their
        # busy windows are. UTC-bucketed; partner-side renders as local
        # by adding the +03 offset (Jordan is UTC+3 year-round, no DST).
        stmt = (
            select(
                func.extract("hour", Checkin.scanned_at).label("hour"),
                func.count(),
            )
            .where(
                Checkin.gym_id == gym_id,
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
            )
            .group_by("hour")
            .order_by("hour")
        )
        rows = (await self.session.execute(stmt)).all()
        return [(int(h), int(c)) for h, c in rows]

    async def _recent_checkins(
        self, gym_id: UUID, *, limit: int
    ) -> list[dict[str, Any]]:
        stmt = (
            select(Checkin, User)
            .join(User, User.id == Checkin.user_id)
            .where(
                Checkin.gym_id == gym_id,
                Checkin.status == CheckinStatus.SUCCESS,
            )
            .order_by(Checkin.scanned_at.desc())
            .limit(limit)
        )
        rows = (await self.session.execute(stmt)).all()
        return [
            {
                "id": str(c.id),
                "userId": str(u.id),
                "userName": u.name or u.first_name or None,
                "scannedAt": c.scanned_at.isoformat(),
            }
            for c, u in rows
        ]
