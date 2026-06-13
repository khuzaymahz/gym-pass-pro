from __future__ import annotations

import secrets
from dataclasses import dataclass
from datetime import timedelta
from uuid import UUID, uuid4

import structlog

from app.config import get_settings
from app.core.exceptions import AppError, ErrorCode
from app.core.security import (
    encode_token,
    hash_otp_async,
    hash_password,
    verify_otp_async,
    verify_password_async,
)
from app.db.enums import Role
from app.db.models import User
from app.providers.sms import SmsProvider
from app.repositories.otp_repo import OtpRepository
from app.repositories.refresh_token_repo import RefreshTokenRepository
from app.repositories.user_repo import UserRepository
from app.services.audit_service import Actor, AuditService
from app.services.rate_limit import RateLimiter
from app.services.referral_service import ReferralService
from app.utils.time import utcnow

log = structlog.get_logger(__name__)

OTP_TTL_SECONDS = 300
OTP_MAX_ATTEMPTS = 5
# OTP request rate limit: at most 5 sends per 60 seconds per phone.
# OTP is the SMS-cost bucket — slightly stricter than the general
# mobile rate limits below since each request consumes a real SMS.
# A 1-minute window blunts spam without being so long the member
# thinks the app is broken when the SMS arrives slowly.
OTP_RATE_LIMIT = 5
OTP_RATE_WINDOW_SECONDS = 60
# General mobile-action rate limit window. Used for any non-OTP
# member-facing action where we want to discourage hammering but
# don't want to lock the member out for minutes after a few mis-
# taps (the previous 5-minute window felt like a punishment for
# fat-fingering a password). Keep this measured in seconds — a
# real attacker's 30-second cooldown is still ~120 attempts/hour
# per IP, which our credential-stuffing protections handle.
LOGIN_RATE_WINDOW_SECONDS = 30
DEV_OTP = "1234"

# Cached argon2 hash of a throwaway value, used to equalize the timing of the
# admin-login "user not found" path with the "wrong password" path. Without
# this, an attacker can probe which emails are registered admins by measuring
# response time (argon2 verification is intentionally slow). Computed lazily
# at module import via the sync hasher (one-time, ~50ms) so request-path
# usage stays a cheap O(1) dict lookup. The verify burns the CPU cost on the
# request path, but that work happens via `verify_password_async` which
# offloads to a thread so the event loop is never blocked.
_DUMMY_PASSWORD_HASH: str | None = None


def _dummy_password_hash() -> str:
    global _DUMMY_PASSWORD_HASH
    if _DUMMY_PASSWORD_HASH is None:
        _DUMMY_PASSWORD_HASH = hash_password("not-a-real-password")
    return _DUMMY_PASSWORD_HASH


@dataclass(frozen=True)
class TokenBundle:
    access_token: str
    refresh_token: str
    access_expires_at: object
    refresh_expires_at: object


