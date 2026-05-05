from __future__ import annotations

from datetime import UTC, datetime, timedelta

from app.utils.time import current_period_start


def _utc(*args: int) -> datetime:
    return datetime(*args, tzinfo=UTC)


def test_current_period_start_returns_starts_at_in_first_period():
    starts_at = _utc(2026, 1, 15, 10)
    now = starts_at + timedelta(days=12)
    assert current_period_start(starts_at, now) == starts_at


def test_current_period_start_rolls_over_at_30_days():
    starts_at = _utc(2026, 1, 15, 10)
    # Day 30 has not rolled yet — still period 0.
    just_under = starts_at + timedelta(days=29, hours=23)
    assert current_period_start(starts_at, just_under) == starts_at
    # Day 30 begins the second period.
    rollover = starts_at + timedelta(days=30)
    assert current_period_start(starts_at, rollover) == rollover


def test_current_period_start_handles_multiple_periods():
    starts_at = _utc(2026, 1, 15, 10)
    in_4th_period = starts_at + timedelta(days=95)  # 3 full periods + 5 days
    expected = starts_at + timedelta(days=90)
    assert current_period_start(starts_at, in_4th_period) == expected


def test_current_period_start_idempotent_at_anchor():
    """The wall time of the period anchor stays stable — a member who
    started at 10:00 UTC sees their next budget reset at 10:00 UTC, not
    drift due to wall-clock minutes during the lookup."""
    starts_at = _utc(2026, 1, 15, 10, 30, 0)
    in_2nd_period = starts_at + timedelta(days=31, minutes=42)
    period = current_period_start(starts_at, in_2nd_period)
    assert period.hour == 10 and period.minute == 30 and period.second == 0


def test_current_period_start_clamps_below_starts_at():
    """Before the subscription begins (clock skew, etc.) the function
    returns `starts_at` rather than something behind the anchor."""
    starts_at = _utc(2026, 1, 15, 10)
    earlier = starts_at - timedelta(hours=1)
    assert current_period_start(starts_at, earlier) == starts_at
