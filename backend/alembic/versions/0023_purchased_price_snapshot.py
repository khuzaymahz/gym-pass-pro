"""subscriptions.purchased_price_jod snapshot

Captures the JOD amount the member actually paid at purchase time so
later plan-price edits don't retroactively rewrite history. Existing
rows backfill from `plans.price_jod` because nothing has been edited
yet — going forward, `Plan.price_jod` is mutable and the historical
truth lives on the subscription row.

Without this column, `AdminUserDetailService` (admin user-detail page),
member receipts, and the audit-log diffs all back-join `Plan` to render
the historical amount — and lie about it the moment an admin changes
the price.

Revision ID: 0023_purchased_price_snapshot
Revises: 0022_admin_scope_token_ver
Create Date: 2026-06-19 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0023_purchased_price_snapshot"
down_revision = "0022_admin_scope_token_ver"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "subscriptions",
        sa.Column(
            "purchased_price_jod",
            sa.Numeric(10, 3),
            nullable=True,
        ),
    )
    # Backfill: every existing subscription paid the plan's current
    # price (which is also its only known price — no admin price
    # edits have happened yet). New rows always populate this via
    # `SubscriptionRepository.create_pending`.
    op.execute(
        "UPDATE subscriptions s "
        "SET purchased_price_jod = p.price_jod "
        "FROM plans p "
        "WHERE p.id = s.plan_id "
        "AND s.purchased_price_jod IS NULL"
    )


def downgrade() -> None:
    op.drop_column("subscriptions", "purchased_price_jod")
