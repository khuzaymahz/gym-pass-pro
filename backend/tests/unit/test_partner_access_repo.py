"""Tests for PartnerAccessRepository — the partner↔gym membership layer
that lets one login own/operate multiple branches."""

from __future__ import annotations

from decimal import Decimal

import pytest

from app.db.enums import AudienceGender, Category, PartnerAccessRole, Role, Tier
from app.db.models import Gym, User
from app.repositories.partner_access_repo import PartnerAccessRepository
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


def _owner(phone: str) -> User:
    return User(id=uuid7(), phone=phone, role=Role.GYM_OWNER)


@pytest.mark.asyncio
async def test_grant_lists_all_branches_for_a_chain_owner(db):
    g1, g2 = _gym("chain-a-1"), _gym("chain-a-2")
    owner = _owner("+962790000010")
    db.add_all([g1, g2, owner])
    await db.flush()
    repo = PartnerAccessRepository(db)

    await repo.grant(user_id=owner.id, gym_id=g1.id, role=PartnerAccessRole.OWNER)
    await repo.grant(user_id=owner.id, gym_id=g2.id, role=PartnerAccessRole.OWNER)

    gyms = await repo.gyms_for_user(owner.id)
    assert {g.id for g, _ in gyms} == {g1.id, g2.id}
    assert all(role is PartnerAccessRole.OWNER for _, role in gyms)
    assert set(await repo.gym_ids_for_user(owner.id)) == {g1.id, g2.id}
    assert await repo.has_access(owner.id, g1.id)
    assert not await repo.has_access(owner.id, uuid7())


@pytest.mark.asyncio
async def test_revoke_removes_access(db):
    g = _gym("chain-b-1")
    owner = _owner("+962790000011")
    db.add_all([g, owner])
    await db.flush()
    repo = PartnerAccessRepository(db)

    await repo.grant(user_id=owner.id, gym_id=g.id, role=PartnerAccessRole.MANAGER)
    assert await repo.has_access(owner.id, g.id)

    await repo.revoke(user_id=owner.id, gym_id=g.id)
    assert not await repo.has_access(owner.id, g.id)


@pytest.mark.asyncio
async def test_gyms_for_user_excludes_soft_deleted_gym(db):
    g = _gym("chain-c-1")
    g.deleted_at = utcnow()
    owner = _owner("+962790000012")
    db.add_all([g, owner])
    await db.flush()
    repo = PartnerAccessRepository(db)
    await repo.grant(user_id=owner.id, gym_id=g.id, role=PartnerAccessRole.OWNER)

    assert await repo.gyms_for_user(owner.id) == []
