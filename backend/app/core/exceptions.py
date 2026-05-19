from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from typing import Any


class ErrorCode(StrEnum):
    # Auth
    AUTH_OTP_INVALID = "AUTH_OTP_INVALID"
    AUTH_OTP_EXPIRED = "AUTH_OTP_EXPIRED"
    AUTH_OTP_LOCKED = "AUTH_OTP_LOCKED"
    AUTH_INVALID_CREDENTIALS = "AUTH_INVALID_CREDENTIALS"
    AUTH_TOKEN_INVALID = "AUTH_TOKEN_INVALID"
    AUTH_TOKEN_EXPIRED = "AUTH_TOKEN_EXPIRED"
    AUTH_GOOGLE_TOKEN_INVALID = "AUTH_GOOGLE_TOKEN_INVALID"
    AUTH_FORBIDDEN = "AUTH_FORBIDDEN"

    # Subscriptions
    SUB_NOT_FOUND = "SUB_NOT_FOUND"
    SUB_EXPIRED = "SUB_EXPIRED"
    SUB_CANCELLED = "SUB_CANCELLED"
    SUB_DUPLICATE_ACTIVE = "SUB_DUPLICATE_ACTIVE"
    SUB_PAUSED = "SUB_PAUSED"
    SUB_PAUSE_NOT_ALLOWED = "SUB_PAUSE_NOT_ALLOWED"

    # Plans
    PLAN_NOT_FOUND = "PLAN_NOT_FOUND"
    PLAN_INACTIVE = "PLAN_INACTIVE"

    # Gyms
    GYM_NOT_FOUND = "GYM_NOT_FOUND"
    GYM_INACTIVE = "GYM_INACTIVE"

    # Check-ins
    CHECKIN_QR_INVALID = "CHECKIN_QR_INVALID"
    CHECKIN_TIER_LOCKED = "CHECKIN_TIER_LOCKED"
    CHECKIN_GENDER_LOCKED = "CHECKIN_GENDER_LOCKED"
    CHECKIN_NO_VISITS = "CHECKIN_NO_VISITS"
    CHECKIN_ALREADY_SCANNED = "CHECKIN_ALREADY_SCANNED"

    # Day passes
    DAY_PASS_OFFERING_NOT_FOUND = "DAY_PASS_OFFERING_NOT_FOUND"
    DAY_PASS_NOT_AVAILABLE = "DAY_PASS_NOT_AVAILABLE"
    DAY_PASS_ALREADY_SUBSCRIBED = "DAY_PASS_ALREADY_SUBSCRIBED"
    DAY_PASS_DUPLICATE_ACTIVE = "DAY_PASS_DUPLICATE_ACTIVE"
    DAY_PASS_AUDIENCE_LOCKED = "DAY_PASS_AUDIENCE_LOCKED"
    DAY_PASS_DAILY_CAP_REACHED = "DAY_PASS_DAILY_CAP_REACHED"

    # Generic
    RATE_LIMITED = "RATE_LIMITED"
    PAYMENT_DECLINED = "PAYMENT_DECLINED"
    PAYMENT_GATEWAY_ERROR = "PAYMENT_GATEWAY_ERROR"
    VALIDATION_ERROR = "VALIDATION_ERROR"
    NOT_FOUND = "NOT_FOUND"
    INTERNAL_ERROR = "INTERNAL_ERROR"


_DEFAULT_STATUS: dict[ErrorCode, int] = {
    ErrorCode.AUTH_OTP_INVALID: 400,
    ErrorCode.AUTH_OTP_EXPIRED: 400,
    ErrorCode.AUTH_OTP_LOCKED: 429,
    ErrorCode.AUTH_INVALID_CREDENTIALS: 401,
    ErrorCode.AUTH_TOKEN_INVALID: 401,
    ErrorCode.AUTH_TOKEN_EXPIRED: 401,
    ErrorCode.AUTH_GOOGLE_TOKEN_INVALID: 401,
    ErrorCode.AUTH_FORBIDDEN: 403,
    ErrorCode.SUB_NOT_FOUND: 404,
    ErrorCode.SUB_EXPIRED: 409,
    ErrorCode.SUB_CANCELLED: 409,
    ErrorCode.SUB_DUPLICATE_ACTIVE: 409,
    ErrorCode.SUB_PAUSED: 409,
    ErrorCode.SUB_PAUSE_NOT_ALLOWED: 409,
    ErrorCode.PLAN_NOT_FOUND: 404,
    ErrorCode.PLAN_INACTIVE: 409,
    ErrorCode.GYM_NOT_FOUND: 404,
    ErrorCode.GYM_INACTIVE: 409,
    ErrorCode.CHECKIN_QR_INVALID: 400,
    ErrorCode.CHECKIN_TIER_LOCKED: 403,
    ErrorCode.CHECKIN_GENDER_LOCKED: 403,
    ErrorCode.CHECKIN_NO_VISITS: 409,
    ErrorCode.CHECKIN_ALREADY_SCANNED: 409,
    ErrorCode.DAY_PASS_OFFERING_NOT_FOUND: 404,
    ErrorCode.DAY_PASS_NOT_AVAILABLE: 409,
    ErrorCode.DAY_PASS_ALREADY_SUBSCRIBED: 409,
    ErrorCode.DAY_PASS_DUPLICATE_ACTIVE: 409,
    ErrorCode.DAY_PASS_AUDIENCE_LOCKED: 403,
    ErrorCode.DAY_PASS_DAILY_CAP_REACHED: 429,
    ErrorCode.RATE_LIMITED: 429,
    ErrorCode.PAYMENT_DECLINED: 402,
    ErrorCode.PAYMENT_GATEWAY_ERROR: 502,
    ErrorCode.VALIDATION_ERROR: 422,
    ErrorCode.NOT_FOUND: 404,
    ErrorCode.INTERNAL_ERROR: 500,
}


@dataclass
class AppError(Exception):
    code: ErrorCode
    message: str
    details: dict[str, Any] | None = None
    status_code: int | None = None

    def __post_init__(self) -> None:
        if self.status_code is None:
            self.status_code = _DEFAULT_STATUS.get(self.code, 500)

    def to_payload(self, request_id: str | None = None) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "error": {
                "code": self.code.value,
                "message": self.message,
                "details": self.details or {},
            }
        }
        if request_id:
            payload["error"]["requestId"] = request_id
        return payload
