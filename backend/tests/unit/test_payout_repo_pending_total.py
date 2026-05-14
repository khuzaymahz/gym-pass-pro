"""Regression tests for PayoutRepository.pending_total_for_gym.

Before the fix in commit `d5e3bb0`, this method summed the
`payouts` aggregation table — so a gym with ledger rows but no
generated batch returned 0 JOD, even though real money was owed.
The widget label promises "what we owe you," which has to be
ledger-sourced (un-batched rows + batched-but-pending rows).

Tests pin the contract:

1. Ledger rows with NULL payout_id count as pending.
2. Ledger rows attached to a PENDING payout count as pending.
3. Ledger rows attached to a PAID payout do NOT count as pending.
4. The same logic applies globally via pending_total().
"""

from __future__ import annotations

from datetime import date
from decimal import Decimal

import pytest

from app.db.enums import (
    Category,
    CheckinStatus,
    PayoutStatus,
    Role,
    Tier,
)
from app.db.models import Checkin, Gym, Payout, PayoutLedger, User
from app.repositories.payout_repo import PayoutRepository
from app.utils.ids import uuid7


def _gym(slug: str, rate: str = "2.00") -> Gym:
    return Gym(
        id=uuid7(),
        slug=slug,
        name_en=slug,
        name_ar=slug,
        address_en="addr",
        address_ar="addr",
        area="Amman",
        lat=Decimal("31.95"),
        lng=Decimal("35.91"),
        category=Category.GYM,
        required_tier=Tier.SILVER,
        per_visit_rate_jod=Decimal(rate),
    )


def _user(phone: str) -> User:
    return User(
        id=uuid7(),
        phone=phone,
        first_name="Test",
        last_name="Member",
        role=Role.MEMBER,
    )


def _checkin(gym: Gym, user: User) -> Checkin:
    return Checkin(
        id=uuid7(),
        user_id=user.id,
        gym_id=gym.id,
        status=CheckinStatus.SUCCESS,
    )


def _ledger(
    gym: Gym, checkin: Checkin, payout_id=None, amount: str = "2.00"
) -> PayoutLedger:
    return PayoutLedger(
        id=uuid7(),
        gym_id=gym.id,
        checkin_id=checkin.id,
        amount_jod=Decimal(amount),
        rate_applied=Decimal(amount),
        payout_id=payout_id,
    )


def _payout(gym: Gym, status: PayoutStatus, total: str, entries: int) -> Payout:
    return Payout(
        id=uuid7(),
        gym_id=gym.id,
        period_start=date(2026, 4, 1),
        period_end=date(2026, 4, 30),
        total_amount_jod=Decimal(total),
        entry_count=entries,
        status=status,
    )


@pytest.mark.asyncio
async def test_pending_total_for_gym_counts_unbatched_ledger_rows(db):
    """The pre-fix bug: unbundled ledger rows used to show as 0
    because the method summed the `payouts` table instead.
    """
    gym = _gym("pt-unbundled")
    user = _user("+962790000101")
    db.add_all([gym, user])
    await db.flush()

    # 3 successful checkins → 3 ledger rows, all unbundled
    for _ in range(3):
        c = _checkin(gym, user)
        db.add(c)
        await db.flush()
        db.add(_ledger(gym, c, payout_id=None, amount="2.00"))
    await db.flush()

    pending = await PayoutRepository(db).pending_total_for_gym(gym.id)
    assert pending == Decimal("6.00")


@pytest.mark.asyncio
async def test_pending_total_includes_rows_in_pending_payout_batch(db):
    """Rows attached to a still-pending Payout are also owed.
    """
    gym = _gym("pt-pending-batch")
    user = _user("+962790000102")
    db.add_all([gym, user])
    await db.flush()

    pending_payout = _payout(gym, PayoutStatus.PENDING, "4.00", 2)
    db.add(pending_payout)
    await db.flush()

    for _ in range(2):
        c = _checkin(gym, user)
        db.add(c)
        await db.flush()
        db.add(_ledger(gym, c, payout_id=pending_payout.id, amount="2.00"))
    await db.flush()

    pending = await PayoutRepository(db).pending_total_for_gym(gym.id)
    assert pending == Decimal("4.00")


