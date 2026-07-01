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


class PartnerAccessRole(StrEnum):
    """How a partner user relates to a gym in `partner_access`.

    owner   — full control of the branch; a chain owner holds an
              `owner` row on every branch (one login, all branches).
    manager — branch-level staff: operates one branch only.
    """

    OWNER = "owner"
    MANAGER = "manager"


class AdminScope(StrEnum):
    """Sub-role for `Role.ADMIN` users.

    Stored as a nullable text column on `User`; null is treated as
    `super` for back-compat with the bootstrap admin and admins
    created before this column existed. Newly minted admins default
    to `ops` — `super` must be granted explicitly by a SUPER_ADMIN.

    Capability matrix (enforced in [api/deps.py]):
      super  — every admin action, including create/reset/delete-
               admin, broadcast, generate-payouts, hard-delete gym.
      ops    — day-to-day operator: read everything; mutate
               subscriptions, plans, checkins, support tickets,
               photos; mark payouts paid; review partner apps.
      viewer — read-only; safe for analysts / contractors.
    """

    SUPER = "super"
    OPS = "ops"
    VIEWER = "viewer"


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
    """Lifecycle of a single payment row.

    `refunded` is set when a successful charge was reversed by the
    compensation path — payment-then-activate failure, admin-issued
    refund, etc. The original `succeeded` row never becomes
    `refunded` in place: a sibling row with the same `gateway_txn_id`
    and a negative-amount-equivalent is written? No — we mutate the
    original row's status to `refunded` and stamp `processed_at`
    with the refund time. The `raw_response` JSONB carries the
    refund txn id under `refund_txn_id` for reconciliation.
    """

    PENDING = "pending"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    REFUNDED = "refunded"


class CheckinStatus(StrEnum):
    SUCCESS = "success"
    TIER_LOCKED = "tier_locked"
    GENDER_LOCKED = "gender_locked"
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
    """Member's declared gender.

    Two values only — the registration form makes one of them
    mandatory, and the value drives gym-audience visibility (a male
    member never sees a `female_only` venue and vice versa, see
    `gym_service.audience_visible_for`).

    A historic `prefer_not_to_say` value still exists in the Postgres
    `gender_enum` (added by migration 0010) but is no longer surfaced
    in Python or any UI; the seed audit confirmed zero rows used it
    before it was retired.
    """

    MALE = "male"
    FEMALE = "female"


class ReferralStatus(StrEnum):
    PENDING = "pending"
    CONVERTED = "converted"
    EXPIRED = "expired"


class ApplicationStatus(StrEnum):
    """Lifecycle states for a partner onboarding application.

    `pending` — submitted via the public partner /join form, no gym
    or user created yet, awaiting admin review.
    `approved` — admin clicked Approve; a `Gym` and a gym-owner
    `User` were created from the application, both back-referenced
    via FK so the audit trail is preserved.
    `rejected` — admin clicked Reject; the row stays for audit but
    no gym/user is created.
    """

    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class DayPassStatus(StrEnum):
    """Lifecycle of a single day-pass purchase.

    `pending` — purchase started, payment in flight. Rows in this
    state are short-lived; the day-pass service flips to either
    `active` or aborts on payment failure.
    `active`  — paid for, valid for check-in, not yet expired.
    `used`    — successfully checked in with this pass. One-shot:
    a second scan within the validity window goes through the
    re-entry rate-limit, not via the pass.
    `expired` — past `expires_at` without a check-in. Set by the
    expiry-sweep task.
    `refunded`— admin or self-service refund within the grace
    window. Becomes ineligible for check-in.
    """

    PENDING = "pending"
    ACTIVE = "active"
    USED = "used"
    EXPIRED = "expired"
    REFUNDED = "refunded"


class AudienceGender(StrEnum):
    """Which members a gym serves.

    `mixed` is the everyone-welcome default — most commercial gyms
    in Jordan are mixed. `female_only` and `male_only` exist because
    a meaningful chunk of the local market is single-sex (women-only
    studios are common; men-only is rarer but exists for some
    martial-arts dojos and barbell halls). Members can filter by this
    on the explore page and partners declare it on their gym profile.
    """

    MIXED = "mixed"
    FEMALE_ONLY = "female_only"
    MALE_ONLY = "male_only"


ENUM_DEFINITIONS: dict[str, type[StrEnum]] = {
    "tier_enum": Tier,
    "category_enum": Category,
    "role_enum": Role,
    "admin_scope_enum": AdminScope,
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
    "audience_gender_enum": AudienceGender,
    "application_status_enum": ApplicationStatus,
    "day_pass_status_enum": DayPassStatus,
}
