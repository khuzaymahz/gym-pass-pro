"""Service-level tests for AdminDayPassService.

Covers admin offering configuration (incl. the platform-fee % and
validity window the partner can't reach), the sold-passes listing, and
the record-only refund path (pass + payment reversal + audit), plus the
not-refundable guards.
"""

from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

import pytest
from sqlalchemy import func, select

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import (
    AudienceGender,
    Category,
    DayPassStatus,
    PaymentMethod,
    PaymentStatus,
    Role,
    Tier,
)
from app.db.models import AuditLog, DayPass, Gym, User
from app.repositories.audit_repo import AuditRepository
from app.repositories.day_pass_repo import (
    DayPassOfferingRepository,
    DayPassRepository,
)
from app.repositories.gym_repo import GymRepository
from app.repositories.payment_repo import PaymentRepository
from app.services.admin_day_pass_service import AdminDayPassService
from app.services.audit_service import Actor, AuditService
from app.utils.ids import uuid7
from app.utils.time import utcnow


def _gym(slug: str) -> Gym:
    return Gym(
        id=uuid7(),
        slug=slug,
        name_en=slug.replace("-", " ").title(),
        address_en="123 Test St",
        address_ar="123",
        area="Amman",
        lat=Decimal("31.95"),
        lng=Decimal("35.91"),
        category=Category.GYM,
        required_tier=Tier.SILVER,
        audience_gender=AudienceGender.MIXED,
        per_visit_rate_jod=Decimal("2.00"),
    )


def _member(phone: str) -> User:
    return User(
        id=uuid7(),
        phone=phone,
        first_name="Test",
        last_name="User",
        role=Role.MEMBER,
    )


def _actor() -> Actor:
    # actor_user_id is nullable (system/admin actions); using None keeps
    # the audit FK satisfied without seeding a dedicated admin row.
    return Actor(
        user_id=None,
        role=Role.ADMIN,
        ip_address="127.0.0.1",
        user_agent="pytest",
    )


def _build(db) -> AdminDayPassService:
    return AdminDayPassService(
        DayPassOfferingRepository(db),
        DayPassRepository(db),
        PaymentRepository(db),
        GymRepository(db),
        AuditService(AuditRepository(db)),
    )


async def _pass(
    db,
    gym: Gym,
    member: User,
    offering_id,
    *,
    status: DayPassStatus = DayPassStatus.ACTIVE,
    payment_id=None,
) -> DayPass:
    now = utcnow()
    dp = DayPass(
        id=uuid7(),
        user_id=member.id,
        gym_id=gym.id,
        offering_id=offering_id,
        payment_id=payment_id,
        price_jod=Decimal("7.000"),
        platform_fee_jod=Decimal("0.700"),
        net_amount_jod=Decimal("6.300"),
        status=status,
        purchased_at=now,
        expires_at=now + timedelta(hours=24),
    )
    db.add(dp)
    await db.flush()
    return dp


async def _audit_count(db, action: str) -> int:
    stmt = select(func.count()).select_from(AuditLog).where(AuditLog.action == action)
    return int((await db.execute(stmt)).scalar_one())


@pytest.mark.asyncio
async def test_configure_offering_sets_admin_fields(db):
    gym = _gym("dp-config-1")
    db.add(gym)
    await db.flush()

    svc = _build(db)
    offering = await svc.configure_offering(
        gym.id,
        is_enabled=True,
        price_jod=Decimal("8.00"),
        platform_fee_pct=Decimal("15.00"),
        validity_hours=48,
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(),
    )
    assert offering.is_enabled is True
    assert offering.platform_fee_pct == Decimal("15.00")
    assert offering.validity_hours == 48
    assert await _audit_count(db, "admin.day_pass_offering.create") == 1


@pytest.mark.asyncio
async def test_configure_offering_unknown_gym_rejected(db):
    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.configure_offering(
            uuid7(),
            is_enabled=True,
            price_jod=Decimal("5.00"),
            platform_fee_pct=Decimal("10.00"),
            validity_hours=24,
            daily_cap=None,
            audience_gender_override=None,
            actor=_actor(),
        )
    assert ei.value.code is ErrorCode.GYM_NOT_FOUND


