"""day_pass_offerings + day_passes: one-off gym access for non-subscribers

Adds two new tables backing the day-use flow:

  day_pass_offerings — per-gym config row. Partners opt in, set a
  price, and configure validity. One row per gym (unique gym_id).
  When `is_enabled = false` the gym is invisible to the day-pass
  purchase flow; existing passes for that gym continue to honor
  their expiry.

  day_passes — per-purchase row. Created PENDING when the member
  taps "buy", flipped to ACTIVE the moment the payment succeeds.
  Carries the gym + offering + payment FKs, a denormalized
  price/fee/net split (so a future price change on the offering
  doesn't rewrite history), and a `used_at` / `checkin_id` pair
  that becomes non-null when the holder scans in.

Why a denormalized fee snapshot: payouts and audit-trail readers
must see the EXACT numbers the member was charged, even if the
offering's `price_jod` or `platform_fee_pct` later changes. The
offering row's values are the template for new purchases; the
day_pass row is the historical record.

Status enum: pending -> active -> (used | expired | refunded).
  pending — purchase started, payment in flight.
  active  — paid, valid for check-in.
  used    — successfully checked in (one-shot pass; multi-use is
            a future enhancement gated on offering policy).
  expired — past `expires_at` without being used.
  refunded — admin or self-service refund within the grace window.

Revision ID: 0019_day_passes
Revises: 0018_audit_log_partitioned
Create Date: 2026-05-19 00:00:00.000000

Note on the short revision id: `alembic_version.version_num` is a
varchar(32). The natural slug
`0019_day_pass_offerings_and_passes` is 35 chars and fails the
final UPDATE with a StringDataRightTruncationError, rolling back
both 0018 and 0019 atomically. Keep new revision ids <= 32 chars.
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0019_day_passes"
down_revision = "0018_audit_log_partitioned"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # Make payments.subscription_id nullable so day-pass payments can
    # exist without a subscription. Day-passes have no subscription —
    # they're a one-off SKU. Audit trail integrity is preserved by
    # the parallel `day_passes.payment_id` FK that points back.
    # ------------------------------------------------------------------
    op.alter_column(
        "payments",
        "subscription_id",
        nullable=True,
        existing_type=postgresql.UUID(as_uuid=True),
    )

    # Create the day-pass status enum before referencing it from the
    # new table. Same two-step pattern as 0017 to keep alembic from
    # auto-emitting a duplicate CREATE TYPE inside create_table.
    status_enum = postgresql.ENUM(
        "pending",
        "active",
        "used",
        "expired",
        "refunded",
        name="day_pass_status_enum",
        create_type=True,
    )
    status_enum.create(op.get_bind(), checkfirst=True)

    audience_enum_existing = postgresql.ENUM(
        "mixed",
        "female_only",
        "male_only",
        name="audience_gender_enum",
        create_type=False,
    )

    # ------------------------------------------------------------------
    # day_pass_offerings — per-gym configuration
    # ------------------------------------------------------------------
    op.create_table(
        "day_pass_offerings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "gym_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("gyms.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "is_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column("price_jod", sa.Numeric(10, 2), nullable=False),
        # Platform's cut. Default 10% but stored per-offering so
        # the admin can negotiate per-partner deals without a
        # global code change.
        sa.Column(
            "platform_fee_pct",
            sa.Numeric(5, 2),
            nullable=False,
            server_default=sa.text("10.00"),
        ),
        # Hours-from-purchase. Default 24h (calendar day pass).
        # 12h, 48h, 72h are realistic alternatives a partner could
        # ask for; store as int so the admin can override later.
        sa.Column(
            "validity_hours",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("24"),
        ),
        # Optional per-day cap on new passes. NULL = unlimited.
        # Stored now, enforced later (Phase 1.5).
        sa.Column("daily_cap", sa.Integer(), nullable=True),
        # Optional audience override. NULL means "inherit from the
        # gym's own audience_gender". Useful when a mixed gym wants
        # to sell day-passes to women only (e.g. ladies-night).
        sa.Column(
            "audience_gender_override",
            audience_enum_existing,
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint("price_jod >= 0", name="ck_day_pass_offerings_price_nonneg"),
        sa.CheckConstraint(
            "platform_fee_pct >= 0 AND platform_fee_pct <= 100",
            name="ck_day_pass_offerings_fee_pct_range",
        ),
        sa.CheckConstraint(
            "validity_hours > 0 AND validity_hours <= 168",
            name="ck_day_pass_offerings_validity_range",
        ),
        sa.CheckConstraint(
            "daily_cap IS NULL OR daily_cap > 0",
            name="ck_day_pass_offerings_daily_cap_positive",
        ),
    )
    op.create_index(
        "uq_day_pass_offerings_gym",
        "day_pass_offerings",
        ["gym_id"],
        unique=True,
    )

    # ------------------------------------------------------------------
    # day_passes — per-purchase instance
    # ------------------------------------------------------------------
    op.create_table(
        "day_passes",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "gym_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("gyms.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "offering_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("day_pass_offerings.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        # Payment FK is nullable: the row is created PENDING before
        # the payment row exists. On payment success the day-pass
        # service writes the FK and flips status to active.
        sa.Column(
            "payment_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("payments.id", ondelete="RESTRICT"),
            nullable=True,
        ),
        # Denormalized snapshot of the offering's price at purchase
        # time. Future price changes on the offering must NOT mutate
        # historical records — payouts and audit trail must reflect
        # what the member was actually charged.
        sa.Column("price_jod", sa.Numeric(10, 2), nullable=False),
        sa.Column("platform_fee_jod", sa.Numeric(10, 2), nullable=False),
        # net = price - platform_fee. Denormalized so payout
        # aggregation can SUM(net_amount_jod) directly without
        # recomputing per-row. Always equals price_jod minus
        # platform_fee_jod by construction.
        sa.Column("net_amount_jod", sa.Numeric(10, 2), nullable=False),
        sa.Column(
            "status",
            postgresql.ENUM(name="day_pass_status_enum", create_type=False),
            nullable=False,
            server_default="pending",
        ),
        sa.Column(
            "purchased_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        # Computed from purchased_at + offering.validity_hours at
        # purchase time. Stored explicitly so a future validity
        # change on the offering doesn't extend already-sold passes.
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "checkin_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("checkins.id", ondelete="RESTRICT"),
            nullable=True,
        ),
        sa.Column("refunded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "expires_at > purchased_at",
            name="ck_day_passes_expires_after_purchase",
        ),
        sa.CheckConstraint(
            "price_jod >= 0 AND platform_fee_jod >= 0 AND net_amount_jod >= 0",
            name="ck_day_passes_amounts_nonneg",
        ),
        sa.CheckConstraint(
            # Floating-point-safe equality: tolerance of 0.01 JOD.
            "abs(price_jod - platform_fee_jod - net_amount_jod) < 0.01",
            name="ck_day_passes_amounts_consistent",
        ),
    )
    # Members lookup: "my active passes" — used by Profile screen.
    op.create_index(
        "ix_day_passes_user_status",
        "day_passes",
        ["user_id", "status"],
    )
    # Check-in resolver lookup: "active pass for (user, gym) right
    # now" — partial index keyed on the only status the resolver
    # cares about, so it stays tiny.
    op.create_index(
        "ix_day_passes_active_lookup",
        "day_passes",
        ["user_id", "gym_id", "expires_at"],
        postgresql_where=sa.text("status = 'active'"),
    )
    # Reaper / expiry-sweep lookup.
    op.create_index(
        "ix_day_passes_expires_at",
        "day_passes",
        ["expires_at"],
        postgresql_where=sa.text("status = 'active'"),
    )
    # Daily-cap enforcement (Phase 1.5): "how many passes sold
    # against this offering today" — partial index on the only
    # statuses that count toward the cap.
    op.create_index(
        "ix_day_passes_offering_purchased",
        "day_passes",
        ["offering_id", "purchased_at"],
        postgresql_where=sa.text("status IN ('active','used','expired')"),
    )


def downgrade() -> None:
    # Drop in reverse-dependency order.
    op.drop_index("ix_day_passes_offering_purchased", table_name="day_passes")
    op.drop_index("ix_day_passes_expires_at", table_name="day_passes")
    op.drop_index("ix_day_passes_active_lookup", table_name="day_passes")
    op.drop_index("ix_day_passes_user_status", table_name="day_passes")
    op.drop_table("day_passes")
    op.drop_index("uq_day_pass_offerings_gym", table_name="day_pass_offerings")
    op.drop_table("day_pass_offerings")
    postgresql.ENUM(name="day_pass_status_enum").drop(
        op.get_bind(),
        checkfirst=True,
    )
    # Restore the payments.subscription_id NOT NULL constraint. This
    # downgrade can only succeed if no rows have NULL — i.e. no
    # day-pass payments survived the drop above. Day-pass rows were
    # already dropped, so any payment with NULL subscription_id is
    # orphaned and would block this rollback. Operator runs a
    # cleanup `DELETE FROM payments WHERE subscription_id IS NULL`
    # before downgrading if any exist.
    op.alter_column(
        "payments",
        "subscription_id",
        nullable=False,
        existing_type=postgresql.UUID(as_uuid=True),
    )