class AuthService:
    def __init__(
        self,
        users: UserRepository,
        otps: OtpRepository,
        refreshes: RefreshTokenRepository,
        rate_limiter: RateLimiter,
        sms: SmsProvider,
        audit: AuditService,
        referrals: ReferralService,
    ) -> None:
        self.users = users
        self.otps = otps
        self.refreshes = refreshes
        self.rate_limiter = rate_limiter
        self.sms = sms
        self.audit = audit
        self.referrals = referrals

    # ---------- Phone OTP ----------

    async def request_phone_otp(self, phone: str, *, actor: Actor) -> None:
        rl_key = f"otp:req:{phone}"
        if not await self.rate_limiter.allow(
            rl_key, limit=OTP_RATE_LIMIT, window_seconds=OTP_RATE_WINDOW_SECONDS
        ):
            raise AppError(
                ErrorCode.AUTH_OTP_LOCKED,
                "Too many OTP requests. Try again later.",
            )

        settings = get_settings()
        code = DEV_OTP if settings.should_use_fixed_otp else f"{secrets.randbelow(10000):04d}"
        code_hash = await hash_otp_async(code)
        now = utcnow()
        await self.otps.delete_expired_for_phone(phone, now)
        await self.otps.insert(
            phone=phone,
            code_hash=code_hash,
            expires_at=now + timedelta(seconds=OTP_TTL_SECONDS),
        )
        await self.sms.send_otp(phone, code)
        await self.audit.log(
            actor=actor, action="auth.otp.request", entity_type="user", entity_id=None,
            diff={"phone": _mask_phone(phone)},
        )

    async def verify_phone_otp(
        self,
        phone: str,
        code: str,
        *,
        actor: Actor,
        referral_code: str | None = None,
    ) -> tuple[User, TokenBundle]:
        latest = await self.otps.latest_for_phone(phone)
        now = utcnow()
        if latest is None or latest.expires_at < now:
            raise AppError(ErrorCode.AUTH_OTP_EXPIRED, "OTP expired.")
        if latest.attempts >= OTP_MAX_ATTEMPTS:
            raise AppError(ErrorCode.AUTH_OTP_LOCKED, "OTP locked.")
        if not await verify_otp_async(code, latest.code_hash):
            await self.otps.increment_attempts(latest)
            raise AppError(ErrorCode.AUTH_OTP_INVALID, "OTP invalid.")

        await self.otps.mark_consumed(latest, now)
        user = await self.users.get_by_phone(phone)
        is_new_user = user is None
        if user is None:
            user = await self.users.create_member_by_phone(phone)
            await self.referrals.ensure_code_for_user(user, actor=actor)
        if is_new_user and referral_code:
            await self.referrals.claim_on_signup(
                invited_user=user, referral_code=referral_code, actor=actor,
            )
        tokens = await self._issue_tokens(user)
        await self.audit.log(
            actor=Actor(user_id=user.id, role=user.role,
                        ip_address=actor.ip_address, user_agent=actor.user_agent),
            action="auth.otp.verify",
            entity_type="user",
            entity_id=user.id,
        )
        return user, tokens

    # ---------- Phone change (authenticated) ----------

    async def request_phone_change_otp(
        self, user: User, new_phone: str, *, actor: Actor
    ) -> None:
        """Send an OTP to a new phone for an already-authenticated user.

        Pre-flight checks fail fast on the obvious cases (same number, already
        taken) so we don't spend an SMS on a request that can never verify.
        """
        if user.phone == new_phone:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "New phone is the same as your current phone.",
            )
        existing = await self.users.get_by_phone(new_phone)
        if existing is not None and existing.id != user.id:
            raise AppError(
                ErrorCode.VALIDATION_ERROR, "Phone already in use."
            )

        rl_key = f"otp:req:{new_phone}"
        if not await self.rate_limiter.allow(
            rl_key, limit=OTP_RATE_LIMIT, window_seconds=OTP_RATE_WINDOW_SECONDS
        ):
            raise AppError(
                ErrorCode.AUTH_OTP_LOCKED,
                "Too many OTP requests. Try again later.",
            )

        settings = get_settings()
        code = DEV_OTP if settings.should_use_fixed_otp else f"{secrets.randbelow(10000):04d}"
        code_hash = await hash_otp_async(code)
        now = utcnow()
        await self.otps.delete_expired_for_phone(new_phone, now)
        await self.otps.insert(
            phone=new_phone,
            code_hash=code_hash,
            expires_at=now + timedelta(seconds=OTP_TTL_SECONDS),
        )
        await self.sms.send_otp(new_phone, code)
        await self.audit.log(
            actor=actor,
            action="auth.phone_change.request",
            entity_type="user",
            entity_id=user.id,
            diff={"new_phone": _mask_phone(new_phone)},
        )

    async def verify_phone_change(
        self, user: User, new_phone: str, code: str, *, actor: Actor
    ) -> User:
        """Verify the OTP and swap the user's phone."""
        latest = await self.otps.latest_for_phone(new_phone)
        now = utcnow()
        if latest is None or latest.expires_at < now:
            raise AppError(ErrorCode.AUTH_OTP_EXPIRED, "OTP expired.")
        if latest.attempts >= OTP_MAX_ATTEMPTS:
            raise AppError(ErrorCode.AUTH_OTP_LOCKED, "OTP locked.")
        if not await verify_otp_async(code, latest.code_hash):
            await self.otps.increment_attempts(latest)
            raise AppError(ErrorCode.AUTH_OTP_INVALID, "OTP invalid.")

        # Re-check uniqueness against a race window between request and verify.
        existing = await self.users.get_by_phone(new_phone)
        if existing is not None and existing.id != user.id:
            raise AppError(
                ErrorCode.VALIDATION_ERROR, "Phone already in use."
            )

        await self.otps.mark_consumed(latest, now)
        old_phone = user.phone
        await self.users.update_fields(user, phone=new_phone)
        await self.audit.log(
            actor=actor,
            action="auth.phone_change.verify",
            entity_type="user",
            entity_id=user.id,
            diff={"old_phone": old_phone, "new_phone": new_phone},
        )
        return user

    # ---------- Google ----------

    async def exchange_google(
        self, *, email: str, name: str | None, google_sub: str, avatar_url: str | None,
        actor: Actor, referral_code: str | None = None,
    ) -> tuple[User, TokenBundle]:
        user = await self.users.get_by_google_sub(google_sub)
        is_new_user = False
        if user is None:
            user = await self.users.get_by_email(email) if email else None
            if user is None:
                user = await self.users.create_member_by_google(
                    email=email, name=name, google_sub=google_sub, avatar_url=avatar_url,
                )
                await self.referrals.ensure_code_for_user(user, actor=actor)
                is_new_user = True
            else:
                # Existing email-only user signs in with Google for the
                # first time — link the two by writing `google_sub`. Use
                # the repo's update_fields so the change is flushed in
                # the same transaction; previously we only mutated the
                # in-memory ORM object, which never made it to the
                # database (it would only persist on the next session
                # commit *after* something else flushed). Now the link
                # is durable and the next sign-in finds the row by
                # `google_sub` directly.
                await self.users.update_fields(user, google_sub=google_sub)
        if is_new_user and referral_code:
            await self.referrals.claim_on_signup(
                invited_user=user, referral_code=referral_code, actor=actor,
            )
        tokens = await self._issue_tokens(user)
        await self.audit.log(
            actor=Actor(user_id=user.id, role=user.role,
                        ip_address=actor.ip_address, user_agent=actor.user_agent),
            action="auth.google.exchange",
            entity_type="user",
            entity_id=user.id,
        )
        return user, tokens

    # ---------- Phone identity check ----------

    async def check_phone(
        self, phone: str
    ) -> tuple[bool, bool, str | None]:
        """Returns (exists, has_password, masked_email) for a phone. Used by
        the sign-in page to decide between OTP and password sign-in, and by
        the forgot-password page to know whether email-reset is on the menu.
        No rate-limit: only leaks existence (unavoidable given the OTP UX)
        plus a masked email — never the full address."""
        user = await self.users.get_by_phone(phone)
        if user is None:
            return False, False, None
        return True, bool(user.password_hash), _mask_email(user.email)

    # ---------- Member phone+password ----------

    async def login_with_password(
        self, phone: str, password: str, *, actor: Actor
    ) -> tuple[User, TokenBundle]:
        # Dual-bucket rate limit (per-IP + per-phone) to blunt credential
        # stuffing without globally locking out a fat-fingered member.
        # Window is short (30 s) per the mobile-action policy — admin
        # login keeps the longer 5-minute window since admin sessions
        # mint service tokens.
        ip = (actor.ip_address or "unknown").lower()
        if not await self.rate_limiter.allow(
            f"login:ip:{ip}",
            limit=10,
            window_seconds=LOGIN_RATE_WINDOW_SECONDS,
        ) or not await self.rate_limiter.allow(
            f"login:phone:{phone}",
            limit=5,
            window_seconds=LOGIN_RATE_WINDOW_SECONDS,
        ):
            raise AppError(
                ErrorCode.RATE_LIMITED,
                "Too many login attempts. Try again in 30 seconds.",
            )

        user = await self.users.get_by_phone(phone)
        if user is None or not user.password_hash:
            await verify_password_async(password, _dummy_password_hash())
            raise AppError(
                ErrorCode.AUTH_INVALID_CREDENTIALS, "Invalid credentials."
            )
        if not await verify_password_async(password, user.password_hash):
            raise AppError(
                ErrorCode.AUTH_INVALID_CREDENTIALS, "Invalid credentials."
            )
        tokens = await self._issue_tokens(user)
        await self.audit.log(
            actor=Actor(
                user_id=user.id, role=user.role,
                ip_address=actor.ip_address, user_agent=actor.user_agent,
            ),
            action="auth.password.login",
            entity_type="user",
            entity_id=user.id,
        )
        return user, tokens

    # ---------- Gym partner phone+password ----------

    async def login_partner(
        self, phone: str, password: str, *, actor: Actor
    ) -> User:
        """Authenticate a gym-owner by Jordanian phone + password.

        Mirrors `login_admin` in shape (rate-limited dual bucket,
        timing-equalized invalid path) but accepts the same Jordan
        phone format the member-app uses, so a partner whose number
        is also registered as a member sees a coherent identity.
        Refuses anything that isn't `Role.GYM_OWNER`.
        """
        ip = (actor.ip_address or "unknown").lower()
        ip_key = f"partner:login:ip:{ip}"
        phone_key = f"partner:login:phone:{phone}"
        if not await self.rate_limiter.allow(
            ip_key, limit=10, window_seconds=300
        ) or not await self.rate_limiter.allow(
            phone_key, limit=5, window_seconds=300
        ):
            log.warning(
                "partner_login_rate_limited",
                phone=_mask_phone(phone),
                ip=actor.ip_address,
            )
            raise AppError(
                ErrorCode.RATE_LIMITED,
                "Too many login attempts. Try again in a few minutes.",
            )

        user = await self.users.get_by_phone(phone)
        if (
            user is None
            or user.role != Role.GYM_OWNER
            or not user.password_hash
            or user.gym_id is None
        ):
            await verify_password_async(password, _dummy_password_hash())
            log.warning(
                "partner_login_failed",
                phone=_mask_phone(phone),
                ip=actor.ip_address,
                reason=(
                    "user_not_found" if user is None
                    else "wrong_role" if user.role != Role.GYM_OWNER
                    else "no_password" if not user.password_hash
                    else "no_gym_link"
                ),
            )
            raise AppError(
                ErrorCode.AUTH_INVALID_CREDENTIALS, "Invalid credentials."
            )
        if not await verify_password_async(password, user.password_hash):
            log.warning(
                "partner_login_failed",
                phone=_mask_phone(phone),
                ip=actor.ip_address,
                reason="bad_password",
                user_id=str(user.id),
            )
            raise AppError(
                ErrorCode.AUTH_INVALID_CREDENTIALS, "Invalid credentials."
            )
        await self.audit.log(
            actor=Actor(
                user_id=user.id, role=user.role,
                ip_address=actor.ip_address, user_agent=actor.user_agent,
            ),
            action="auth.partner.login",
            entity_type="user",
            entity_id=user.id,
        )
        return user

    # ---------- Admin email+password ----------

    async def login_admin(self, email: str, password: str, *, actor: Actor) -> User:
        # Rate-limit on both IP and email to blunt credential stuffing while
        # still letting one typo-prone admin retry without global lockout.
        ip = (actor.ip_address or "unknown").lower()
        ip_key = f"admin:login:ip:{ip}"
        email_key = f"admin:login:email:{email.lower()}"
        if not await self.rate_limiter.allow(
            ip_key, limit=10, window_seconds=300
        ) or not await self.rate_limiter.allow(
            email_key, limit=5, window_seconds=300
        ):
            log.warning(
                "admin_login_rate_limited",
                email=_mask_email(email),
                ip=actor.ip_address,
            )
            raise AppError(
                ErrorCode.RATE_LIMITED,
                "Too many login attempts. Try again in a few minutes.",
            )

        user = await self.users.get_by_email(email)
        if user is None or user.role != Role.ADMIN or not user.password_hash:
            await verify_password_async(password, _dummy_password_hash())
            log.warning(
                "admin_login_failed",
                email=_mask_email(email),
                ip=actor.ip_address,
                reason=(
                    "user_not_found" if user is None
                    else "wrong_role" if user.role != Role.ADMIN
                    else "no_password"
                ),
            )
            raise AppError(
                ErrorCode.AUTH_INVALID_CREDENTIALS, "Invalid credentials."
            )
        if not await verify_password_async(password, user.password_hash):
            log.warning(
                "admin_login_failed",
                email=_mask_email(email),
                ip=actor.ip_address,
                reason="bad_password",
                user_id=str(user.id),
            )
            raise AppError(
                ErrorCode.AUTH_INVALID_CREDENTIALS, "Invalid credentials."
            )
        await self.audit.log(
            actor=Actor(user_id=user.id, role=user.role,
                        ip_address=actor.ip_address, user_agent=actor.user_agent),
            action="auth.admin.login",
            entity_type="user",
            entity_id=user.id,
        )
        return user

    async def issue_service_token(self, user: User) -> tuple[str, object]:
        """Mint a service-token JWT for an admin user.

        Service tokens are short-lived (5 min by default) and are used
        by the admin / partner Next.js apps when they exchange a
        NextAuth session for a backend bearer.
        """
        extras: dict[str, object] = {"role": user.role.value}
        token, exp = encode_token(
            subject=user.id, token_type="service", extra=extras
        )
        return token, exp

    async def issue_service_token_for_partner(
        self, user: User
    ) -> tuple[str, object]:
        """Service-token variant for gym-owners.

        Embeds `gym_id` in the JWT extras so downstream channel-scope
        checks (e.g. realtime ws) can confirm the partner is asking
        about *their* gym, not someone else's. The user must already
        be a `GYM_OWNER` with a non-null `gym_id` — callers ensure
        this, but we re-assert here so a misuse fails loudly rather
        than minting a partner token without scope.
        """
        if user.role != Role.GYM_OWNER or user.gym_id is None:
            raise AppError(ErrorCode.AUTH_FORBIDDEN, "Not a gym partner.")
        extras: dict[str, object] = {
            "role": user.role.value,
            "gym_id": str(user.gym_id),
        }
        token, exp = encode_token(
            subject=user.id, token_type="service", extra=extras
        )
        return token, exp

    # ---------- Refresh ----------

    async def refresh(self, refresh_token: str, *, actor: Actor) -> TokenBundle:
        from app.core.security import decode_token

        payload = decode_token(refresh_token, expected_type="refresh")
        jti = payload.get("jti")
        if not jti:
            raise AppError(ErrorCode.AUTH_TOKEN_INVALID, "Refresh token invalid.")
        jti_uuid = UUID(jti)
        row = await self.refreshes.get(jti_uuid)
        now = utcnow()
        if row is None or row.expires_at < now:
            raise AppError(ErrorCode.AUTH_TOKEN_INVALID, "Refresh token revoked.")
        # **Reuse-detection**: if the token was already revoked but
        # hasn't expired yet, treat it as theft. The legitimate user
        # would have rotated to a fresh token by now; an attacker
        # presenting the *previous* one means they hold (or held) a
        # copy. Revoke every live refresh token for this user so the
        # whole chain dies — both sides have to log in fresh.
        if row.revoked_at is not None:
            await self.refreshes.revoke_all_for_user(row.user_id, now)
            await self.audit.log(
                actor=Actor(
                    user_id=row.user_id,
                    role=None,
                    ip_address=actor.ip_address,
                    user_agent=actor.user_agent,
                ),
                action="auth.refresh.reuse_detected",
                entity_type="user",
                entity_id=row.user_id,
                diff={"jti": str(jti_uuid)},
            )
            raise AppError(
                ErrorCode.AUTH_TOKEN_INVALID,
                "Refresh token reuse detected; all sessions revoked.",
            )
        user = await self.users.get(row.user_id)
        if user is None:
            raise AppError(ErrorCode.AUTH_TOKEN_INVALID, "User not found.")
        # Rotate: revoke old, issue new.
        await self.refreshes.revoke(row, now)
        tokens = await self._issue_tokens(user)
        await self.audit.log(
            actor=Actor(user_id=user.id, role=user.role,
                        ip_address=actor.ip_address, user_agent=actor.user_agent),
            action="auth.refresh",
            entity_type="user",
            entity_id=user.id,
        )
        return tokens

    async def logout(self, refresh_token: str, *, actor: Actor) -> None:
        """Revoke the presented refresh token (and any siblings on
        the same user) so a stolen access token's window collapses
        to its remaining TTL. Idempotent — already-revoked or
        unknown tokens succeed silently rather than leaking the
        existence of a session.
        """
        from app.core.security import decode_token

        try:
            payload = decode_token(refresh_token, expected_type="refresh")
        except Exception:  # noqa: BLE001 — any decode failure → silent OK
            return
        jti = payload.get("jti")
        if not jti:
            return
        try:
            jti_uuid = UUID(jti)
        except ValueError:
            return
        row = await self.refreshes.get(jti_uuid)
        if row is None:
            return
        await self.refreshes.revoke_all_for_user(row.user_id, utcnow())
        await self.audit.log(
            actor=Actor(
                user_id=row.user_id,
                role=None,
                ip_address=actor.ip_address,
                user_agent=actor.user_agent,
            ),
            action="auth.logout",
            entity_type="user",
            entity_id=row.user_id,
        )

    # ---------- Internal ----------

    async def _issue_tokens(self, user: User) -> TokenBundle:
        jti = uuid4()
        access, access_exp = encode_token(
            subject=user.id,
            token_type="access",
            extra={"role": user.role.value},
        )
        refresh, refresh_exp = encode_token(
            subject=user.id, token_type="refresh", jti=str(jti)
        )
        await self.refreshes.create(
            jti=jti, user_id=user.id, expires_at=refresh_exp
        )
        return TokenBundle(
            access_token=access,
            refresh_token=refresh,
            access_expires_at=access_exp,
            refresh_expires_at=refresh_exp,
        )


def _mask_email(email: str | None) -> str | None:
    """Masks the local-part beyond its first two chars: `omar@x.com` →
    `om**@x.com`. Returns None if input is empty or has no `@`. Mirrors the
    mobile-side mask so the forgot-password UI can swap in the backend value
    without surprise."""
    if not email:
        return None
    at = email.find("@")
    if at <= 0:
        return None
    local = email[:at]
    domain = email[at:]
    if len(local) <= 2:
        return f"{local}{domain}"
    keep = local[:2]
    return f"{keep}{'*' * (len(local) - 2)}{domain}"


def _mask_phone(phone: str | None) -> str | None:
    """Mask a phone number for audit-log diffs. Keeps the country
    prefix and last four digits (`+962 7X XXX 4567` → `+962***4567`)
    so support can correlate a member report with the right log
    entry without spraying full PII into a table that may be queried
    by analysts who don't need the raw numbers. Returns None if input
    is empty or shorter than the keep window.
    """
    if not phone:
        return None
    if len(phone) < 8:
        return phone  # Too short to mask meaningfully.
    return f"{phone[:4]}***{phone[-4:]}"


__all__ = ["AuthService", "TokenBundle", "hash_password"]
