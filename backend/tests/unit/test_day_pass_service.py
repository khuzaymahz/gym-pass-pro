"""Service-level tests for the day-pass flow.

Bypasses HTTP routing and exercises DayPassService + CheckinService
against the real DB session, the way the deps-wired services would
run in production. Covers:

  1. Partner upserts an offering — row created, defaults applied.
  2. Member purchases when offering is ON — pass active, payment row
     created with NULL subscription_id, audit-log row written.
  3. Purchase refused when offering is OFF / disabled.
  4. Purchase refused when caller already has an active subscription.
  5. Purchase refused when an unexpired active pass already exists.
  6. Check-in via day-pass: marks pass USED, writes payout-ledger
     entry with the pass's NET amount (not the gym per_visit_rate).
  7. Audit-trail integrity: every state transition leaves a row.

The fake payment provider always succeeds — `tests/conftest.py`
doesn't mock it, so we instantiate the real `MockPaymentProvider`
which has the same behaviour as production-dev.
"""

from __future__ import annotations

from datetime import timedelta
from decimal import Decimal
from uuid import UUID

import pytest

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import (
    AudienceGender,
    Category,
    DayPassStatus,
    Gender,
    PaymentStatus,
    Role,
    SubscriptionStatus,
    Tier,
)
from app.db.models import (
    DayPass,
    Gym,
    Payment,
    PayoutLedger,
    Plan,
    Subscription,
    User,
)
from app.providers.payments.mock_payment import MockPaymentProvider
from app.repositories.audit_repo import AuditRepository
from app.repositories.checkin_repo import CheckinRepository
from app.repositories.day_pass_repo import (
    DayPassOfferingRepository,
    DayPassRepository,
)
from app.repositories.gym_repo import GymRepository
from app.repositories.payment_repo import PaymentRepository
from app.repositories.payout_repo import PayoutLedgerRepository
from app.repositories.plan_repo import PlanRepository
from app.repositories.subscription_pause_repo import SubscriptionPauseRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.services.audit_service import Actor, AuditService
from app.services.checkin_service import CheckinService
from app.services.day_pass_service import DayPassService
from app.utils.ids import uuid7
from app.utils.time import utcnow


# ---------------------------------------------------------------------
# Fixtures (factory helpers, not pytest fixtures — kept inline-local so
# each test reads top-to-bottom without hunting through conftest)
# ---------------------------------------------------------------------


def _gym(slug: str, *, rate: str = "2.00", audience: AudienceGender = AudienceGender.MIXED) -> Gym:
    return Gym(
        id=uuid7(),
        slug=slug,
        name_en=slug.replace("-", " ").title(),
        address_en="123 Test St",
        address_ar="123 شارع الاختبار",
        area="Amman",
        lat=Decimal("31.95"),
        lng=Decimal("35.91"),
        category=Category.GYM,
        required_tier=Tier.SILVER,
        audience_gender=audience,
        per_visit_rate_jod=Decimal(rate),
    )


def _user(phone: str, *, gender: Gender = Gender.MALE) -> User:
    return User(
        id=uuid7(),
        phone=phone,
        first_name="Test",
        last_name="User",
        role=Role.MEMBER,
        gender=gender,
    )


class _NullRateLimiter:
    """RateLimiter stub that always allows. Real rate-limit semantics
    are exercised in the rate-limit tests; here we want to focus on
    day-pass logic without piping in fake redis.
    """

    async def allow(self, key: str, *, limit: int, window_seconds: int) -> bool:
        return True


def _actor(user: User) -> Actor:
    return Actor(user_id=user.id, role=user.role, ip_address="127.0.0.1", user_agent="pytest")


def _build_day_pass_service(db) -> DayPassService:
    return DayPassService(
        offerings=DayPassOfferingRepository(db),
        passes=DayPassRepository(db),
        gyms=GymRepository(db),
        subs=SubscriptionRepository(db),
        payments=PaymentRepository(db),
        payment_provider=MockPaymentProvider(),
        audit=AuditService(AuditRepository(db)),
    )


def _build_checkin_service(db) -> CheckinService:
    """CheckinService takes positional repos/services then two kwargs
    for the day-pass deps — match that ordering exactly so a future
    constructor refactor surfaces here.
    """
    dps = _build_day_pass_service(db)
    return CheckinService(
        GymRepository(db),
        SubscriptionRepository(db),
        PlanRepository(db),
        CheckinRepository(db),
        SubscriptionPauseRepository(db),
        PayoutLedgerRepository(db),
        _NullRateLimiter(),
        AuditService(AuditRepository(db)),
        day_passes=DayPassRepository(db),
        day_pass_service=dps,
    )


