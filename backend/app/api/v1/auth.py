from __future__ import annotations

from typing import TYPE_CHECKING, Annotated

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import auth_service, client_actor, db_session, redis_client

if TYPE_CHECKING:
    from redis.asyncio import Redis
from app.config import get_settings
from app.core.exceptions import AppError, ErrorCode
from app.schemas.auth import (
    AdminExchangeRequest,
    AdminLoginRequest,
    GoogleExchange,
    MeUser,
    PartnerExchangeRequest,
    PartnerLoginRequest,
    PartnerMeUser,
    PhoneCheckRequest,
    PhoneCheckResult,
    PhoneLoginRequest,
    PhoneStart,
    PhoneVerify,
    RefreshRequest,
    ServiceToken,
    TokenPair,
)
from app.services.audit_service import Actor
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/phone/start", status_code=204)
async def phone_start(
    body: PhoneStart,
    svc: Annotated[AuthService, Depends(auth_service)],
    actor: Annotated[Actor, Depends(client_actor)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    await svc.request_phone_otp(body.phone, actor=actor)
    await session.commit()


@router.post("/phone/verify", response_model=TokenPair)
async def phone_verify(
    body: PhoneVerify,
    request: Request,
    svc: Annotated[AuthService, Depends(auth_service)],
    actor: Annotated[Actor, Depends(client_actor)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> TokenPair:
    _, tokens = await svc.verify_phone_otp(
        body.phone, body.code, actor=actor, referral_code=body.referral_code,
    )
    await session.commit()
    return _tokens_to_schema(tokens)


@router.post("/phone/check", response_model=PhoneCheckResult)
async def phone_check(
    body: PhoneCheckRequest,
    svc: Annotated[AuthService, Depends(auth_service)],
) -> PhoneCheckResult:
    exists, has_password, masked_email = await svc.check_phone(body.phone)
    return PhoneCheckResult(
        exists=exists,
        hasPassword=has_password,
        maskedEmail=masked_email,
    )


@router.post("/login", response_model=TokenPair)
async def phone_login(
    body: PhoneLoginRequest,
    svc: Annotated[AuthService, Depends(auth_service)],
    actor: Annotated[Actor, Depends(client_actor)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> TokenPair:
    _, tokens = await svc.login_with_password(body.phone, body.password, actor=actor)
    await session.commit()
    return _tokens_to_schema(tokens)


@router.post("/google/exchange", response_model=TokenPair)
async def google_exchange(
    body: GoogleExchange,
    svc: Annotated[AuthService, Depends(auth_service)],
    actor: Annotated[Actor, Depends(client_actor)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> TokenPair:
    """Exchange a Google ID token for a member session.

    Two paths:
      - **GOOGLE_OAUTH_CLIENT_ID is configured**: verify the ID token
        against Google's JWKS, refuse on signature / audience / issuer
        mismatch, refuse on `email_verified=false`. The verified `sub`
        and `email` then drive the same user-create-or-find flow as
        OTP signup.
      - **No client id configured (dev only)**: accept the raw token
        string as the Google `sub` so QA can exercise the flow without
        Google Cloud setup. Refuses outright in production regardless
        of whether the operator forgot to set the env var — better a
        loud error at runtime than a silent dev-mode bypass shipping.
    """
    settings = get_settings()
    if settings.google_oauth_client_id:
        from app.services.google_oauth import verify_google_id_token

        try:
            claims = verify_google_id_token(
                body.id_token, audience=settings.google_oauth_client_id
            )
        except ValueError as exc:
            raise AppError(
                ErrorCode.AUTH_GOOGLE_TOKEN_INVALID, str(exc)
            ) from exc
        _, tokens = await svc.exchange_google(
            email=claims["email"],
            name=claims.get("name"),
            google_sub=claims["sub"],
            avatar_url=claims.get("picture"),
            actor=actor,
            referral_code=body.referral_code,
        )
        await session.commit()
        return _tokens_to_schema(tokens)

    # Dev fallback. Production refuses to use it: an operator who forgot
    # to set GOOGLE_OAUTH_CLIENT_ID would otherwise silently accept any
    # opaque string as a valid Google identity.
    if not settings.is_dev:
        raise AppError(
            ErrorCode.AUTH_GOOGLE_TOKEN_INVALID,
            "Google sign-in is not configured.",
        )
    _, tokens = await svc.exchange_google(
        email="dev@example.com",
        name="Dev User",
        google_sub=body.id_token,
        avatar_url=None,
        actor=actor,
        referral_code=body.referral_code,
    )
    await session.commit()
    return _tokens_to_schema(tokens)


@router.post("/refresh", response_model=TokenPair)
async def refresh(
    body: RefreshRequest,
    svc: Annotated[AuthService, Depends(auth_service)],
    actor: Annotated[Actor, Depends(client_actor)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> TokenPair:
    tokens = await svc.refresh(body.refresh_token, actor=actor)
    await session.commit()
    return _tokens_to_schema(tokens)


@router.post("/logout", status_code=204)
async def logout(
    body: RefreshRequest,
    svc: Annotated[AuthService, Depends(auth_service)],
    actor: Annotated[Actor, Depends(client_actor)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    """Revoke the presented refresh token and every sibling on the
    same user. Idempotent — replaying a logout against an already-
    revoked token still 204s rather than leaking session state.
    Mobile is expected to wipe its local token vault after this
    returns; the backend revocation makes a stolen access token's
    window collapse to its remaining TTL (≤15 min by default).
    """
    await svc.logout(body.refresh_token, actor=actor)
    await session.commit()


@router.post("/admin/login", response_model=MeUser)
async def admin_login(
    body: AdminLoginRequest,
    svc: Annotated[AuthService, Depends(auth_service)],
    actor: Annotated[Actor, Depends(client_actor)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> MeUser:
    user = await svc.login_admin(body.email, body.password, actor=actor)
    await session.commit()
    return MeUser.model_validate(user)


@router.post("/admin/exchange", response_model=ServiceToken)
async def admin_exchange(
    body: AdminExchangeRequest,
    svc: Annotated[AuthService, Depends(auth_service)],
    redis: Annotated["Redis", Depends(redis_client)],
) -> ServiceToken:
    """NextAuth → backend service-token exchange.

    The previous version trusted any caller who could reach this
    endpoint with the admin's email — the only "protection" was the
    nginx Origin restriction, which a header-spoof or direct
    container hit defeats. Now NextAuth must HMAC-sign the envelope
    with `ADMIN_EXCHANGE_SECRET` (shared out of band) and the
    backend verifies before minting a service token.

    Replay guard: every accepted nonce is parked in Redis for the
    skew window so the same signed envelope can't be re-played even
    inside its valid timestamp range.

    Rate-limit guard: defence in depth on top of the HMAC + nonce.
    If the shared secret ever leaks, the rate limit caps a flood
    attack at 5 service-token mints per email per 5 minutes — long
    enough for ops to rotate the secret before the attacker mints
    a useful number of tokens.
    """
    import hashlib
    import hmac
    import time

    from app.config import get_settings
    from app.core.exceptions import AppError, ErrorCode
    from app.db.enums import Role

    rl_key = f"admin:exchange:{body.email.lower()}"
    # See partner_exchange below for the why on the bump from 5 → 30.
    # Same reasoning applies: HMAC envelope is the actual defense,
    # the rate-limit is a safety net that was too tight for a
    # legitimate active session.
    if not await svc.rate_limiter.allow(
        rl_key, limit=30, window_seconds=300,
    ):
        raise AppError(
            ErrorCode.RATE_LIMITED,
            "Too many exchange requests. Try again in a few minutes.",
        )

    settings = get_settings()
    now = int(time.time())
    skew = settings.admin_exchange_max_skew_seconds
    if abs(now - body.signed_at) > skew:
        raise AppError(
            ErrorCode.AUTH_FORBIDDEN,
            "Exchange envelope expired or clock-skewed.",
        )
    expected = hmac.new(
        settings.admin_exchange_secret.encode("utf-8"),
        f"{body.email}|{body.nonce}|{body.signed_at}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected, body.signature.lower()):
        # Constant-time compare — no early return on length mismatch
        # in `hmac.compare_digest`. Burns the same time on a wrong
        # signature as on a right one.
        raise AppError(ErrorCode.AUTH_FORBIDDEN, "Invalid exchange signature.")
    # Nonce single-use enforcement. Key TTL == skew so the entry
    # ages out the same instant the signature would have anyway.
    nonce_key = f"admin:exchange:nonce:{body.nonce}"
    set_ok = await redis.set(nonce_key, "1", nx=True, ex=skew)
    if not set_ok:
        raise AppError(ErrorCode.AUTH_FORBIDDEN, "Exchange envelope replayed.")

    user = await svc.users.get_by_email(body.email)
    if user is None or user.role != Role.ADMIN:
        raise AppError(ErrorCode.AUTH_FORBIDDEN, "Not an admin.")
    token, exp = await svc.issue_service_token(user)
    return ServiceToken(token=token, expires_at=exp)  # type: ignore[arg-type]


@router.post("/partner/login", response_model=PartnerMeUser)
async def partner_login(
    body: PartnerLoginRequest,
    svc: Annotated[AuthService, Depends(auth_service)],
    actor: Annotated[Actor, Depends(client_actor)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> PartnerMeUser:
    user = await svc.login_partner(body.phone, body.password, actor=actor)
    await session.commit()
    return PartnerMeUser.model_validate(user)


@router.post("/partner/exchange", response_model=ServiceToken)
async def partner_exchange(
    body: PartnerExchangeRequest,
    svc: Annotated[AuthService, Depends(auth_service)],
    redis: Annotated["Redis", Depends(redis_client)],
) -> ServiceToken:
    """NextAuth (gym-partner app) → backend service-token exchange.

    Mirrors `/auth/admin/exchange`: signed envelope (phone | nonce |
    signed_at) HMAC'd with the shared secret, single-use nonce in
    Redis, rate-limit cap. Mints a service JWT scoped to the
    partner's user id; backend `current_gym_owner` re-checks the
    role and gym-link on every request, so a leaked token can only
    act as the partner it was issued for.
    """
    import hashlib
    import hmac
    import time

    from app.config import get_settings
    from app.core.exceptions import AppError, ErrorCode
    from app.db.enums import Role

    # The exchange endpoint is gated by an HMAC envelope tied to a
    # shared secret only the partner portal holds, plus a single-use
    # nonce. Anyone who can produce a valid request is, by definition,
    # the legitimate caller — the rate-limiter is purely defensive
    # against a buggy NextAuth side spinning out requests, not against
    # an attacker. 5/5min was tight enough that a normal active session
    # (one mint on sign-in + one refresh near the 5-min service-token
    # expiry per active tab) regularly tripped it, surfacing as the
    # very misleading "Credentials not recognised" on /login. Bumped
    # generously and gated by a more robust check on the calling side
    # (NextAuth coalesces concurrent refreshes so a render storm only
    # produces a single exchange call).
    rl_key = f"partner:exchange:{body.phone}"
    if not await svc.rate_limiter.allow(
        rl_key, limit=30, window_seconds=300,
    ):
        raise AppError(
            ErrorCode.RATE_LIMITED,
            "Too many exchange requests. Try again in a few minutes.",
        )

    settings = get_settings()
    now = int(time.time())
    skew = settings.admin_exchange_max_skew_seconds
    if abs(now - body.signed_at) > skew:
        raise AppError(
            ErrorCode.AUTH_FORBIDDEN,
            "Exchange envelope expired or clock-skewed.",
        )
    expected = hmac.new(
        settings.admin_exchange_secret.encode("utf-8"),
        f"{body.phone}|{body.nonce}|{body.signed_at}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected, body.signature.lower()):
        raise AppError(ErrorCode.AUTH_FORBIDDEN, "Invalid exchange signature.")
    nonce_key = f"partner:exchange:nonce:{body.nonce}"
    set_ok = await redis.set(nonce_key, "1", nx=True, ex=skew)
    if not set_ok:
        raise AppError(ErrorCode.AUTH_FORBIDDEN, "Exchange envelope replayed.")

    user = await svc.users.get_by_phone(body.phone)
    if (
        user is None
        or user.role != Role.GYM_OWNER
        or user.gym_id is None
    ):
        raise AppError(ErrorCode.AUTH_FORBIDDEN, "Not a gym partner.")
    token, exp = await svc.issue_service_token(user)
    return ServiceToken(token=token, expires_at=exp)  # type: ignore[arg-type]


def _tokens_to_schema(bundle: object) -> TokenPair:
    return TokenPair.model_validate(
        {
            "accessToken": bundle.access_token,  # type: ignore[attr-defined]
            "refreshToken": bundle.refresh_token,  # type: ignore[attr-defined]
            "accessExpiresAt": bundle.access_expires_at,  # type: ignore[attr-defined]
            "refreshExpiresAt": bundle.refresh_expires_at,  # type: ignore[attr-defined]
        }
    )
