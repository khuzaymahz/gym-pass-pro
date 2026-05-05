"""init schema

Revision ID: 0001_init
Revises:
Create Date: 2026-04-21 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0001_init"
down_revision = None
branch_labels = None
depends_on = None


TIER = ("silver", "gold", "emerald", "diamond")
CATEGORY = ("gym", "crossfit", "martial", "yoga")
ROLE = ("member", "admin")
SUB_STATUS = ("pending", "active", "expired", "cancelled")
PAYMENT_METHOD = ("card", "cliq", "apple_pay", "mock")
PAYMENT_STATUS = ("pending", "succeeded", "failed")
CHECKIN_STATUS = (
    "success", "tier_locked", "no_visits", "expired", "invalid_qr", "rate_limited",
)
PAYOUT_STATUS = ("pending", "paid")
NOTIF_TYPE = ("expire", "checkin", "promo", "guest", "system")
LOCALE = ("ar", "en")


def _create_enum(name: str, values: tuple[str, ...]) -> postgresql.ENUM:
    values_sql = ", ".join(f"'{v}'" for v in values)
    op.execute(
        f"DO $$ BEGIN "
        f"IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = '{name}') THEN "
        f"CREATE TYPE {name} AS ENUM ({values_sql}); "
        f"END IF; END $$;"
    )
    return postgresql.ENUM(*values, name=name, create_type=False)


def upgrade() -> None:
    tier_enum = _create_enum("tier_enum", TIER)
    category_enum = _create_enum("category_enum", CATEGORY)
    role_enum = _create_enum("role_enum", ROLE)
    sub_status_enum = _create_enum("sub_status_enum", SUB_STATUS)
    payment_method_enum = _create_enum("payment_method_enum", PAYMENT_METHOD)
    payment_status_enum = _create_enum("payment_status_enum", PAYMENT_STATUS)
    checkin_status_enum = _create_enum("checkin_status_enum", CHECKIN_STATUS)
    payout_status_enum = _create_enum("payout_status_enum", PAYOUT_STATUS)
    notif_type_enum = _create_enum("notification_type_enum", NOTIF_TYPE)
    locale_enum = _create_enum("locale_enum", LOCALE)

    # users
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("phone", sa.Text(), nullable=True),
        sa.Column("email", sa.Text(), nullable=True),
        sa.Column("name", sa.Text(), nullable=True),
        sa.Column("google_sub", sa.Text(), nullable=True),
        sa.Column("password_hash", sa.Text(), nullable=True),
        sa.Column("role", role_enum, nullable=False, server_default="member"),
        sa.Column("locale", locale_enum, nullable=False, server_default="ar"),
        sa.Column("avatar_url", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "phone IS NOT NULL OR email IS NOT NULL OR google_sub IS NOT NULL",
            name="ck_users_identity",
        ),
    )
    op.create_index(
        "uq_users_phone", "users", ["phone"], unique=True,
        postgresql_where=sa.text("phone IS NOT NULL AND deleted_at IS NULL"),
    )
    op.create_index(
        "uq_users_email", "users", ["email"], unique=True,
        postgresql_where=sa.text("email IS NOT NULL AND deleted_at IS NULL"),
    )
    op.create_index(
        "uq_users_google_sub", "users", ["google_sub"], unique=True,
        postgresql_where=sa.text("google_sub IS NOT NULL"),
    )
    op.create_index("ix_users_role", "users", ["role"])

    # otp_codes
    op.create_table(
        "otp_codes",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("phone", sa.Text(), nullable=False),
        sa.Column("code_hash", sa.Text(), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_otp_codes_phone_expires", "otp_codes",
                    ["phone", "expires_at"])

    # gyms
    op.create_table(
        "gyms",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("slug", sa.Text(), nullable=False),
        sa.Column("name_en", sa.Text(), nullable=False),
        sa.Column("name_ar", sa.Text(), nullable=False),
        sa.Column("address_en", sa.Text(), nullable=False),
        sa.Column("address_ar", sa.Text(), nullable=False),
        sa.Column("area", sa.Text(), nullable=False),
        sa.Column("lat", sa.Numeric(9, 6), nullable=False),
        sa.Column("lng", sa.Numeric(9, 6), nullable=False),
        sa.Column("phone", sa.Text(), nullable=True),
        sa.Column("category", category_enum, nullable=False),
        sa.Column("required_tier", tier_enum, nullable=False, server_default="silver"),
        sa.Column("per_visit_rate_jod", sa.Numeric(10, 2), nullable=False,
                  server_default="2.00"),
        sa.Column("rating", sa.Numeric(2, 1), nullable=True),
        sa.Column("review_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("cover_image_url", sa.Text(), nullable=True),
        sa.Column("amenities", postgresql.JSONB(), nullable=False,
                  server_default=sa.text("'[]'::jsonb")),
        sa.Column("opening_hours", postgresql.JSONB(), nullable=False,
                  server_default=sa.text("'{}'::jsonb")),
        sa.Column("is_active", sa.Boolean(), nullable=False,
                  server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("slug", name="uq_gyms_slug"),
    )
    op.create_index(
        "ix_gyms_category_required_tier", "gyms", ["category", "required_tier"]
    )
    op.create_index(
        "ix_gyms_is_active", "gyms", ["is_active"],
        postgresql_where=sa.text("is_active = true AND deleted_at IS NULL"),
    )
    op.create_index("ix_gyms_area", "gyms", ["area"])

    # plans
    op.create_table(
        "plans",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("tier", tier_enum, nullable=False),
        sa.Column("duration_months", sa.Integer(), nullable=False),
        sa.Column("price_jod", sa.Numeric(10, 2), nullable=False),
        sa.Column("monthly_visits", sa.Integer(), nullable=False),
        sa.Column("included_gym_count", sa.Integer(), nullable=False),
        sa.Column("features_en", postgresql.JSONB(), nullable=False,
                  server_default=sa.text("'[]'::jsonb")),
        sa.Column("features_ar", postgresql.JSONB(), nullable=False,
                  server_default=sa.text("'[]'::jsonb")),
        sa.Column("discount_percent", sa.Numeric(5, 2), nullable=False,
                  server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False,
                  server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("tier", "duration_months", name="uq_plans_tier_duration"),
        sa.CheckConstraint("monthly_visits > 0", name="ck_plans_monthly_visits_positive"),
    )

    # subscriptions
    op.create_table(
        "subscriptions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("plan_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("tier", tier_enum, nullable=False),
        sa.Column("status", sub_status_enum, nullable=False, server_default="pending"),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("visits_used", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("auto_renew", sa.Boolean(), nullable=False,
                  server_default=sa.text("false")),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"],
                                name="fk_subscriptions_user_id_users",
                                ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["plan_id"], ["plans.id"],
                                name="fk_subscriptions_plan_id_plans",
                                ondelete="RESTRICT"),
    )
    op.create_index(
        "uq_subscriptions_active_per_user", "subscriptions", ["user_id"],
        unique=True, postgresql_where=sa.text("status = 'active'"),
    )
    op.create_index(
        "ix_subscriptions_user_status", "subscriptions", ["user_id", "status"]
    )
    op.create_index("ix_subscriptions_expires_at", "subscriptions", ["expires_at"])

    # payments
    op.create_table(
        "payments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("subscription_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("amount_jod", sa.Numeric(10, 2), nullable=False),
        sa.Column("method", payment_method_enum, nullable=False),
        sa.Column("gateway_txn_id", sa.Text(), nullable=True),
        sa.Column("status", payment_status_enum, nullable=False, server_default="pending"),
        sa.Column("raw_response", postgresql.JSONB(), nullable=False,
                  server_default=sa.text("'{}'::jsonb")),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["subscription_id"], ["subscriptions.id"],
            name="fk_payments_subscription_id_subscriptions",
            ondelete="RESTRICT",
        ),
    )
    op.create_index("ix_payments_subscription_id", "payments", ["subscription_id"])
    op.create_index(
        "ix_payments_gateway_txn_id", "payments", ["gateway_txn_id"], unique=True,
        postgresql_where=sa.text("gateway_txn_id IS NOT NULL"),
    )

    # checkins
    op.create_table(
        "checkins",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("gym_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("subscription_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("scanned_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("ip_address", postgresql.INET(), nullable=True),
        sa.Column("user_agent", sa.Text(), nullable=True),
        sa.Column("status", checkin_status_enum, nullable=False),
        sa.Column("failure_reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"],
                                name="fk_checkins_user_id_users",
                                ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["gym_id"], ["gyms.id"],
                                name="fk_checkins_gym_id_gyms",
                                ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["subscription_id"], ["subscriptions.id"],
                                name="fk_checkins_subscription_id_subscriptions",
                                ondelete="RESTRICT"),
    )
    op.create_index("ix_checkins_user_scanned_at", "checkins",
                    ["user_id", "scanned_at"])
    op.create_index("ix_checkins_gym_scanned_at", "checkins",
                    ["gym_id", "scanned_at"])
    op.create_index(
        "ix_checkins_status", "checkins", ["status"],
        postgresql_where=sa.text("status <> 'success'"),
    )

    # payouts (before payout_ledger — ledger FKs into it)
    op.create_table(
        "payouts",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("gym_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("period_start", sa.Date(), nullable=False),
        sa.Column("period_end", sa.Date(), nullable=False),
        sa.Column("total_amount_jod", sa.Numeric(12, 2), nullable=False),
        sa.Column("entry_count", sa.Integer(), nullable=False),
        sa.Column("status", payout_status_enum, nullable=False, server_default="pending"),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["gym_id"], ["gyms.id"],
                                name="fk_payouts_gym_id_gyms",
                                ondelete="RESTRICT"),
        sa.UniqueConstraint("gym_id", "period_start", "period_end",
                            name="uq_payouts_gym_period"),
    )
    op.create_index(
        "ix_payouts_status", "payouts", ["status"],
        postgresql_where=sa.text("status = 'pending'"),
    )

    # payout_ledger
    op.create_table(
        "payout_ledger",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("gym_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("checkin_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("amount_jod", sa.Numeric(10, 2), nullable=False),
        sa.Column("rate_applied", sa.Numeric(10, 2), nullable=False),
        sa.Column("payout_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["gym_id"], ["gyms.id"],
                                name="fk_payout_ledger_gym_id_gyms",
                                ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["checkin_id"], ["checkins.id"],
                                name="fk_payout_ledger_checkin_id_checkins",
                                ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["payout_id"], ["payouts.id"],
                                name="fk_payout_ledger_payout_id_payouts",
                                ondelete="RESTRICT"),
        sa.UniqueConstraint("checkin_id", name="uq_payout_ledger_checkin_id"),
    )
    op.create_index("ix_payout_ledger_gym_payout", "payout_ledger",
                    ["gym_id", "payout_id"])

    # notifications
    op.create_table(
        "notifications",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("type", notif_type_enum, nullable=False),
        sa.Column("title_en", sa.Text(), nullable=False),
        sa.Column("title_ar", sa.Text(), nullable=False),
        sa.Column("body_en", sa.Text(), nullable=False),
        sa.Column("body_ar", sa.Text(), nullable=False),
        sa.Column("deep_link", sa.Text(), nullable=True),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"],
                                name="fk_notifications_user_id_users",
                                ondelete="CASCADE"),
    )
    op.create_index(
        "ix_notifications_user_unread", "notifications",
        ["user_id", "created_at"],
        postgresql_where=sa.text("read_at IS NULL"),
    )

    # audit_log
    op.create_table(
        "audit_log",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("actor_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("actor_role", role_enum, nullable=True),
        sa.Column("action", sa.Text(), nullable=False),
        sa.Column("entity_type", sa.Text(), nullable=False),
        sa.Column("entity_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("diff_json", postgresql.JSONB(), nullable=False,
                  server_default=sa.text("'{}'::jsonb")),
        sa.Column("ip_address", postgresql.INET(), nullable=True),
        sa.Column("user_agent", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"],
                                name="fk_audit_log_actor_user_id_users",
                                ondelete="SET NULL"),
    )
    op.create_index("ix_audit_log_entity", "audit_log",
                    ["entity_type", "entity_id", "created_at"])
    op.create_index("ix_audit_log_actor_created", "audit_log",
                    ["actor_user_id", "created_at"])

    # refresh_tokens
    op.create_table(
        "refresh_tokens",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("device_info", sa.Text(), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"],
                                name="fk_refresh_tokens_user_id_users",
                                ondelete="CASCADE"),
    )
    op.create_index(
        "ix_refresh_tokens_user_revoked", "refresh_tokens", ["user_id"],
        postgresql_where=sa.text("revoked_at IS NULL"),
    )


def downgrade() -> None:
    for table in [
        "refresh_tokens", "audit_log", "notifications", "payout_ledger", "payouts",
        "checkins", "payments", "subscriptions", "plans", "gyms", "otp_codes", "users",
    ]:
        op.drop_table(table)

    for enum_name in [
        "locale_enum", "notification_type_enum", "payout_status_enum",
        "checkin_status_enum", "payment_status_enum", "payment_method_enum",
        "sub_status_enum", "role_enum", "category_enum", "tier_enum",
    ]:
        postgresql.ENUM(name=enum_name).drop(op.get_bind(), checkfirst=True)
