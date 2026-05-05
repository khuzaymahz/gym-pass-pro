from __future__ import annotations

from datetime import UTC, datetime, timedelta


def utcnow() -> datetime:
    return datetime.now(UTC)


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
