"""payments.refunded + tighten day-pass platform_fee_pct

Two small bundled changes — both quick column/constraint edits, no
table rewrites:

1. Add `refunded` to `payment_status_enum`. The compensation path
   in `SubscriptionService.purchase` / `DayPassService.purchase`
   needs a status to flip the payment to when an activation fails
   AFTER a successful charge (money leaves, mutation can't land,
   gateway gets reversed). Without the enum value, the audit
   trail can only carry "succeeded" or "failed" — both wrong for
   a payment that was charged and then refunded.

2. Tighten `ck_day_pass_offerings_fee_pct_range`: was
   `>= 0 AND <= 100`, now `>= 0 AND < 100`. A 100% platform fee
   means the gym sells day-passes for full price and receives
   ZERO JOD per redemption — silent zero-payout. No reasonable
   business arrangement maps to that; clamping it `< 100`
   guarantees the partner always gets a positive cut.

Revision ID: 0020_refund_and_fee
Revises: 0019_day_passes
Create Date: 2026-05-20 00:00:00.000000
"""

from __future__ import annotations

from alembic import op

revision = "0020_refund_and_fee"
down_revision = "0019_day_passes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Add `refunded` to the existing payment_status_enum.
    # `ALTER TYPE ... ADD VALUE IF NOT EXISTS` is safe on Postgres
    # 16 and idempotent if this migration is re-run after a
    # partial failure. The IF NOT EXISTS also lets a freshly-
    # recreated test DB skip the value-add without complaint.
    op.execute(
        "ALTER TYPE payment_status_enum ADD VALUE IF NOT EXISTS 'refunded'"
    )

    # 2. Tighten the day-pass fee constraint. Drop + recreate so
    # the new check is visible in pg_constraint without needing
    # to re-create the table.
    op.execute(
        "ALTER TABLE day_pass_offerings "
        "DROP CONSTRAINT IF EXISTS ck_day_pass_offerings_fee_pct_range"
    )
    op.execute(
        "ALTER TABLE day_pass_offerings "
        "ADD CONSTRAINT ck_day_pass_offerings_fee_pct_range "
        "CHECK (platform_fee_pct >= 0 AND platform_fee_pct < 100)"
    )


def downgrade() -> None:
    # Restore the looser constraint. We CAN'T remove the `refunded`
    # enum value via standard ALTER TYPE — Postgres has no
    # supported drop-value syntax pre-15-ish and trying to do it
    # via the system catalog is destructive if any payment row
    # has been flipped to `refunded`. Operators rolling back
    # should accept that the enum keeps the extra value and
    # confirm zero rows reference it before proceeding.
    op.execute(
        "ALTER TABLE day_pass_offerings "
        "DROP CONSTRAINT IF EXISTS ck_day_pass_offerings_fee_pct_range"
    )
    op.execute(
        "ALTER TABLE day_pass_offerings "
        "ADD CONSTRAINT ck_day_pass_offerings_fee_pct_range "
        "CHECK (platform_fee_pct >= 0 AND platform_fee_pct <= 100)"
    )
