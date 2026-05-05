from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any, Literal
from uuid import UUID

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import get_settings
from app.core.exceptions import AppError, ErrorCode

TokenType = Literal["access", "refresh", "service"]

_pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")


def hash_password(plain: str) -> str:
    return _pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    return _pwd_context.verify(plain, hashed)


def hash_otp(code: str) -> str:
    return _pwd_context.hash(code)


def verify_otp(code: str, hashed: str) -> bool:
    return _pwd_context.verify(code, hashed)


def _ttl_for(token_type: TokenType) -> int:
    s = get_settings()
    if token_type == "access":
        return s.jwt_access_ttl_seconds
    if token_type == "refresh":
        return s.jwt_refresh_ttl_seconds
    return s.jwt_service_ttl_seconds


def encode_token(
    *,
    subject: str | UUID,
    token_type: TokenType,
    extra: dict[str, Any] | None = None,
    jti: str | None = None,
) -> tuple[str, datetime]:
    settings = get_settings()
    now = datetime.now(UTC)
    exp = now + timedelta(seconds=_ttl_for(token_type))
    payload: dict[str, Any] = {
        "sub": str(subject),
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
        "type": token_type,
    }
    if jti:
        payload["jti"] = jti
    if extra:
        payload.update(extra)
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    return token, exp


def decode_token(token: str, expected_type: TokenType | None = None) -> dict[str, Any]:
    settings = get_settings()
    try:
        payload: dict[str, Any] = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )
    except JWTError as exc:  # noqa: BLE001
        if "expired" in str(exc).lower():
            raise AppError(ErrorCode.AUTH_TOKEN_EXPIRED, "Token expired.") from exc
        raise AppError(ErrorCode.AUTH_TOKEN_INVALID, "Token invalid.") from exc

    if expected_type and payload.get("type") != expected_type:
        raise AppError(ErrorCode.AUTH_TOKEN_INVALID, "Wrong token type.")
    return payload
