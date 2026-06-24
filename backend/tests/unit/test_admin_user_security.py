"""Service-level tests for AdminUserService security actions:
force-logout (revoke sessions), session listing, and contact edits
with uniqueness guards.
"""

from __future__ import annotations

from datetime import timedelta

import pytest
from sqlalchemy import func, select

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import Role
from app.db.models import AuditLog, User
from app.repositories.audit_repo import AuditRepository
from app.repositories.refresh_token_repo import RefreshTokenRepository
from app.repositories.user_repo import UserRepository
from app.schemas.admin import AdminUserUpdate
from app.services.admin_user_service import AdminUserService
from app.services.audit_service import Actor, AuditService
from app.utils.ids import uuid7
from app.utils.time import utcnow


def _member(phone: str, *, email: str | None = None) -> User:
    return User(
        id=uuid7(),
        phone=phone,
        email=email,
        first_name="Test",
        last_name="User",
        role=Role.MEMBER,
        token_version=0,
    )


def _actor() -> Actor:
    return Actor(user_id=None, role=Role.ADMIN, ip_address="127.0.0.1", user_agent="pytest")


def _build(db) -> AdminUserService:
    return AdminUserService(
        UserRepository(db),
        AuditService(AuditRepository(db)),
        RefreshTokenRepository(db),
    )


async def _audit_count(db, action: str) -> int:
    stmt = select(func.count()).select_from(AuditLog).where(AuditLog.action == action)
    return int((await db.execute(stmt)).scalar_one())


@pytest.mark.asyncio
async def test_revoke_sessions_revokes_live_tokens(db):
    member = _member("+962790400001")
    db.add(member)
    await db.flush()
    refreshes = RefreshTokenRepository(db)
    await refreshes.create(
        jti=uuid7(),
        user_id=member.id,
        expires_at=utcnow() + timedelta(days=30),
    )

    svc = _build(db)
    revoked = await svc.revoke_sessions(member.id, actor=_actor())
    # rowcount of the live-token bulk-revoke is the authoritative signal.
    assert revoked == 1
    # token_version bumped from 0 → 1 (read via scalar select to avoid
    # touching the identity-mapped instance the Core UPDATE expired).
    tv = (await db.execute(select(User.token_version).where(User.id == member.id))).scalar_one()
    assert tv == 1
    assert await _audit_count(db, "admin.user.revoke_sessions") == 1


@pytest.mark.asyncio
async def test_list_sessions_returns_rows(db):
    member = _member("+962790400002")
    db.add(member)
    await db.flush()
    refreshes = RefreshTokenRepository(db)
    await refreshes.create(jti=uuid7(), user_id=member.id, expires_at=utcnow() + timedelta(days=30))

    svc = _build(db)
    rows = await svc.list_sessions(member.id)
    assert len(rows) == 1


@pytest.mark.asyncio
async def test_update_email_changes(db):
    member = _member("+962790400003", email="old@example.com")
    db.add(member)
    await db.flush()

    svc = _build(db)
    out = await svc.update(member.id, AdminUserUpdate(email="new@example.com"), actor=_actor())
    assert out.email == "new@example.com"


@pytest.mark.asyncio
async def test_update_email_clash_rejected(db):
    a = _member("+962790400004", email="taken@example.com")
    b = _member("+962790400005", email="other@example.com")
    db.add_all([a, b])
    await db.flush()

    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.update(b.id, AdminUserUpdate(email="taken@example.com"), actor=_actor())
    assert ei.value.code is ErrorCode.VALIDATION_ERROR


@pytest.mark.asyncio
async def test_update_phone_clash_rejected(db):
    a = _member("+962790400006")
    b = _member("+962790400007")
    db.add_all([a, b])
    await db.flush()

    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.update(b.id, AdminUserUpdate(phone="+962790400006"), actor=_actor())
    assert ei.value.code is ErrorCode.VALIDATION_ERROR
