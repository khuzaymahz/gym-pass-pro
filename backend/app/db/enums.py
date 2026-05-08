from __future__ import annotations

from enum import StrEnum


class Tier(StrEnum):
    SILVER = "silver"
    GOLD = "gold"
    PLATINUM = "platinum"
    DIAMOND = "diamond"

    @property
    def rank(self) -> int:
        return _TIER_RANK[self]


_TIER_RANK = {Tier.SILVER: 0, Tier.GOLD: 1, Tier.PLATINUM: 2, Tier.DIAMOND: 3}


class Category(StrEnum):
    GYM = "gym"
    CROSSFIT = "crossfit"
    MARTIAL = "martial"
    YOGA = "yoga"


class Role(StrEnum):
    MEMBER = "member"
    ADMIN = "admin"
    GYM_OWNER = "gym_owner"


class SubscriptionStatus(StrEnum):
    PENDING = "pending"
    ACTIVE = "active"
    EXPIRED = "expired"
    CANCELLED = "cancelled"


class PaymentMethod(StrEnum):
    CARD = "card"
    CLIQ = "cliq"
    APPLE_PAY = "apple_pay"
    GOOGLE_PAY = "google_pay"
    MOCK = "mock"


class PaymentStatus(StrEnum):
    PENDING = "pending"
    SUCCEEDED = "succeeded"
    FAILED = "failed"


class CheckinStatus(StrEnum):
    SUCCESS = "success"
    TIER_LOCKED = "tier_locked"
    NO_VISITS = "no_visits"
    EXPIRED = "expired"
    INVALID_QR = "invalid_qr"
    RATE_LIMITED = "rate_limited"


class PayoutStatus(StrEnum):
    PENDING = "pending"
    PAID = "paid"


class NotificationType(StrEnum):
    EXPIRE = "expire"
    CHECKIN = "checkin"
    PROMO = "promo"
    GUEST = "guest"
    SYSTEM = "system"


class Locale(StrEnum):
    AR = "ar"
    EN = "en"


class TicketCategory(StrEnum):
    BUG = "bug"
    COMPLAINT = "complaint"
    FEATURE = "feature"
    ACCOUNT = "account"
    PAYMENT = "payment"
    GYM_ISSUE = "gym_issue"
    OTHER = "other"


class TicketPriority(StrEnum):
    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"
    URGENT = "urgent"


class TicketStatus(StrEnum):
    OPEN = "open"
    IN_PROGRESS = "in_progress"
    WAITING_USER = "waiting_user"
    RESOLVED = "resolved"
    CLOSED = "closed"


class Gender(StrEnum):
    MALE = "male"
    FEMALE = "female"
    # Privacy-respecting opt-out — added so onboarding doesn't force
    # disclosure. Backend treats this exactly like the other variants
    # (no special-casing); UI surfaces it as the third option in the
    # gender picker.
    PREFER_NOT_TO_SAY = "prefer_not_to_say"


class ReferralStatus(StrEnum):
    PENDING = "pending"
    CONVERTED = "converted"
    EXPIRED = "expired"


ENUM_DEFINITIONS: dict[str, type[StrEnum]] = {
    "tier_enum": Tier,
    "category_enum": Category,
    "role_enum": Role,
    "sub_status_enum": SubscriptionStatus,
    "payment_method_enum": PaymentMethod,
    "payment_status_enum": PaymentStatus,
    "checkin_status_enum": CheckinStatus,
    "payout_status_enum": PayoutStatus,
    "notification_type_enum": NotificationType,
    "locale_enum": Locale,
    "ticket_category_enum": TicketCategory,
    "ticket_priority_enum": TicketPriority,
    "ticket_status_enum": TicketStatus,
    "gender_enum": Gender,
    "referral_status_enum": ReferralStatus,
}
