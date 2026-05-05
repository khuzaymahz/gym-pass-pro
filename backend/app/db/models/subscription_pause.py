from __future__ import annotations

from datetime import date

from sqlalchemy import CheckConstraint, Date, ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import TimestampTZ, TimestampTZNullable, UUIDCol, UUIDFk


class SubscriptionPause(Base):
    """One pause window. Belongs to a single subscription, audited by row.

    A pause is in one of three states:
      - **scheduled**: `starts_on > today`. Member set it up in advance.
      - **active**: `starts_on <= today <= ends_on` and `ended_at IS NULL`.
        Check-ins are rejected with `SUB_PAUSED` while in this state.
      - **completed**: `ended_at IS NOT NULL`. The Celery night-job marks
        a pause completed when its `ends_on` rolls past today, OR a
        member's manual resume drops `ended_at = today`. Either path
        also writes `days_consumed` and shifts the parent subscription's
        `expires_at` forward by that many days, so a paused month
        doesn't burn calendar days the member couldn't use.

    Multiple pause rows per subscription are allowed (12-month plans
    permit two), but only one can be in the `scheduled OR active` state
    at a time — enforced by the partial unique index below. Completed
    rows are kept for audit and to count `pauses_used` against the
    plan's allowance.
    """

    __tablename__ = "subscription_pauses"

    id: Mapped[UUIDCol]
    subscription_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("subscriptions.id", ondelete="CASCADE"), nullable=False
    )

    starts_on: Mapped[date] = mapped_column(Date(), nullable=False)
    ends_on: Mapped[date] = mapped_column(Date(), nullable=False)

    # Set when the pause is finalised — either auto-resumed by the cron
    # at end-of-window, or manually resumed early by the member. Days
    # actually consumed equal `min(today, ends_on) - starts_on`, captured
    # in `days_consumed` so we don't have to recompute later.
    ended_at: Mapped[TimestampTZNullable]
    days_consumed: Mapped[int] = mapped_column(
        nullable=False, server_default=text("0")
    )

    created_at: Mapped[TimestampTZ]

    __table_args__ = (
        # ends_on must be on or after starts_on. Allowing same-day pauses
        # so a "took today off" UX is supported (consumes 0 days, but
        # still counts toward `pauses_used` to discourage abuse).
        CheckConstraint(
            "ends_on >= starts_on",
            name="ck_subscription_pauses_window_ordered",
        ),
        # At most one open (scheduled OR active) pause per subscription.
        # `ended_at IS NULL` is the open-state predicate; once finalised
        # the row is excluded from this index and a fresh pause can be
        # scheduled. The Celery cron sets `ended_at` so this never wedges.
        Index(
            "uq_subscription_pauses_one_open",
            "subscription_id",
            unique=True,
            postgresql_where=text("ended_at IS NULL"),
        ),
        Index(
            "ix_subscription_pauses_open_window",
            "ends_on",
            postgresql_where=text("ended_at IS NULL"),
        ),
    )
