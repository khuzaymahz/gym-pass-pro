from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

from app.repositories.checkin_repo import CheckinRepository
from app.repositories.payout_repo import PayoutLedgerRepository, PayoutRepository


class PartnerMetricsService:
    """Per-gym aggregates for the partner dashboard.

    Every query is scoped on `gym_id` so the same backend can serve
    many partners without leakage. We deliberately skip caching here
    for the same reason as admin metrics — partners want to see the
    numbers move in real time when they walk a member in for a scan.
    """

    def __init__(
        self,
        checkins: CheckinRepository,
        ledger: PayoutLedgerRepository,
        payouts: PayoutRepository,
    ) -> None:
        self.checkins = checkins
        self.ledger = ledger
        self.payouts = payouts

    async def overview(self, gym_id: UUID) -> dict[str, Any]:
        now = datetime.now(UTC)
        start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        start_of_month = start_of_today.replace(day=1)
        thirty_days_ago = start_of_today - timedelta(days=29)

        checkins_today = await self.checkins.count_success_for_gym_since(
            gym_id, start_of_today
        )
        checkins_mtd = await self.checkins.count_success_for_gym_since(
            gym_id, start_of_month
        )
        checkins_30 = await self.checkins.count_success_for_gym_since(
            gym_id, thirty_days_ago
        )

        unique_members_30 = await self.checkins.count_unique_members_for_gym_since(
            gym_id, thirty_days_ago
        )

        # Sum of per-visit payouts earned by this gym in the period —
        # this is "what we owe you" from a successful-checkin standpoint,
        # regardless of whether a Payout aggregation has been generated.
        revenue_mtd = await self.ledger.sum_for_gym_since(
            gym_id, since=start_of_month
        )
        pending_payout_total = await self.payouts.pending_total_for_gym(gym_id)
        paid_payout_mtd = await self.payouts.paid_total_for_gym_since(
            gym_id, since=start_of_month
        )

        checkins_per_day = await self.checkins.count_per_day_for_gym_since(
            gym_id, thirty_days_ago
        )
        revenue_per_day = await self.ledger.sum_per_day_for_gym_since(
            gym_id, since=thirty_days_ago
        )
        # Subscription tier captured at scan time = subscription on the
        # checkin row. Members on a paused subscription with a
        # scheduled tier-down don't get scanned through anyway, so the
        # tier here is the active one. NULL subscription_id means a
        # failed scan; the repo helper filters to success-only.
        tier_breakdown = await self.checkins.tier_breakdown_for_gym_since(
            gym_id, thirty_days_ago
        )
        # Per-hour-of-day distribution so partners can see when their
        # busy windows are. UTC-bucketed; partner-side renders as local
        # by adding the +03 offset (Jordan is UTC+3 year-round, no DST).
        hour_breakdown = await self.checkins.hour_breakdown_for_gym_since(
            gym_id, thirty_days_ago
        )
        recent_checkins = await self.checkins.recent_with_user_for_gym(
            gym_id, limit=10
        )

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


__all__ = ["PartnerMetricsService"]