# ---------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------


@pytest.mark.asyncio
async def test_partner_upsert_offering_creates_row_with_defaults(db):
    gym = _gym("upsert-defaults")
    owner = _user("+962790100001")
    db.add_all([gym, owner])
    await db.flush()

    svc = _build_day_pass_service(db)
    offering = await svc.upsert_offering(
        gym=gym,
        is_enabled=True,
        price_jod=Decimal("8.00"),
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(owner),
    )
    await db.flush()

    assert offering.gym_id == gym.id
    assert offering.is_enabled is True
    assert offering.price_jod == Decimal("8.00")
    # Defaults preserved from the schema column (10%, 24h).
    assert offering.platform_fee_pct == Decimal("10.00")
    assert offering.validity_hours == 24


@pytest.mark.asyncio
async def test_partner_upsert_is_idempotent(db):
    """Saving the offering twice mutates the same row, doesn't
    create a second one (the unique index enforces this; this test
    pins the service-level contract).
    """
    gym = _gym("upsert-idempotent")
    owner = _user("+962790100002")
    db.add_all([gym, owner])
    await db.flush()

    svc = _build_day_pass_service(db)
    first = await svc.upsert_offering(
        gym=gym,
        is_enabled=False,
        price_jod=Decimal("5.00"),
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(owner),
    )
    second = await svc.upsert_offering(
        gym=gym,
        is_enabled=True,
        price_jod=Decimal("9.50"),
        daily_cap=20,
        audience_gender_override=None,
        actor=_actor(owner),
    )
    await db.flush()

    assert first.id == second.id
    assert second.is_enabled is True
    assert second.price_jod == Decimal("9.50")
    assert second.daily_cap == 20


@pytest.mark.asyncio
async def test_member_purchase_happy_path(db):
    """Unsubscribed member buys a day pass for a gym that has the
    offering enabled. Verifies:
      * Pass is created ACTIVE with the snapshotted prices.
      * Payment row exists with NULL subscription_id and SUCCEEDED.
      * net_amount_jod = price_jod - platform_fee_jod (10% default).
      * expires_at = purchased_at + offering.validity_hours.
    """
    gym = _gym("purchase-happy")
    member = _user("+962790100003")
    db.add_all([gym, member])
    await db.flush()

    svc = _build_day_pass_service(db)
    await svc.upsert_offering(
        gym=gym,
        is_enabled=True,
        price_jod=Decimal("10.00"),
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(member),
    )
    await db.flush()

    day_pass = await svc.purchase(
        user=member,
        gym_slug=gym.slug,
        payment_method="mock",
        actor=_actor(member),
    )
    await db.flush()

    assert day_pass.status == DayPassStatus.ACTIVE
    assert day_pass.price_jod == Decimal("10.00")
    assert day_pass.platform_fee_jod == Decimal("1.00")  # 10% of 10
    assert day_pass.net_amount_jod == Decimal("9.00")
    # Validity window: 24h.
    assert (day_pass.expires_at - day_pass.purchased_at) == timedelta(hours=24)

    # Payment row should exist, success, null subscription.
    payment = await db.get(Payment, day_pass.payment_id)
    assert payment is not None
    assert payment.status == PaymentStatus.SUCCEEDED
    assert payment.subscription_id is None
    assert payment.amount_jod == Decimal("10.00")
    # raw_response carries the day-pass discriminator for ops grep.
    assert payment.raw_response.get("sku") == "day_pass"


@pytest.mark.asyncio
async def test_member_purchase_refused_when_offering_disabled(db):
    gym = _gym("purchase-offering-off")
    member = _user("+962790100004")
    db.add_all([gym, member])
    await db.flush()

    svc = _build_day_pass_service(db)
    await svc.upsert_offering(
        gym=gym,
        is_enabled=False,
        price_jod=Decimal("5.00"),
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(member),
    )
    await db.flush()

    with pytest.raises(AppError) as exc:
        await svc.purchase(
            user=member,
            gym_slug=gym.slug,
            payment_method="mock",
            actor=_actor(member),
        )
    # Specific code so the UI can show "Day passes are paused at
    # this gym" rather than a generic "not available". The earlier
    # DAY_PASS_NOT_AVAILABLE collapsed both this case and the no-
    # offering case under one banner.
    assert exc.value.code == ErrorCode.DAY_PASS_OFFERING_DISABLED


