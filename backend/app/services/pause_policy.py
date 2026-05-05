"""Pause-allowance policy for subscriptions.

Tiers and durations have different pause allowances. A 1- or 3-month plan
gets nothing (pause is a long-commitment perk); 6-month plans get one
contiguous block; 12-month plans get a per-tier pool that can be split
across two pauses. Mirrored verbatim from the mobile catalog so the
preview the user saw on /plans matches the limit the backend enforces.

Kept as a pure-function module rather than a service class because the
policy is a value, not a behavior — the only state it touches is the
plan's `(tier, duration_months)` tuple.
"""

from __future__ import annotations

from app.db.enums import Tier


def pause_allowance_days(tier: Tier, duration_months: int) -> int:
    """Maximum total pause days a `(tier, duration)` plan grants.

    Returns zero for plans that don't include pause (1-month, 3-month).
    For 6-month plans the allowance is the whole single pause; for
    12-month plans it's the pool that can be split across `max_pauses`
    distinct windows.
    """
    if duration_months == 6:
        match tier:
            case Tier.SILVER:
                return 10
            case Tier.GOLD:
                return 12
            case Tier.PLATINUM:
                return 14
            case Tier.DIAMOND:
                return 16
    if duration_months == 12:
        match tier:
            case Tier.SILVER:
                return 24
            case Tier.GOLD:
                return 26
            case Tier.PLATINUM:
                return 28
            case Tier.DIAMOND:
                return 30
    return 0


def max_pauses(duration_months: int) -> int:
    """Number of separate pause windows allowed on the term. 12-month
    plans split their allowance across two; 6-month plans get one
    contiguous block; shorter plans get nothing."""
    if duration_months == 12:
        return 2
    if duration_months == 6:
        return 1
    return 0


__all__ = ["max_pauses", "pause_allowance_days"]
