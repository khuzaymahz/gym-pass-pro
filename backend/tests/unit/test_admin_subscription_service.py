"""Service-level tests for AdminSubscriptionService management verbs.

Bypasses HTTP and exercises the service against the real DB session the
deps-wired endpoint would use. Covers extend / adjust-visits / change-
tier / restore / comp / force-resume-pause, the invariant guards
(one-active-per-user, elapsed-term), and audit-trail integrity.
"""

from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

import pytest
from sqlalchemy import func, select

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import Role, SubscriptionStatus, Tier
from app.db.models import (
    AuditLog,
    Plan,
    Subscription,
    SubscriptionPause,
    User,
)
from app.repositories.audit_repo import AuditRepository
from app.repositories.plan_repo import PlanRepository
from app.repositories.subscription_pause_repo import SubscriptionPauseRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.services.admin_subscription_service import AdminSubscriptionService
from app.services.audit_service import Actor, AuditService
from app.services.pause_service import PauseService
from app.utils.ids import uuid7
from app.utils.time import utcnow

# --- inline factories (kept local so each test reads top-to-bottom) ---


def _user(phone: str) -> User:
    return User(
        id=uuid7(),
        phone=phone,
        first_name="Test",
        last_name="User",
        role=Role.MEMBER,
    )


def _plan(tier: Tier = Tier.SILVER, *, months: int = 1) -> Plan:
    return Plan(
        id=uuid7(),
        tier=tier,
        duration_months=months,
        price_jod=Decimal("25.00"),
        monthly_visits=30,
        included_gym_count=10,
        features_en=[],
        features_ar=[],
        discount_percent=Decimal("0.00"),
        is_active=True,
    )


def _sub(
    user: User,
    plan: Plan,
    *,
    status: SubscriptionStatus = SubscriptionStatus.ACTIVE,
    tier: Tier = Tier.SILVER,
    expires_in_days: int = 30,
    visits_used: int = 0,
) -> Subscription:
    now = utcnow()
    return Subscription(
        id=uuid7(),
        user_id=user.id,
        plan_id=plan.id,
        tier=tier,
        status=status,
        starts_at=now,
        expires_at=now + timedelta(days=expires_in_days),
        visits_used=visits_used,
    )


def _actor(user: User) -> Actor:
    return Actor(user_id=user.id, role=Role.ADMIN, ip_address="127.0.0.1", user_agent="pytest")


def _build(db) -> AdminSubscriptionService:
    subs = SubscriptionRepository(db)
    plans = PlanRepository(db)
    pauses = SubscriptionPauseRepository(db)
    audit = AuditService(AuditRepository(db))
    pause_svc = PauseService(pauses, subs, plans, audit)
    return AdminSubscriptionService(subs, plans, pauses, pause_svc, audit)


async def _audit_count(db, action: str) -> int:
    stmt = select(func.count()).select_from(AuditLog).where(AuditLog.action == action)
    return int((await db.execute(stmt)).scalar_one())


# --- extend -----------------------------------------------------------


@pytest.mark.asyncio
async def test_extend_shifts_expiry_and_audits(db):
    user, plan = _user("+962790200001"), _plan()
    db.add_all([user, plan])
    await db.flush()
    sub = _sub(user, plan)
    db.add(sub)
    await db.flush()

    svc = _build(db)
    before = sub.expires_at
    out = await svc.extend(sub.id, days=7, actor=_actor(user))
    await db.flush()

    assert out.expires_at == before + timedelta(days=7)
    assert await _audit_count(db, "admin.subscription.extend") == 1


@pytest.mark.asyncio
async def test_extend_negative_shortens(db):
    user, plan = _user("+962790200002"), _plan()
    db.add_all([user, plan])
    await db.flush()
    sub = _sub(user, plan)
    db.add(sub)
    await db.flush()

    svc = _build(db)
    before = sub.expires_at
    out = await svc.extend(sub.id, days=-3, actor=_actor(user))
    assert out.expires_at == before - timedelta(days=3)


@pytest.mark.asyncio
async def test_extend_zero_rejected(db):
    user, plan = _user("+962790200003"), _plan()
    db.add_all([user, plan])
    await db.flush()
    sub = _sub(user, plan)
    db.add(sub)
    await db.flush()

    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.extend(sub.id, days=0, actor=_actor(user))
    assert ei.value.code is ErrorCode.VALIDATION_ERROR


# --- set_visits -------------------------------------------------------


@pytest.mark.asyncio
async def test_set_visits_absolute(db):
    user, plan = _user("+962790200004"), _plan()
    db.add_all([user, plan])
    await db.flush()
    sub = _sub(user, plan, visits_used=10)
    db.add(sub)
    await db.flush()

    svc = _build(db)
    out = await svc.set_visits(sub.id, visits_used=3, actor=_actor(user))
    assert out.visits_used == 3


@pytest.mark.asyncio
async def test_set_visits_negative_rejected(db):
    user, plan = _user("+962790200005"), _plan()
    db.add_all([user, plan])
    await db.flush()
    sub = _sub(user, plan)
    db.add(sub)
    await db.flush()

    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.set_visits(sub.id, visits_used=-1, actor=_actor(user))
    assert ei.value.code is ErrorCode.VALIDATION_ERROR


