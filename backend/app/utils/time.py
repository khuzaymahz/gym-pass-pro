from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

# Jordan operates on UTC+3 year-round (no DST since 2022). All member-
# facing date math (pause windows, day-pass daily caps, partner
# dashboard "today") should anchor here, not UTC — the previous code
# used UTC `today.date()` and rolled over at 03:00 local, so a pause
# whose `ends_on` was today (local) blocked check-ins until 03:00 the
# next morning local time.
AMMAN = ZoneInfo("Asia/Amman")


def utcnow() -> datetime:
    return datetime.now(UTC)


def amman_today() -> date:
    """The current calendar date in Asia/Amman. Use this for any
    date-only boundary that a member would describe in their local
    wall-clock — pause windows, day-pass daily caps, partner-dashboard
    "today". Anything that needs an instant (audit timestamps, JWT
    exp, etc.) keeps using `utcnow()`.
    """
    return datetime.now(AMMAN).date()


def amman_day_bounds(d: date) -> tuple[datetime, datetime]:
    """Return the [start, end) UTC instants of an Asia/Amman calendar
    day. Pairs with `amman_today()` for SQL range filters on
    timestamptz columns — let Postgres do the comparison in UTC, but
    have the bounds reflect a local midnight-to-midnight window.
    """
    start_local = datetime(d.year, d.month, d.day, tzinfo=AMMAN)
    end_local = start_local + timedelta(days=1)
    return start_local.astimezone(UTC), end_local.astimezone(UTC)


def add_months(base: datetime, months: int) -> datetime:
    # Approximation sufficient for billing: 30 days per month.
    return base + timedelta(days=30 * months)


def current_period_start(starts_at: datetime, now: datetime) -> datetime:
    """Anchor of the current 30-day billing period for a subscription that
    began at `starts_at`. Used by the check-in service to count "visits
    consumed in the current month" without storing a counter that has to
    be reset by a cron — the value is always derivable from immutable
    timestamps.

    Returns `starts_at` when the subscription is in its first period, and
    walks forward in 30-day steps otherwise. Idempotent and timezone-
    preserving so a subscription that started 2026-01-15T10:00Z always
    rolls over at the same wall time.
    """
    if now <= starts_at:
        return starts_at
    elapsed_days = (now - starts_at).days
    full_periods = elapsed_days // 30
    return starts_at + timedelta(days=30 * full_periods)
