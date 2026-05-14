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

    async def overview(
        self,
        gym_id: UUID,
        *,
        since: datetime | None = None,
        until: datetime | None = None,
    ) -> dict[str, Any]:
        """Aggregate dashboard metrics for the given window.

        When ``since`` is omitted, defaults to the start of the
        current calendar month (preserves the legacy "MTD" behaviour).
        When ``until`` is omitted, runs to "now". The "today" tile
        and the "pending payout" tile are always anchored to the
        current moment regardless of the window — they answer
        questions about the present, not the period.
        """
        now = datetime.now(UTC)
        start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        if since is None:
            since = start_of_today.replace(day=1)
        if until is None:
            until = now

        checkins_today = await self.checkins.count_success_for_gym_since(
            gym_id, start_of_today
        )
        checkins_period = await self.checkins.count_success_for_gym_since(
            gym_id, since
        )

        unique_members_period = (
            await self.checkins.count_unique_members_for_gym_since(gym_id, since)
        )

        # Sum of per-visit payouts earned by this gym in the period —
        # this is "what we owe you" from a successful-checkin standpoint,
        # regardless of whether a Payout aggregation has been generated.
        revenue_period = await self.ledger.sum_for_gym_since(
            gym_id, since=since
        )
        pending_payout_total = await self.payouts.pending_total_for_gym(gym_id)
        paid_payout_period = await self.payouts.paid_total_for_gym_since(
            gym_id, since=since
        )

        checkins_per_day = await self.checkins.count_per_day_for_gym_since(
            gym_id, since
        )
        revenue_per_day = await self.ledger.sum_per_day_for_gym_since(
            gym_id, since=since
        )
        tier_breakdown = await self.checkins.tier_breakdown_for_gym_since(
            gym_id, since
        )
        hour_breakdown = await self.checkins.hour_breakdown_for_gym_since(
            gym_id, since
        )
        recent_checkins = await self.checkins.recent_with_user_for_gym(
            gym_id, limit=10
        )

        # Wire field names stay backwards-compatible — fields named
        # `*Mtd*` and `Last30Days` now reflect the chosen window. The
        # partner UI displays them with a label that swaps to match
        # the period selection, so the suffix is just a stable JSON
        # key, not a semantic claim about "this month".
        return {
            "checkinsToday": checkins_today,
            "checkinsThisMonth": checkins_period,
            "checkinsLast30Days": checkins_period,
            "uniqueMembersLast30Days": unique_members_period,
            "revenueMtdJod": revenue_period,
            "pendingPayoutTotalJod": pending_payout_total,
            "paidPayoutMtdJod": paid_payout_period,
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
