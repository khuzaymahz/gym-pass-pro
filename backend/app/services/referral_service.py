from __future__ import annotations

import secrets
from uuid import UUID

import structlog

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import ReferralStatus
from app.db.models import Referral, User
from app.repositories.referral_repo import ReferralRepository
from app.repositories.user_repo import UserRepository
from app.services.audit_service import Actor, AuditService
from app.utils.time import utcnow

log = structlog.get_logger(__name__)

_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no O/0/I/1
_CODE_LENGTH = 6
_CODE_MAX_ATTEMPTS = 10


class ReferralService:
    """Owns referral-code lifecycle: generation, claim, conversion.

    One code per user (stored on User.referral_code). One referral row per
    invited user (unique constraint). Pending referrals flip to converted on
    first paid subscription — that is the rule the team agreed on.
    """

    def __init__(
        self,
        users: UserRepository,
        referrals: ReferralRepository,
        audit: AuditService,
    ) -> None:
        self.users = users
        self.referrals = referrals
        self.audit = audit

    async def resolve_code(self, code: str) -> User | None:
        """Look up the referrer behind a code. Mobile uses this to confirm
        a friend's code is real (and to surface the referrer's display name)
        before recording the claim. Returns None for unknown codes; callers
        decide how to surface that — usually a 404."""
        normalized = code.strip().upper()
        if not normalized:
            return None
        return await self.users.get_by_referral_code(normalized)

    async def ensure_code_for_user(self, user: User) -> str:
        if user.referral_code:
            return user.referral_code
        code = await self._generate_unique_code()
        await self.users.update_fields(user, referral_code=code)
        return code

    async def claim_on_signup(
        self,
        *,
        invited_user: User,
        referral_code: str,
        actor: Actor,
    ) -> Referral | None:
        """Attach an invited user to the referrer identified by `referral_code`.

        Idempotent: if the invited user already has a referral row, returns it
        without mutating. Raises if the code is unknown or self-referral.
        """
        existing = await self.referrals.get_by_invited_user(invited_user.id)
        if existing is not None:
            return existing

        code = referral_code.strip().upper()
        referrer = await self.users.get_by_referral_code(code)
        if referrer is None:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Unknown referral code.",
                details={"field": "referralCode"},
            )
        if referrer.id == invited_user.id:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Cannot refer yourself.",
                details={"field": "referralCode"},
            )

        referral = await self.referrals.create(
            referrer_user_id=referrer.id,
            invited_user_id=invited_user.id,
            referral_code=code,
        )
        await self.users.update_fields(invited_user, invited_by_user_id=referrer.id)
        await self.audit.log(
            actor=actor,
            action="referral.claim",
            entity_type="referral",
            entity_id=referral.id,
            diff={
                "referrer_user_id": str(referrer.id),
                "invited_user_id": str(invited_user.id),
                "code": code,
            },
        )
        return referral

    async def mark_converted_if_pending(self, invited_user_id: UUID) -> bool:
        """Flip the invited user's referral to `converted` if still pending.

        Called from SubscriptionService after a successful purchase. Returns
        True if a flip happened. No-op if no referral row or already converted.
        """
        referral = await self.referrals.get_by_invited_user(invited_user_id)
        if referral is None or referral.status != ReferralStatus.PENDING:
            return False
        await self.referrals.mark_converted(referral, utcnow())
        await self.audit.log(
            actor=Actor(user_id=invited_user_id, role=None),
            action="referral.convert",
            entity_type="referral",
            entity_id=referral.id,
        )
        return True

    async def summary_for(self, user: User) -> dict[str, object]:
        code = await self.ensure_code_for_user(user)
        counts = await self.referrals.counts_for_referrer(user.id)
        rows = await self.referrals.list_for_referrer(user.id)
        return {
            "code": code,
            "counts": counts,
            "items": rows,
        }

    async def _generate_unique_code(self) -> str:
        for _ in range(_CODE_MAX_ATTEMPTS):
            raw = "".join(
                secrets.choice(_CODE_ALPHABET) for _ in range(_CODE_LENGTH)
            )
            code = f"GP-{raw}"
            if await self.users.get_by_referral_code(code) is None:
                return code
        raise AppError(
            ErrorCode.INTERNAL_ERROR,
            "Could not generate unique referral code.",
        )
