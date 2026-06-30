from __future__ import annotations

import re
from typing import Any
from uuid import UUID

from sqlalchemy.exc import IntegrityError

from app.core.exceptions import AppError, ErrorCode
from app.core.security import hash_password_async
from app.db.enums import PartnerAccessRole, Role
from app.db.models import User
from app.repositories.partner_access_repo import PartnerAccessRepository
from app.repositories.user_repo import UserRepository
from app.services.audit_service import Actor, AuditService
from app.services.gym_service import GymService
from app.utils.time import utcnow

# Jordan mobile prefixes (`077`/`078`/`079`).
PHONE_RE = re.compile(r"^\+962(7[789])\d{7}$")


class AdminPartnerService:
    """Provisioning surface for gym-partner logins from the admin console.

    Mints a `GYM_OWNER` user linked 1:1 to a gym; the partial unique
    index `uq_users_gym_owner_gym_id` enforces the invariant at the
    DB level, this service surfaces the same error as a 409 instead
    of bubbling an IntegrityError out as a 500. Every mutation writes
    an audit-log entry in the same transaction.
    """

    def __init__(
        self,
        users: UserRepository,
        gyms: GymService,
        audit: AuditService,
        access: PartnerAccessRepository,
    ) -> None:
        self.users = users
        self.gyms = gyms
        self.audit = audit
        self.access = access

    async def get_owner(self, gym_id: UUID) -> User | None:
        """Return the active partner row for a gym, or None if unset.
        404s on unknown gym so the route doesn't have to."""
        await self.gyms.get(gym_id)
        return await self.users.get_gym_owner_for_gym(gym_id)

    async def create_owner(
        self,
        *,
        gym_id: UUID,
        phone: str,
        password: str,
        name: str,
        actor: Actor,
    ) -> tuple[User, dict[str, Any]]:
        """Create a partner login for `gym_id`. Returns the new user
        plus the response dict the route renders."""
        normalized_phone = phone.strip().replace(" ", "").replace("-", "")
        if not PHONE_RE.match(normalized_phone):
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Invalid Jordanian phone (expected +9627XXXXXXXX).",
                details={"field": "phone"},
            )

        gym = await self.gyms.get(gym_id)

        existing_owner = await self.users.get_gym_owner_for_gym(gym_id)
        if existing_owner is not None:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "This gym already has a partner login.",
                details={"field": "gymId"},
            )

        existing_user = await self.users.get_by_phone(normalized_phone)
        if existing_user is not None:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Phone is already registered to another account.",
                details={"field": "phone"},
            )

        try:
            owner = await self.users.create_gym_owner(
                phone=normalized_phone,
                password_hash=await hash_password_async(password),
                name=name,
                gym_id=gym.id,
            )
        except IntegrityError as exc:
            # Partial unique race (someone created the partner between
            # our check and this insert) → surface as 409 not 500.
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "This gym already has a partner login.",
                details={"field": "gymId"},
            ) from exc

        # Membership row so the new login shows up in multi-branch scoping
        # (/partner/gyms, selected_gym). The legacy users.gym_id set above
        # stays their primary branch; this is the same gym as an `owner`
        # access row — the two stay consistent for a freshly minted owner.
        await self.access.grant(user_id=owner.id, gym_id=gym.id, role=PartnerAccessRole.OWNER)

        await self.audit.log(
            actor=actor,
            action="partner.create",
            entity_type="user",
            entity_id=owner.id,
            diff={
                "after": {
                    "role": Role.GYM_OWNER.value,
                    "gym_id": str(gym.id),
                    "phone": normalized_phone,
                    "name": name,
                }
            },
        )
        return owner, {
            "id": str(owner.id),
            "phone": normalized_phone,
            "name": owner.name,
            "gymId": str(gym.id),
        }

    async def link_owner(self, *, gym_id: UUID, phone: str, actor: Actor) -> dict[str, Any]:
        """Grant an EXISTING partner access to another branch.

        The multi-branch answer to a phone collision: rather than refuse a
        duplicate login, attach this gym to the partner who already owns
        that phone. Writes only a `partner_access` row — the partner's
        legacy `users.gym_id` (their first branch) is untouched, so
        `selected_gym` still defaults them there and they reach this branch
        by selecting it. Returns the route's response dict.
        """
        normalized_phone = phone.strip().replace(" ", "").replace("-", "")
        if not PHONE_RE.match(normalized_phone):
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Invalid Jordanian phone (expected +9627XXXXXXXX).",
                details={"field": "phone"},
            )

        gym = await self.gyms.get(gym_id)

        user = await self.users.get_by_phone(normalized_phone)
        if user is None:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "No partner found with this phone. Create a new login instead.",
                details={"field": "phone"},
            )
        if user.role != Role.GYM_OWNER:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "This phone belongs to a non-partner account.",
                details={"field": "phone"},
            )
        if await self.access.has_access(user.id, gym.id):
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "This partner is already linked to this gym.",
                details={"field": "phone"},
            )

        await self.access.grant(user_id=user.id, gym_id=gym.id, role=PartnerAccessRole.OWNER)
        await self.audit.log(
            actor=actor,
            action="partner.link",
            entity_type="user",
            entity_id=user.id,
            diff={
                "after": {
                    "gym_id": str(gym.id),
                    "role": PartnerAccessRole.OWNER.value,
                    "linked_phone": normalized_phone,
                }
            },
        )
        return {
            "id": str(user.id),
            "phone": normalized_phone,
            "name": user.name,
            "gymId": str(gym.id),
        }

    async def reset_owner_password(self, *, gym_id: UUID, password: str, actor: Actor) -> User:
        """Set a new password for a gym's partner login.

        v1 has no self-service reset (no email/SMS provider yet), so an
        admin sets the password directly when a partner forgets theirs.
        The hash is never recorded in the audit diff — only that a reset
        happened. Existing access tokens stay valid until they expire;
        a forgotten-password partner has no live session anyway, and a
        compromised one should be revoked via delete_owner instead.
        """
        await self.gyms.get(gym_id)
        owner = await self.users.get_gym_owner_for_gym(gym_id)
        if owner is None:
            raise AppError(ErrorCode.NOT_FOUND, "No partner attached to this gym.")
        # `owner` is a session-tracked row; the route commits the dirty
        # password_hash alongside the audit entry below.
        owner.password_hash = await hash_password_async(password)
        await self.audit.log(
            actor=actor,
            action="partner.password_reset",
            entity_type="user",
            entity_id=owner.id,
            diff={"after": {"gym_id": str(gym_id), "password_reset": True}},
        )
        return owner

    async def delete_owner(self, *, gym_id: UUID, actor: Actor) -> None:
        """Soft-delete a partner login. The `users` row stays for audit;
        the partial unique index drops it from the active-owner set as
        soon as `deleted_at` is non-null, freeing the gym to receive a
        new partner without a manual cleanup."""
        await self.gyms.get(gym_id)
        owner = await self.users.get_gym_owner_for_gym(gym_id)
        if owner is None:
            raise AppError(ErrorCode.NOT_FOUND, "No partner attached to this gym.")
        await self.users.soft_delete(owner, utcnow())
        await self.audit.log(
            actor=actor,
            action="partner.delete",
            entity_type="user",
            entity_id=owner.id,
            diff={"before": {"gym_id": str(gym_id), "phone": owner.phone}},
        )


__all__ = ["AdminPartnerService"]