@pytest.mark.asyncio
async def test_pending_total_excludes_rows_in_paid_payout_batch(db):
    """Once a Payout is paid, its ledger rows are settled — they
    must NOT count as pending. This is the only branch the
    pre-fix implementation got right for the wrong reason.
    """
    gym = _gym("pt-paid-batch")
    user = _user("+962790000103")
    db.add_all([gym, user])
    await db.flush()

    paid_payout = _payout(gym, PayoutStatus.PAID, "10.00", 5)
    db.add(paid_payout)
    await db.flush()

    for _ in range(5):
        c = _checkin(gym, user)
        db.add(c)
        await db.flush()
        db.add(_ledger(gym, c, payout_id=paid_payout.id, amount="2.00"))
    await db.flush()

    pending = await PayoutRepository(db).pending_total_for_gym(gym.id)
    assert pending == Decimal("0.00")


@pytest.mark.asyncio
async def test_pending_total_mixes_batched_and_unbatched(db):
    """Real-world shape: a gym typically has some already-bundled
    rows (in a pending batch) AND some new rows accrued after the
    last batch. The sum is everything-not-paid.
    """
    gym = _gym("pt-mixed")
    user = _user("+962790000104")
    db.add_all([gym, user])
    await db.flush()

    pending_payout = _payout(gym, PayoutStatus.PENDING, "6.00", 3)
    paid_payout = _payout(gym, PayoutStatus.PAID, "8.00", 4)
    paid_payout.period_start = date(2026, 3, 1)
    paid_payout.period_end = date(2026, 3, 31)
    db.add_all([pending_payout, paid_payout])
    await db.flush()

    # 3 rows in pending batch (count) + 4 in paid batch (don't
    # count) + 2 unbatched (count) = 5 rows × 2 JOD = 10 JOD pending
    for _ in range(3):
        c = _checkin(gym, user)
        db.add(c)
        await db.flush()
        db.add(_ledger(gym, c, payout_id=pending_payout.id, amount="2.00"))
    for _ in range(4):
        c = _checkin(gym, user)
        db.add(c)
        await db.flush()
        db.add(_ledger(gym, c, payout_id=paid_payout.id, amount="2.00"))
    for _ in range(2):
        c = _checkin(gym, user)
        db.add(c)
        await db.flush()
        db.add(_ledger(gym, c, payout_id=None, amount="2.00"))
    await db.flush()

    pending = await PayoutRepository(db).pending_total_for_gym(gym.id)
    assert pending == Decimal("10.00")


@pytest.mark.asyncio
async def test_pending_total_for_gym_isolates_by_gym(db):
    """A gym's pending total must not leak rows from other gyms.
    """
    gym_a = _gym("pt-iso-a")
    gym_b = _gym("pt-iso-b", rate="3.00")
    user = _user("+962790000105")
    db.add_all([gym_a, gym_b, user])
    await db.flush()

    c_a = _checkin(gym_a, user)
    c_b = _checkin(gym_b, user)
    db.add_all([c_a, c_b])
    await db.flush()
    db.add_all(
        [
            _ledger(gym_a, c_a, amount="2.00"),
            _ledger(gym_b, c_b, amount="3.00"),
        ]
    )
    await db.flush()

    pending_a = await PayoutRepository(db).pending_total_for_gym(gym_a.id)
    pending_b = await PayoutRepository(db).pending_total_for_gym(gym_b.id)
    assert pending_a == Decimal("2.00")
    assert pending_b == Decimal("3.00")


@pytest.mark.asyncio
async def test_pending_total_global_matches_per_gym_sum(db):
    """Global pending_total() = sum of all gyms' pending_total_for_gym().
    Pins the contract that the unscoped version uses the same
    ledger-based logic as the gym-scoped one.
    """
    gym_a = _gym("pt-global-a")
    gym_b = _gym("pt-global-b")
    user = _user("+962790000106")
    db.add_all([gym_a, gym_b, user])
    await db.flush()

    for gym in (gym_a, gym_b):
        c = _checkin(gym, user)
        db.add(c)
        await db.flush()
        db.add(_ledger(gym, c, amount="2.00"))
    await db.flush()

    repo = PayoutRepository(db)
    per_a = await repo.pending_total_for_gym(gym_a.id)
    per_b = await repo.pending_total_for_gym(gym_b.id)
    total = await repo.pending_total()
    assert total >= per_a + per_b  # other test data may also live in pending state
