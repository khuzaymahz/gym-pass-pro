from __future__ import annotations

import re
from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.db.enums import Gender, Locale, Role

PHONE_RE = re.compile(r"^\+962(7[789])\d{7}$")


class PhoneStart(BaseModel):
    phone: str

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, v: str) -> str:
        v = v.strip().replace(" ", "").replace("-", "")
        if not PHONE_RE.match(v):
            raise ValueError("invalid jordanian phone (expected +9627X…)")
        return v


class PhoneVerify(PhoneStart):
    code: str = Field(min_length=4, max_length=4, pattern=r"^\d{4}$")
    referral_code: str | None = Field(
        alias="referralCode", default=None, max_length=16
    )

    model_config = ConfigDict(populate_by_name=True)


class GoogleExchange(BaseModel):
    id_token: str = Field(alias="idToken")
    referral_code: str | None = Field(
        alias="referralCode", default=None, max_length=16
    )

    model_config = ConfigDict(populate_by_name=True)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(alias="refreshToken")

    model_config = ConfigDict(populate_by_name=True)


class PhoneCheckRequest(PhoneStart):
    pass


class PhoneCheckResult(BaseModel):
    exists: bool
    has_password: bool = Field(alias="hasPassword")
    # Masked form of the user's email (e.g. "om**@x.com") when one is on file,
    # so the forgot-password page can offer email-reset without leaking the
    # full address. None when the user has no email or doesn't exist.
    masked_email: str | None = Field(default=None, alias="maskedEmail")

    model_config = ConfigDict(populate_by_name=True)


class PhoneLoginRequest(PhoneStart):
    password: str = Field(min_length=8, max_length=128)


class PhoneChangeStart(PhoneStart):
    """Authenticated user requesting an OTP for a new phone number."""


class PhoneChangeVerify(PhoneStart):
    """Authenticated user submitting the OTP for the new phone number."""

    code: str = Field(min_length=4, max_length=4, pattern=r"^\d{4}$")


class MeUpdate(BaseModel):
    first_name: str | None = Field(alias="firstName", default=None, max_length=64)
    last_name: str | None = Field(alias="lastName", default=None, max_length=64)
    email: EmailStr | None = None
    gender: Gender | None = None
    birthdate: date | None = None
    password: str | None = Field(default=None, min_length=8, max_length=128)
    locale: Locale | None = None

    model_config = ConfigDict(populate_by_name=True)


class AdminLoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class PartnerLoginRequest(PhoneStart):
    """Gym-partner sign-in: Jordan phone + password."""

    password: str = Field(min_length=8, max_length=128)


class PartnerExchangeRequest(BaseModel):
    """Partner NextAuth → backend service-token exchange. Same HMAC
    envelope as `AdminExchangeRequest` but keyed on phone (which is
    the partner's identifier — gym-owners don't necessarily have an
    email on file)."""

    phone: str
    signed_at: int = Field(alias="signedAt")
    nonce: str = Field(min_length=16, max_length=128)
    signature: str = Field(min_length=64, max_length=128)

    model_config = ConfigDict(populate_by_name=True)

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, v: str) -> str:
        v = v.strip().replace(" ", "").replace("-", "")
        if not PHONE_RE.match(v):
            raise ValueError("invalid jordanian phone (expected +9627X…)")
        return v


class PartnerMeUser(BaseModel):
    """Slim payload returned to NextAuth after `partner/login`. The
    full gym profile is fetched separately by the partner SDK once
    the session is live."""

    id: UUID
    phone: str
    name: str | None = None
    role: Role
    gym_id: UUID = Field(alias="gymId")

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class AdminExchangeRequest(BaseModel):
    """NextAuth posts a signed envelope rather than a bare email so the
    backend can verify the request actually came from the admin app
    and isn't being replayed.

    Signature scheme:
      - `signed_at`: epoch seconds (int)
      - `nonce`:     32-char hex string, single-use within the
                     `admin_exchange_max_skew_seconds` window
      - `signature`: hex-encoded HMAC-SHA256 of
                     `f"{email}|{nonce}|{signed_at}"` keyed with
                     `settings.admin_exchange_secret`

    Backend rejects on any of: bad signature, |now - signed_at| >
    skew window, nonce already seen.
    """

    email: EmailStr
    signed_at: int = Field(alias="signedAt")
    nonce: str = Field(min_length=16, max_length=128)
    signature: str = Field(min_length=64, max_length=128)

    model_config = ConfigDict(populate_by_name=True)


class TokenPair(BaseModel):
    access_token: str = Field(alias="accessToken")
    refresh_token: str = Field(alias="refreshToken")
    access_expires_at: datetime = Field(alias="accessExpiresAt")
    refresh_expires_at: datetime = Field(alias="refreshExpiresAt")

    model_config = ConfigDict(populate_by_name=True)


class ServiceToken(BaseModel):
    token: str
    expires_at: datetime = Field(alias="expiresAt")

    model_config = ConfigDict(populate_by_name=True)


class MeUser(BaseModel):
    id: UUID
    phone: str | None = None
    email: str | None = None
    name: str | None = None
    first_name: str | None = Field(default=None, alias="firstName")
    last_name: str | None = Field(default=None, alias="lastName")
    gender: Gender | None = None
    birthdate: date | None = None
    has_password: bool = Field(default=False, alias="hasPassword")
    role: Role
    locale: Locale
    avatar_url: str | None = Field(default=None, alias="avatarUrl")

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)