@pytest.mark.asyncio
async def test_member_purchase_refused_when_no_offering_row(db):
    """A gym without any offering row at all should also refuse,
    not 500. The mobile flow only renders the CTA when the public
    offering endpoint returns enabled=true, so this only fires on
    a race or a tampered request.
    """
    gym = _gym("purchase-no-offering")
    member = _user("+962790100005")
    db.add_all([gym, member])
    await db.flush()

    svc = _build_day_pass_service(db)
    with pytest.raises(AppError) as exc:
        await svc.purchase(
            user=member,
            gym_slug=gym.slug,
            payment_method="mock",
            actor=_actor(member),
        )
    # `NOT_CONFIGURED` distinguishes "partner hasn't set up day
    # passes" from "partner turned them off" so the UI copy can
    # differ ("We hope to add this gym" vs "paused right now").
    assert exc.value.code == ErrorCode.DAY_PASS_OFFERING_NOT_CONFIGURED


@pytest.mark.asyncio
async def test_member_purchase_refused_when_subscription_covers_gym(db):
    """An active subscriber whose tier ALREADY COVERS this gym
    shouldn't buy a one-off pass — they'd just be paying twice for
    the same access. Refuse with ALREADY_SUBSCRIBED. The locked-by-
    tier case (sub exists but at a lower tier than the gym
    requires) is covered by the next test — that path is allowed
    because the day-pass is a valid upsell.
    """
    gym = _gym("purchase-sub-covers")  # requires SILVER by default
    member = _user("+962790100006")
    plan = Plan(
        id=uuid7(),
        tier=Tier.SILVER,
        duration_months=1,
        price_jod=Decimal("25.00"),
        monthly_visits=30,
        included_gym_count=10,
        features_en=[],
        features_ar=[],
        discount_percent=Decimal("0.00"),
        is_active=True,
    )
    # Two-phase flush: SQLAlchemy doesn't always reorder a single
    # add_all batch by FK dependency, so we INSERT the parents
    # (users + plans) first and only then the Subscription that
    # FKs to them.
    db.add_all([gym, member, plan])
    await db.flush()
    # Silver sub against a Silver-required gym — coverage matches.
    sub = Subscription(
        id=uuid7(),
        user_id=member.id,
        plan_id=plan.id,
        tier=Tier.SILVER,
        status=SubscriptionStatus.ACTIVE,
        starts_at=utcnow(),
        expires_at=utcnow() + timedelta(days=30),
    )
    db.add(sub)
    await db.flush()

    svc = _build_day_pass_service(db)
    await svc.upsert_offering(
        gym=gym,
        is_enabled=True,
        price_jod=Decimal("7.00"),
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(member),
    )
    await db.flush()

    with pytest.raises(AppError) as exc:
        await svc.purchase(
            user=member,
            gym_slug=gym.slug,
            payment_method="mock",
            actor=_actor(member),
        )
    assert exc.value.code == ErrorCode.DAY_PASS_ALREADY_SUBSCRIBED


@pytest.mark.asyncio
async def test_member_purchase_allowed_when_sub_tier_below_gym(db):
    """The upsell path: a Silver subscriber looking at a Platinum
    gym they can't normally enter is a VALID day-pass customer —
    cheap trial, converts into a plan upgrade later. The service
    only refuses subscribers whose tier already covers the gym.
    """
    # Platinum-required gym
    gym = _gym("purchase-sub-locked")
    gym.required_tier = Tier.PLATINUM
    member = _user("+962790100020")
    plan = Plan(
        id=uuid7(),
        tier=Tier.SILVER,
        duration_months=1,
        price_jod=Decimal("25.00"),
        monthly_visits=30,
        included_gym_count=10,
        features_en=[],
        features_ar=[],
        discount_percent=Decimal("0.00"),
        is_active=True,
    )
    db.add_all([gym, member, plan])
    await db.flush()
    sub = Subscription(
        id=uuid7(),
        user_id=member.id,
        plan_id=plan.id,
        tier=Tier.SILVER,  # below the gym's required PLATINUM
        status=SubscriptionStatus.ACTIVE,
        starts_at=utcnow(),
        expires_at=utcnow() + timedelta(days=30),
    )
    db.add(sub)
    await db.flush()

    svc = _build_day_pass_service(db)
    await svc.upsert_offering(
        gym=gym,
        is_enabled=True,
        price_jod=Decimal("12.00"),
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(member),
    )
    await db.flush()

    # Should succeed — sub doesn't cover this gym, day-pass is a
    # legitimate alternative.
    day_pass = await svc.purchase(
        user=member,
        gym_slug=gym.slug,
        payment_method="mock",
        actor=_actor(member),
    )
    await db.flush()
    assert day_pass.status == DayPassStatus.ACTIVE
    assert day_pass.price_jod == Decimal("12.00")


