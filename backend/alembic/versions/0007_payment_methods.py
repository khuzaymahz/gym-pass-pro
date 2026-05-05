"""payment_methods table

Member-saved payment methods. The mock provider tokenizes the entry so
nothing card-shaped (PAN, CVV) ever lands here — only display-safe last4
plus a gateway token.

Revision ID: 0007_payment_methods
Revises: 0006_gym_logo
Create Date: 2026-04-30 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0007_payment_methods"
down_revision = "0006_gym_logo"
branch_labels = None
depends_on = None


def upgrade() -> None:
    payment_method_enum = postgresql.ENUM(
        "card", "cliq", "apple_pay", "mock",
        name="payment_method_enum",
        create_type=False,
    )

    op.create_table(
        "payment_methods",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("kind", payment_method_enum, nullable=False),
        sa.Column("label", sa.Text(), nullable=False),
        sa.Column(
            "last4", sa.Text(), nullable=False, server_default=sa.text("''")
        ),
        sa.Column("holder", sa.Text(), nullable=True),
        sa.Column("expiry_mm", sa.Integer(), nullable=True),
        sa.Column("expiry_yy", sa.Integer(), nullable=True),
        sa.Column("cliq_alias", sa.Text(), nullable=True),
        sa.Column("cliq_phone", sa.Text(), nullable=True),
        sa.Column("gateway_token", sa.Text(), nullable=True),
        sa.Column(
            "is_default",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            server_onupdate=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "deleted_at", sa.DateTime(timezone=True), nullable=True
        ),
        sa.CheckConstraint(
            "(kind <> 'card') OR ("
            "expiry_mm IS NOT NULL AND expiry_yy IS NOT NULL"
            ")",
            name="ck_payment_methods_card_has_expiry",
        ),
        sa.CheckConstraint(
            "(kind <> 'cliq') OR ("
            "cliq_alias IS NOT NULL OR cliq_phone IS NOT NULL"
            ")",
            name="ck_payment_methods_cliq_has_identifier",
        ),
    )
    op.create_index(
        "ix_payment_methods_user_active",
        "payment_methods",
        ["user_id"],
        postgresql_where=sa.text("deleted_at IS NULL"),
    )
    op.create_index(
        "uq_payment_methods_user_default",
        "payment_methods",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("is_default = true AND deleted_at IS NULL"),
    )


def downgrade() -> None:
    op.drop_index("uq_payment_methods_user_default", table_name="payment_methods")
    op.drop_index("ix_payment_methods_user_active", table_name="payment_methods")
    op.drop_table("payment_methods")
