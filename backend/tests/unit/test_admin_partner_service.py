"""Service-level tests for AdminPartnerService — gym-partner login
provisioning and the admin-driven password reset (no self-service
reset flow in v1)."""

from __future__ import annotations

from decimal import Decimal

import pytest
from sqlalchemy import func, select

from app.core.exceptions import AppError, ErrorCode
from app.core.security import verify_password
from app.db.enums import AudienceGender, Category, Role, Tier
from app.db.models import AuditLog, Gym
from app.repositories.audit_repo import AuditRepository
from app.repositories.gym_repo import GymRepository
from app.repositories.user_repo import UserRepository
from app.services.admin_partner_service import AdminPartnerService
from app.services.audit_service import Actor, AuditService
from app.services.gym_service import GymService
from app.utils.ids import uuid7


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


def _actor() -> Actor:
    return Actor(
        user_id=None,
        role=Role.ADMIN,
        ip_address="127.0.0.1",
        user_agent="pytest",
    )


def _build(db) -> AdminPartnerService:
    audit = AuditService(AuditRepository(db))
    return AdminPartnerService(
        UserRepository(db),
        GymService(GymRepository(db), audit),
        audit,
    )


async def _audit_count(db, action: str) -> int:
    stmt = select(func.count()).select_from(AuditLog).where(AuditLog.action == action)
    return int((await db.execute(stmt)).scalar_one())


@pytest.mark.asyncio
async def test_reset_owner_password_changes_hash_and_audits(db):
    gym = _gym("partner-reset-1")
    db.add(gym)
    await db.flush()
    svc = _build(db)
    owner, _ = await svc.create_owner(
        gym_id=gym.id,
        phone="+962790000001",
        password="oldpassword1",
        name="Owner One",
        actor=_actor(),
    )
    old_hash = owner.password_hash

    await svc.reset_owner_password(gym_id=gym.id, password="brandnewpass2", actor=_actor())

    assert owner.password_hash != old_hash
    assert verify_password("brandnewpass2", owner.password_hash)
    assert not verify_password("oldpassword1", owner.password_hash)
    assert await _audit_count(db, "partner.password_reset") == 1


@pytest.mark.asyncio
async def test_reset_owner_password_no_owner_rejected(db):
    gym = _gym("partner-reset-2")
    db.add(gym)
    await db.flush()
    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.reset_owner_password(gym_id=gym.id, password="whatever123", actor=_actor())
    assert ei.value.code is ErrorCode.NOT_FOUND


@pytest.mark.asyncio
async def test_reset_owner_password_unknown_gym_rejected(db):
    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.reset_owner_password(gym_id=uuid7(), password="whatever123", actor=_actor())
    assert ei.value.code is ErrorCode.GYM_NOT_FOUND