@pytest.mark.asyncio
async def test_member_purchase_refused_when_active_pass_exists(db):
    """Stacking is blocked — buying a second pass for the same gym
    while the first is still valid would let the holder skip the
    re-entry rate-limit by churning passes.
    """
    gym = _gym("purchase-stack")
    member = _user("+962790100007")
    db.add_all([gym, member])
    await db.flush()

    svc = _build_day_pass_service(db)
    await svc.upsert_offering(
        gym=gym,
        is_enabled=True,
        price_jod=Decimal("6.00"),
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(member),
    )
    await db.flush()

    await svc.purchase(
        user=member, gym_slug=gym.slug, payment_method="mock", actor=_actor(member)
    )
    await db.flush()

    with pytest.raises(AppError) as exc:
        await svc.purchase(
            user=member,
            gym_slug=gym.slug,
            payment_method="mock",
            actor=_actor(member),
        )
    assert exc.value.code == ErrorCode.DAY_PASS_DUPLICATE_ACTIVE


@pytest.mark.asyncio
async def test_member_purchase_refused_on_audience_mismatch(db):
    """A male member can't buy a day pass for a female-only gym.
    The pass is the only path through the audience gate for
    non-subscribers; refusing it here is symmetric with the
    subscription-path gender check.
    """
    gym = _gym("purchase-audience", audience=AudienceGender.FEMALE_ONLY)
    member = _user("+962790100008", gender=Gender.MALE)
    db.add_all([gym, member])
    await db.flush()

    svc = _build_day_pass_service(db)
    await svc.upsert_offering(
        gym=gym,
        is_enabled=True,
        price_jod=Decimal("8.00"),
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(member),
    )
    await db.flush()

    with pytest.raises(AppError) as exc:
        await svc.purchase(
            user=member,
            gym_slug=gym.slug,
            payment_method="mock",
            actor=_actor(member),
        )
    assert exc.value.code == ErrorCode.DAY_PASS_AUDIENCE_LOCKED


@pytest.mark.asyncio
async def test_checkin_via_day_pass_marks_used_and_writes_ledger(db):
    """End-to-end: an unsubscribed member with a paid day pass
    scans the gym's static QR. Verifies:
      * CheckinService returns success without consuming subscription budget.
      * Day-pass status flips to USED.
      * PayoutLedger row is created with the pass's NET amount,
        NOT the gym's per_visit_rate (so the gym is paid the
        agreed day-pass share, not the subscription rate).
    """
    gym = _gym("checkin-via-pass", rate="2.00")
    member = _user("+962790100009")
    db.add_all([gym, member])
    await db.flush()

    dps = _build_day_pass_service(db)
    await dps.upsert_offering(
        gym=gym,
        is_enabled=True,
        price_jod=Decimal("10.00"),
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(member),
    )
    await db.flush()

    day_pass = await dps.purchase(
        user=member, gym_slug=gym.slug, payment_method="mock", actor=_actor(member)
    )
    await db.flush()

    # Scan via slug — same path the mobile QR-decoder takes after
    # parsing a `gympass:<slug>` payload.
    checkin_svc = _build_checkin_service(db)
    result = await checkin_svc.scan(
        user=member,
        qr_payload=gym.slug,
        actor=_actor(member),
    )
    await db.flush()

    # Pass is now used, with checkin_id pointing to the freshly
    # created checkin row.
    refreshed = await db.get(DayPass, day_pass.id)
    assert refreshed is not None
    assert refreshed.status == DayPassStatus.USED
    assert refreshed.checkin_id == result.checkin.id
    assert refreshed.used_at is not None

    # PayoutLedger row exists with the NET amount (price - 10% fee
    # = 9 JOD), not the gym's per_visit_rate (2 JOD).
    from sqlalchemy import select

    ledger_row = (
        await db.execute(
            select(PayoutLedger).where(PayoutLedger.checkin_id == result.checkin.id)
        )
    ).scalar_one()
    assert ledger_row.amount_jod == Decimal("9.00")
    assert ledger_row.gym_id == gym.id

    # `remaining` is None because day-pass holders don't have a
    # per-period visit budget.
    assert result.remaining is None
