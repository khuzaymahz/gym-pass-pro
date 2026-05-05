"""subscription_pauses table

One pause window per row. Members can schedule a pause in advance
(`starts_on > today`), enter it (`starts_on <= today <= ends_on`,
`ended_at IS NULL`), and exit it (auto-resumed by Celery cron at
window end, or manually resumed early — either path sets `ended_at`
plus `days_consumed`). Partial unique index keeps one open pause per
subscription. Completed pauses stay for audit.

Revision ID: 0008_subscription_pauses
Revises: 0007_payment_methods
Create Date: 2026-04-30 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0008_subscription_pauses"
down_revision = "0007_payment_methods"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "subscription_pauses",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "subscription_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("subscriptions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("starts_on", sa.Date(), nullable=False),
        sa.Column("ends_on", sa.Date(), nullable=False),
        sa.Column(
            "ended_at", sa.DateTime(timezone=True), nullable=True
        ),
        sa.Column(
            "days_consumed",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("0"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "ends_on >= starts_on",
            name="ck_subscription_pauses_window_ordered",
        ),
    )
    op.create_index(
        "uq_subscription_pauses_one_open",
        "subscription_pauses",
        ["subscription_id"],
        unique=True,
        postgresql_where=sa.text("ended_at IS NULL"),
    )
    op.create_index(
        "ix_subscription_pauses_open_window",
        "subscription_pauses",
        ["ends_on"],
        postgresql_where=sa.text("ended_at IS NULL"),
    )


def downgrade() -> None:
    op.drop_index(
        "ix_subscription_pauses_open_window",
        table_name="subscription_pauses",
    )
    op.drop_index(
        "uq_subscription_pauses_one_open",
        table_name="subscription_pauses",
    )
    op.drop_table("subscription_pauses")
