from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest

from app.core.exceptions import AppError, ErrorCode
from app.core.security import decode_token, encode_token, hash_password, verify_password


def test_password_hash_round_trip():
    h = hash_password("supersecret")
    assert verify_password("supersecret", h)
    assert not verify_password("wrong", h)


def test_encode_decode_access():
    token, exp = encode_token(subject=uuid4(), token_type="access")
    assert exp > datetime.now(UTC)
    payload = decode_token(token, expected_type="access")
    assert payload["type"] == "access"


def test_decode_expired_token_raises():
    # Craft an access token with very short TTL by monkey-patching settings.
    from app.config import get_settings

    s = get_settings()
    original = s.jwt_access_ttl_seconds
    try:
        s.jwt_access_ttl_seconds = -1
        token, _ = encode_token(subject=uuid4(), token_type="access")
    finally:
        s.jwt_access_ttl_seconds = original

    with pytest.raises(AppError) as ei:
        decode_token(token)
    assert ei.value.code == ErrorCode.AUTH_TOKEN_EXPIRED


def test_decode_wrong_type_raises():
    token, _ = encode_token(subject=uuid4(), token_type="access")
    with pytest.raises(AppError) as ei:
        decode_token(token, expected_type="refresh")
    assert ei.value.code == ErrorCode.AUTH_TOKEN_INVALID
