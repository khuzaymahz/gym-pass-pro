"""Tests for the `selected_gym` request-scoping dependency — the gate that
turns a partner request into exactly one branch they're allowed to operate.

These pin the multi-branch contract:
  - an explicit branch is honoured only if the caller has a membership,
  - a single-gym partner keeps working with no branch specified (back-compat),
  - a chain owner with many branches must name one.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal
from uuid import UUID

import pytest

from app.api.deps import selected_gym
from app.core.exceptions import AppError, ErrorCode
from app.db.enums import (
    AudienceGender,
    Category,
    PartnerAccessRole,
    Role,
    Tier,
)
from app.db.models import Gym, User
from app.repositories.partner_access_repo import PartnerAccessRepository
from app.utils.ids import uuid7


@dataclass
class _Req:
    """Minimal stand-in for a Starlette Request — `selected_gym` only reads
    `.headers.get(...)` and `.query_params.get(...)`."""

    headers: dict[str, str] = field(default_factory=dict)
    query_params: dict[str, str] = field(default_factory=dict)


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


def _owner(phone: str, *, gym_id: UUID | None = None) -> User:
    return User(id=uuid7(), phone=phone, role=Role.GYM_OWNER, gym_id=gym_id)


@pytest.mark.asyncio
async def test_explicit_branch_via_header_is_honoured(db):
    g1, g2 = _gym("sel-a-1"), _gym("sel-a-2")
    owner = _owner("+962790000020")
    db.add_all([g1, g2, owner])
    await db.flush()
    repo = PartnerAccessRepository(db)
    await repo.grant(user_id=owner.id, gym_id=g1.id, role=PartnerAccessRole.OWNER)
    await repo.grant(user_id=owner.id, gym_id=g2.id, role=PartnerAccessRole.OWNER)

    req = _Req(headers={"X-Gym-Id": str(g2.id)})
    assert await selected_gym(req, owner, repo) == g2.id


@pytest.mark.asyncio
async def test_branch_without_membership_is_rejected(db):
    g1, g2 = _gym("sel-b-1"), _gym("sel-b-2")
    owner = _owner("+962790000021")
    db.add_all([g1, g2, owner])
    await db.flush()
    repo = PartnerAccessRepository(db)
    await repo.grant(user_id=owner.id, gym_id=g1.id, role=PartnerAccessRole.OWNER)

    # g2 exists but the owner has no access row for it.
    req = _Req(headers={"X-Gym-Id": str(g2.id)})
    with pytest.raises(AppError) as exc:
        await selected_gym(req, owner, repo)
    assert exc.value.code == ErrorCode.AUTH_FORBIDDEN


@pytest.mark.asyncio
async def test_no_branch_falls_back_to_legacy_primary_gym(db):
    """Existing single-gym partner sends nothing → their `users.gym_id`."""
    g1 = _gym("sel-c-1")
    db.add(g1)
    await db.flush()
    owner = _owner("+962790000022", gym_id=g1.id)
    db.add(owner)
    await db.flush()
    repo = PartnerAccessRepository(db)
    await repo.grant(user_id=owner.id, gym_id=g1.id, role=PartnerAccessRole.OWNER)

    assert await selected_gym(_Req(), owner, repo) == g1.id


@pytest.mark.asyncio
async def test_no_branch_single_membership_no_gym_id(db):
    """A branch manager (no `gym_id`) with exactly one membership resolves
    to that membership without naming it."""
    g1 = _gym("sel-d-1")
    manager = _owner("+962790000023")
    db.add_all([g1, manager])
    await db.flush()
    repo = PartnerAccessRepository(db)
    await repo.grant(user_id=manager.id, gym_id=g1.id, role=PartnerAccessRole.MANAGER)

    assert await selected_gym(_Req(), manager, repo) == g1.id


@pytest.mark.asyncio
async def test_no_branch_multi_membership_requires_choice(db):
    g1, g2 = _gym("sel-e-1"), _gym("sel-e-2")
    owner = _owner("+962790000024")
    db.add_all([g1, g2, owner])
    await db.flush()
    repo = PartnerAccessRepository(db)
    await repo.grant(user_id=owner.id, gym_id=g1.id, role=PartnerAccessRole.OWNER)
    await repo.grant(user_id=owner.id, gym_id=g2.id, role=PartnerAccessRole.OWNER)

    with pytest.raises(AppError) as exc:
        await selected_gym(_Req(), owner, repo)
    assert exc.value.code == ErrorCode.VALIDATION_ERROR


@pytest.mark.asyncio
async def test_malformed_gym_id_header_is_rejected(db):
    owner = _owner("+962790000025")
    db.add(owner)
    await db.flush()
    repo = PartnerAccessRepository(db)

    req = _Req(headers={"X-Gym-Id": "not-a-uuid"})
    with pytest.raises(AppError) as exc:
        await selected_gym(req, owner, repo)
    assert exc.value.code == ErrorCode.VALIDATION_ERROR
