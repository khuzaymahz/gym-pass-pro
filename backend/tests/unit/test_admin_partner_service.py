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
from app.repositories.partner_access_repo import PartnerAccessRepository
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
        PartnerAccessRepository(db),
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
async def test_create_owner_grants_partner_access_membership(db):
    """A freshly minted owner gets a partner_access row so they show up in
    multi-branch scoping (/partner/gyms, selected_gym), not just gym_id."""
    gym = _gym("partner-grant-1")
    db.add(gym)
    await db.flush()
    svc = _build(db)
    owner, _ = await svc.create_owner(
        gym_id=gym.id,
        phone="+962790000005",
        password="ownerpass12",
        name="Grant Owner",
        actor=_actor(),
    )
    access = PartnerAccessRepository(db)
    assert await access.has_access(owner.id, gym.id)


@pytest.mark.asyncio
async def test_link_owner_attaches_existing_partner_to_second_branch(db):
    g1, g2 = _gym("chain-link-1"), _gym("chain-link-2")
    db.add_all([g1, g2])
    await db.flush()
    svc = _build(db)
    owner, _ = await svc.create_owner(
        gym_id=g1.id,
        phone="+962790000006",
        password="ownerpass12",
        name="Chain Owner",
        actor=_actor(),
    )

    payload = await svc.link_owner(gym_id=g2.id, phone="+962790000006", actor=_actor())

    access = PartnerAccessRepository(db)
    assert await access.has_access(owner.id, g1.id)
    assert await access.has_access(owner.id, g2.id)
    # Linking does NOT move the partner's primary gym.
    assert owner.gym_id == g1.id
    assert payload["gymId"] == str(g2.id)
    assert await _audit_count(db, "partner.link") == 1


@pytest.mark.asyncio
async def test_link_owner_unknown_phone_rejected(db):
    gym = _gym("chain-link-3")
    db.add(gym)
    await db.flush()
    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.link_owner(gym_id=gym.id, phone="+962790009999", actor=_actor())
    assert ei.value.code is ErrorCode.VALIDATION_ERROR


@pytest.mark.asyncio
async def test_link_owner_already_linked_rejected(db):
    g1, g2 = _gym("chain-link-4"), _gym("chain-link-5")
    db.add_all([g1, g2])
    await db.flush()
    svc = _build(db)
    await svc.create_owner(
        gym_id=g1.id,
        phone="+962790000007",
        password="ownerpass12",
        name="Dup Owner",
        actor=_actor(),
    )
    await svc.link_owner(gym_id=g2.id, phone="+962790000007", actor=_actor())

    with pytest.raises(AppError) as ei:
        await svc.link_owner(gym_id=g2.id, phone="+962790000007", actor=_actor())
    assert ei.value.code is ErrorCode.VALIDATION_ERROR


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
