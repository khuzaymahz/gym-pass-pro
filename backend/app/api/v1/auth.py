from __future__ import annotations

import hashlib
import hmac
import time
from typing import TYPE_CHECKING, Annotated

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import auth_service, client_actor, db_session, redis_client

if TYPE_CHECKING:
    from redis.asyncio import Redis
from app.config import Settings, get_settings
from app.core.exceptions import AppError, ErrorCode
from app.db.enums import Role
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

# Service-token exchange — see `_enforce_exchange_envelope` below.
# History on the limit: 5/5min → 30/5min → 120/5min. The current
# ceiling accommodates a Next.js dashboard render that fans out to
# several server-component data calls each calling `getServerSession`
# concurrently. The HMAC + nonce are the actual security boundary;
# the rate-limit is purely a safety net against a buggy NextAuth
# side spinning out requests.
_EXCHANGE_RATE_LIMIT = 120
_EXCHANGE_RATE_WINDOW_SECONDS = 300


async def _enforce_exchange_envelope(
    *,
    svc: AuthService,
    redis: "Redis",
    settings: Settings,
    rate_limit_key: str,
    nonce_key: str,
    signed_payload: str,
    signature: str,
    signed_at: int,
) -> None:
    """Validate an exchange envelope: rate-limit, skew, HMAC, nonce.

    Raises `AppError` on any failure. Returns `None` on success —
    the caller proceeds to load the subject and mint the service
    token. Shared by `admin_exchange` and `partner_exchange` so the
    two endpoints can never drift on what counts as a valid
    envelope.
    """
    if not await svc.rate_limiter.allow(
        rate_limit_key,
        limit=_EXCHANGE_RATE_LIMIT,
        window_seconds=_EXCHANGE_RATE_WINDOW_SECONDS,
    ):
        raise AppError(
            ErrorCode.RATE_LIMITED,
            "Too many exchange requests. Try again in a few minutes.",
        )

    skew = settings.admin_exchange_max_skew_seconds
    if abs(int(time.time()) - signed_at) > skew:
        raise AppError(
            ErrorCode.AUTH_FORBIDDEN,
            "Exchange envelope expired or clock-skewed.",
        )

    expected = hmac.new(
        settings.admin_exchange_secret.encode("utf-8"),
        signed_payload.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    # Constant-time compare — `hmac.compare_digest` doesn't early-
    # return on length mismatch, so a wrong signature burns the
    # same time as a right one.
    if not hmac.compare_digest(expected, signature.lower()):
        raise AppError(ErrorCode.AUTH_FORBIDDEN, "Invalid exchange signature.")

    # Nonce single-use enforcement. Key TTL == skew window so the
    # entry ages out the same instant the signature would have
    # anyway. `set nx ex` is atomic — if the nonce was already
    # parked, we got `False` back and treat it as a replay.
    set_ok = await redis.set(nonce_key, "1", nx=True, ex=skew)
    if not set_ok:
        raise AppError(ErrorCode.AUTH_FORBIDDEN, "Exchange envelope replayed.")


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
    """NextAuth (admin app) → backend service-token exchange.

    NextAuth HMAC-signs the envelope with `ADMIN_EXCHANGE_SECRET`
    (shared out of band) and we verify before minting a service
    token. Replay-protected via a single-use nonce in Redis;
    rate-limited per-email as defence in depth.
    """
    email = body.email.lower()
    await _enforce_exchange_envelope(
        svc=svc,
        redis=redis,
        settings=get_settings(),
        rate_limit_key=f"admin:exchange:{email}",
        nonce_key=f"admin:exchange:nonce:{body.nonce}",
        signed_payload=f"{body.email}|{body.nonce}|{body.signed_at}",
        signature=body.signature,
        signed_at=body.signed_at,
    )

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
    partner's user id; `current_gym_owner` re-checks the role and
    gym-link on every request, so a leaked token can only act as
    the partner it was issued for.
    """
    await _enforce_exchange_envelope(
        svc=svc,
        redis=redis,
        settings=get_settings(),
        rate_limit_key=f"partner:exchange:{body.phone}",
        nonce_key=f"partner:exchange:nonce:{body.nonce}",
        signed_payload=f"{body.phone}|{body.nonce}|{body.signed_at}",
        signature=body.signature,
        signed_at=body.signed_at,
    )

    user = await svc.users.get_by_phone(body.phone)
    if user is None or user.role != Role.GYM_OWNER or user.gym_id is None:
        raise AppError(ErrorCode.AUTH_FORBIDDEN, "Not a gym partner.")
    token, exp = await svc.issue_service_token_for_partner(user)
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
