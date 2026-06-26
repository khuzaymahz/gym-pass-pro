"""supporting indexes for un-indexed foreign keys

Postgres does NOT auto-create an index for a foreign-key column. Without
one, (a) joins/filters on the column seq-scan as the table grows and
(b) deleting/updating the *parent* row seq-scans (and locks) the child
table to enforce the FK action (RESTRICT / SET NULL / CASCADE).

This adds the missing FK indexes the schema audit flagged.

Note: plain (transactional) CREATE INDEX — fine at current volume. If a
table later grows large in a live, write-heavy DB, recreate the index
with `CREATE INDEX CONCURRENTLY` (outside a transaction) instead.

Revision ID: 0024_fk_supporting_indexes
Revises: 0023_purchased_price_snapshot
Create Date: 2026-06-26 00:00:00.000000
"""

from __future__ import annotations

from alembic import op

revision = "0024_fk_supporting_indexes"
down_revision = "0023_purchased_price_snapshot"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index("ix_checkins_subscription_id", "checkins", ["subscription_id"])
    op.create_index("ix_subscriptions_plan_id", "subscriptions", ["plan_id"])
    op.create_index(
        "ix_partner_applications_reviewed_by",
        "partner_applications",
        ["reviewed_by_user_id"],
    )
    op.create_index(
        "ix_partner_applications_approved_gym",
        "partner_applications",
        ["approved_gym_id"],
    )
    op.create_index(
        "ix_partner_applications_approved_owner",
        "partner_applications",
        ["approved_owner_user_id"],
    )
    op.create_index("ix_day_passes_payment_id", "day_passes", ["payment_id"])
    op.create_index("ix_day_passes_checkin_id", "day_passes", ["checkin_id"])
    op.create_index(
        "ix_support_ticket_messages_author",
        "support_ticket_messages",
        ["author_user_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_support_ticket_messages_author", table_name="support_ticket_messages")
    op.drop_index("ix_day_passes_checkin_id", table_name="day_passes")
    op.drop_index("ix_day_passes_payment_id", table_name="day_passes")
    op.drop_index("ix_partner_applications_approved_owner", table_name="partner_applications")
    op.drop_index("ix_partner_applications_approved_gym", table_name="partner_applications")
    op.drop_index("ix_partner_applications_reviewed_by", table_name="partner_applications")
    op.drop_index("ix_subscriptions_plan_id", table_name="subscriptions")
    op.drop_index("ix_checkins_subscription_id", table_name="checkins")
