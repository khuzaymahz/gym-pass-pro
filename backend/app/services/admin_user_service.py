from __future__ import annotations

from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.core.security import hash_password_async
from app.db.enums import AdminScope, Role
from app.db.models import User
from app.repositories.refresh_token_repo import RefreshTokenRepository
from app.repositories.user_repo import UserRepository
from app.schemas.admin import AdminCreate, AdminUserUpdate
from app.services.audit_service import Actor, AuditService
from app.utils.time import utcnow


class AdminUserService:
    """Manages members and admins from the admin console.

    Keeps all identity-writing side effects in a single place so the audit
    log stays coherent — every mutation is accompanied by an audit entry.
    """

    def __init__(
        self,
        users: UserRepository,
        audit: AuditService,
        refreshes: RefreshTokenRepository | None = None,
    ) -> None:
        self.users = users
        self.audit = audit
        # Optional only so older test fixtures don't break. Production
        # wiring (deps.py) always supplies the refresh repo so
        # `reset_admin_password` can revoke outstanding sessions.
        self.refreshes = refreshes

    async def list(
        self,
        *,
        role: Role | None,
        q: str | None,
        include_deleted: bool,
        page: int,
        page_size: int,
    ) -> tuple[list[User], int]:
        return await self.users.list_paginated(
            role=role, q=q, include_deleted=include_deleted,
            page=page, page_size=page_size,
        )

    async def get(self, user_id: UUID) -> User:
        user = await self.users.get(user_id)
        if user is None:
            raise AppError(ErrorCode.NOT_FOUND, "User not found.")
        return user

    async def update(
        self, user_id: UUID, data: AdminUserUpdate, *, actor: Actor
    ) -> User:
        user = await self.get(user_id)
        before = _snapshot(user)
        updates = data.model_dump(by_alias=False, exclude_unset=True)

        # ----- Role-change guards -----
        # Admin can't change their *own* role — they'd lock themselves
        # out and have to ask another admin (or shell-poke the DB) to
        # come back. Forces an explicit two-admin handoff for any
        # demotion / promotion targeting yourself.
        if "role" in updates and user.id == actor.user_id:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Cannot change your own role; ask another admin.",
            )
        # Don't let the last live admin be demoted to a member — the
        # system would have no one with admin permissions, and the
        # only recovery path is a server-side bootstrap. Counts only
        # *active* (non-deleted) admins to ignore tombstoned rows.
        if (
            "role" in updates
            and updates["role"] != Role.ADMIN
            and user.role == Role.ADMIN
        ):
            live_admins = await self.users.count_by_role(Role.ADMIN)
            if live_admins <= 1:
                raise AppError(
                    ErrorCode.VALIDATION_ERROR,
                    "Cannot demote the last active admin.",
                )

        is_active = updates.pop("is_active", None)
        if is_active is True:
            await self.users.restore(user)
        elif is_active is False:
            if user.id == actor.user_id:
                raise AppError(
                    ErrorCode.VALIDATION_ERROR, "Cannot deactivate yourself."
                )
            # Same last-admin guard for soft-delete: deactivating an
            # admin counts as "no longer admin" for access purposes.
            if user.role == Role.ADMIN:
                live_admins = await self.users.count_by_role(Role.ADMIN)
                if live_admins <= 1:
                    raise AppError(
                        ErrorCode.VALIDATION_ERROR,
                        "Cannot deactivate the last active admin.",
                    )
            await self.users.soft_delete(user, utcnow())

        if updates:
            await self.users.update_fields(user, **updates)

        after: dict[str, object] = dict(updates)
        if is_active is not None:
            after["is_active"] = is_active
        # Specialised audit action for role changes so the admin
        # queue can spotlight them apart from name/locale tweaks.
        action = (
            "user.role_change"
            if "role" in updates and updates["role"] != user.role.value
            else "user.update"
        )
        await self.audit.log(
            actor=actor,
            action=action,
            entity_type="user",
            entity_id=user.id,
            diff={"before": before, "after": after},
        )
        return user

    async def create_admin(self, data: AdminCreate, *, actor: Actor) -> User:
        existing = await self.users.get_by_email(data.email)
        if existing is not None:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Email already in use.",
                details={"field": "email"},
            )
        # New admins start at `ops`. Promoting to `super` is a separate,
        # super-only operation — the surface is deliberately narrow so a
        # compromised admin token can't silently elevate a fresh peer.
        user = await self.users.create_admin(
            email=str(data.email),
            password_hash=await hash_password_async(data.password),
            name=data.name,
            scope=AdminScope.OPS,
        )
        await self.audit.log(
            actor=actor,
            action="admin.create",
            entity_type="user",
            entity_id=user.id,
            diff={
                "after": {
                    "email": user.email,
                    "name": user.name,
                    "scope": AdminScope.OPS.value,
                }
            },
        )
        return user

    async def reset_admin_password(
        self, user_id: UUID, new_password: str, *, actor: Actor
    ) -> None:
        user = await self.get(user_id)
        if user.role != Role.ADMIN:
            raise AppError(
                ErrorCode.VALIDATION_ERROR, "Target user is not an admin."
            )
        await self.users.update_fields(
            user, password_hash=await hash_password_async(new_password)
        )
        # Bump token_version so every outstanding access / service token
        # the target admin holds is rejected on the next request, AND
        # revoke every live refresh token so they can't trade a stale
        # refresh for a new pair. Without these two writes the attacker
        # who already had a token keeps acting as admin until the
        # natural TTL elapses.
        new_version = await self.users.bump_token_version(user.id)
        if self.refreshes is not None:
            await self.refreshes.revoke_all_for_user(user.id, utcnow())
        await self.audit.log(
            actor=actor,
            action="admin.password_reset",
            entity_type="user",
            entity_id=user.id,
            diff={"token_version": new_version, "sessions_revoked": True},
        )


def _snapshot(user: User) -> dict[str, object]:
    return {
        "email": user.email,
        "phone": user.phone,
        "name": user.name,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "gender": user.gender.value if user.gender is not None else None,
        "birthdate": user.birthdate.isoformat() if user.birthdate else None,
        "role": user.role.value,
        "locale": user.locale.value,
        "is_active": user.deleted_at is None,
    }