@pytest.mark.asyncio
async def test_list_offerings_returns_gym(db):
    gym = _gym("dp-list-1")
    db.add(gym)
    await db.flush()
    svc = _build(db)
    await svc.configure_offering(
        gym.id,
        is_enabled=True,
        price_jod=Decimal("6.00"),
        platform_fee_pct=Decimal("10.00"),
        validity_hours=24,
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(),
    )
    rows, total = await svc.list_offerings(enabled=True, page=1, page_size=50)
    assert total >= 1
    assert any(g.id == gym.id for _, g in rows)


@pytest.mark.asyncio
async def test_list_passes_filters_by_status(db):
    gym = _gym("dp-passes-1")
    member = _member("+962790300001")
    db.add_all([gym, member])
    await db.flush()
    svc = _build(db)
    offering = await svc.configure_offering(
        gym.id,
        is_enabled=True,
        price_jod=Decimal("7.00"),
        platform_fee_pct=Decimal("10.00"),
        validity_hours=24,
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(),
    )
    await _pass(db, gym, member, offering.id, status=DayPassStatus.ACTIVE)

    rows, total = await svc.list_passes(
        status=DayPassStatus.ACTIVE,
        gym_id=gym.id,
        user_id=None,
        page=1,
        page_size=20,
    )
    assert total == 1
    _dp, u, g = rows[0]
    assert u.id == member.id and g.id == gym.id


@pytest.mark.asyncio
async def test_refund_active_pass_reverses_payment_and_audits(db):
    gym = _gym("dp-refund-1")
    member = _member("+962790300002")
    db.add_all([gym, member])
    await db.flush()
    svc = _build(db)
    offering = await svc.configure_offering(
        gym.id,
        is_enabled=True,
        price_jod=Decimal("7.00"),
        platform_fee_pct=Decimal("10.00"),
        validity_hours=24,
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(),
    )
    payment = await PaymentRepository(db).create(
        subscription_id=None,
        amount_jod=Decimal("7.000"),
        method=PaymentMethod.MOCK,
        gateway_txn_id="mock-1",
        status=PaymentStatus.SUCCEEDED,
        raw_response={"mock": True},
        processed_at=utcnow(),
    )
    dp = await _pass(
        db,
        gym,
        member,
        offering.id,
        status=DayPassStatus.ACTIVE,
        payment_id=payment.id,
    )

    out = await svc.refund_pass(dp.id, actor=_actor())
    assert out.status is DayPassStatus.REFUNDED
    assert out.refunded_at is not None

    refreshed_payment = await PaymentRepository(db).get(payment.id)
    assert refreshed_payment is not None
    assert refreshed_payment.status is PaymentStatus.REFUNDED
    assert await _audit_count(db, "admin.day_pass.refund") == 1


@pytest.mark.asyncio
async def test_refund_used_pass_rejected(db):
    gym = _gym("dp-refund-2")
    member = _member("+962790300003")
    db.add_all([gym, member])
    await db.flush()
    svc = _build(db)
    offering = await svc.configure_offering(
        gym.id,
        is_enabled=True,
        price_jod=Decimal("7.00"),
        platform_fee_pct=Decimal("10.00"),
        validity_hours=24,
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(),
    )
    dp = await _pass(db, gym, member, offering.id, status=DayPassStatus.USED)

    with pytest.raises(AppError) as ei:
        await svc.refund_pass(dp.id, actor=_actor())
    assert ei.value.code is ErrorCode.DAY_PASS_NOT_REFUNDABLE


@pytest.mark.asyncio
async def test_refund_already_refunded_rejected(db):
    gym = _gym("dp-refund-3")
    member = _member("+962790300004")
    db.add_all([gym, member])
    await db.flush()
    svc = _build(db)
    offering = await svc.configure_offering(
        gym.id,
        is_enabled=True,
        price_jod=Decimal("7.00"),
        platform_fee_pct=Decimal("10.00"),
        validity_hours=24,
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(),
    )
    dp = await _pass(db, gym, member, offering.id, status=DayPassStatus.REFUNDED)

    with pytest.raises(AppError) as ei:
        await svc.refund_pass(dp.id, actor=_actor())
    assert ei.value.code is ErrorCode.DAY_PASS_NOT_REFUNDABLE


@pytest.mark.asyncio
async def test_refund_unknown_pass_rejected(db):
    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.refund_pass(uuid7(), actor=_actor())
    assert ei.value.code is ErrorCode.DAY_PASS_NOT_FOUND