# --- change_tier ------------------------------------------------------


@pytest.mark.asyncio
async def test_change_tier(db):
    user, plan = _user("+962790200006"), _plan()
    db.add_all([user, plan])
    await db.flush()
    sub = _sub(user, plan, tier=Tier.SILVER)
    db.add(sub)
    await db.flush()

    svc = _build(db)
    out = await svc.change_tier(sub.id, tier=Tier.GOLD, actor=_actor(user))
    assert out.tier is Tier.GOLD


@pytest.mark.asyncio
async def test_change_tier_same_rejected(db):
    user, plan = _user("+962790200007"), _plan()
    db.add_all([user, plan])
    await db.flush()
    sub = _sub(user, plan, tier=Tier.GOLD)
    db.add(sub)
    await db.flush()

    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.change_tier(sub.id, tier=Tier.GOLD, actor=_actor(user))
    assert ei.value.code is ErrorCode.VALIDATION_ERROR


# --- restore ----------------------------------------------------------


@pytest.mark.asyncio
async def test_restore_cancelled(db):
    user, plan = _user("+962790200008"), _plan()
    db.add_all([user, plan])
    await db.flush()
    sub = _sub(user, plan, status=SubscriptionStatus.CANCELLED)
    sub.cancelled_at = utcnow()
    db.add(sub)
    await db.flush()

    svc = _build(db)
    out = await svc.restore(sub.id, actor=_actor(user))
    assert out.status is SubscriptionStatus.ACTIVE
    assert out.cancelled_at is None


@pytest.mark.asyncio
async def test_restore_rejected_when_other_active(db):
    user, plan = _user("+962790200009"), _plan()
    db.add_all([user, plan])
    await db.flush()
    cancelled = _sub(user, plan, status=SubscriptionStatus.CANCELLED)
    active = _sub(user, plan, status=SubscriptionStatus.ACTIVE)
    db.add_all([cancelled, active])
    await db.flush()

    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.restore(cancelled.id, actor=_actor(user))
    assert ei.value.code is ErrorCode.SUB_DUPLICATE_ACTIVE


@pytest.mark.asyncio
async def test_restore_rejected_when_term_elapsed(db):
    user, plan = _user("+962790200010"), _plan()
    db.add_all([user, plan])
    await db.flush()
    sub = _sub(user, plan, status=SubscriptionStatus.EXPIRED, expires_in_days=-1)
    db.add(sub)
    await db.flush()

    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.restore(sub.id, actor=_actor(user))
    assert ei.value.code is ErrorCode.SUB_EXPIRED


# --- comp -------------------------------------------------------------


@pytest.mark.asyncio
async def test_comp_creates_free_active_sub(db):
    user, plan = _user("+962790200011"), _plan(months=12)
    db.add_all([user, plan])
    await db.flush()

    svc = _build(db)
    out = await svc.comp(user_id=user.id, plan_id=plan.id, actor=_actor(user))
    assert out.status is SubscriptionStatus.ACTIVE
    assert out.purchased_price_jod == Decimal("0")
    assert out.tier is plan.tier


@pytest.mark.asyncio
async def test_comp_rejected_when_active_exists(db):
    user, plan = _user("+962790200012"), _plan()
    db.add_all([user, plan])
    await db.flush()
    db.add(_sub(user, plan, status=SubscriptionStatus.ACTIVE))
    await db.flush()

    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.comp(user_id=user.id, plan_id=plan.id, actor=_actor(user))
    assert ei.value.code is ErrorCode.SUB_DUPLICATE_ACTIVE


@pytest.mark.asyncio
async def test_comp_unknown_plan_rejected(db):
    user = _user("+962790200013")
    db.add(user)
    await db.flush()

    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.comp(user_id=user.id, plan_id=uuid7(), actor=_actor(user))
    assert ei.value.code is ErrorCode.PLAN_NOT_FOUND


# --- resume_pause -----------------------------------------------------


@pytest.mark.asyncio
async def test_resume_pause_credits_expiry(db):
    user, plan = _user("+962790200014"), _plan(months=12)
    db.add_all([user, plan])
    await db.flush()
    sub = _sub(user, plan)
    db.add(sub)
    await db.flush()
    # An open pause that started two days ago — resuming today credits
    # the consumed days back onto expires_at.
    today = utcnow().date()
    pause = SubscriptionPause(
        id=uuid7(),
        subscription_id=sub.id,
        starts_on=today - timedelta(days=2),
        ends_on=today + timedelta(days=5),
    )
    db.add(pause)
    await db.flush()

    svc = _build(db)
    before = sub.expires_at
    await svc.resume_pause(sub.id, actor=_actor(user))
    await db.flush()
    assert sub.expires_at > before


@pytest.mark.asyncio
async def test_resume_pause_without_open_pause_rejected(db):
    user, plan = _user("+962790200015"), _plan()
    db.add_all([user, plan])
    await db.flush()
    sub = _sub(user, plan)
    db.add(sub)
    await db.flush()

    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.resume_pause(sub.id, actor=_actor(user))
    assert ei.value.code is ErrorCode.VALIDATION_ERROR
