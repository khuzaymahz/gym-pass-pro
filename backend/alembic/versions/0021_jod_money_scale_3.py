"""widen JOD money columns from Numeric(10,2) to Numeric(10,3)

JOD has 3 minor units (fils): `1.234 JOD` is legal money. Every money
column in the schema was declared `Numeric(10, 2)`, so the third
decimal was being silently rounded on every INSERT/UPDATE. Over a
payout batch this compounds — a 2.345 JOD per-visit rate becomes
2.35, off by 5 fils per check-in, multiplied across a month of
scans per gym.

This migration widens every JOD-denominated column in lock-step.
`ALTER COLUMN TYPE Numeric(p, s)` rewrites the table once per column,
which is cheap while the dataset is still small (pre-launch) and
becomes increasingly painful as rows accumulate — so doing it now
is materially less expensive than waiting.

Columns touched:
  - plans.price_jod
  - day_pass_offerings.price_jod
  - day_passes.price_jod, platform_fee_jod, net_amount_jod
  - gyms.per_visit_rate_jod (also widens server_default 2.00 → 2.000)
  - payments.amount_jod
  - payout_ledger.amount_jod, rate_applied
  - payouts.total_amount_jod (Numeric(12,2) → Numeric(12,3))

Down path narrows back to (10,2)/(12,2). PG will raise if any
existing value has 3-decimal precision that doesn't fit — that's
the correct behaviour: don't silently truncate on a rollback.

Revision ID: 0021_jod_money_scale_3
Revises: 0020_refund_and_fee
Create Date: 2026-06-19 00:00:00.000000
"""

from __future__ import annotations

from alembic import op

revision = "0021_jod_money_scale_3"
down_revision = "0020_refund_and_fee"
branch_labels = None
depends_on = None


# (table, column, new precision, new scale, server_default or None)
_WIDEN = [
    ("plans", "price_jod", 10, 3, None),
    ("day_pass_offerings", "price_jod", 10, 3, None),
    ("day_passes", "price_jod", 10, 3, None),
    ("day_passes", "platform_fee_jod", 10, 3, None),
    ("day_passes", "net_amount_jod", 10, 3, None),
    ("gyms", "per_visit_rate_jod", 10, 3, "2.000"),
    ("payments", "amount_jod", 10, 3, None),
    ("payout_ledger", "amount_jod", 10, 3, None),
    ("payout_ledger", "rate_applied", 10, 3, None),
    ("payouts", "total_amount_jod", 12, 3, None),
]


def upgrade() -> None:
    for table, column, precision, scale, default in _WIDEN:
        op.execute(
            f"ALTER TABLE {table} "
            f"ALTER COLUMN {column} TYPE NUMERIC({precision}, {scale})"
        )
        if default is not None:
            op.execute(
                f"ALTER TABLE {table} "
                f"ALTER COLUMN {column} SET DEFAULT {default}"
            )


def downgrade() -> None:
    # Narrow back. Any existing 3-decimal value will fail loudly with
    # `value overflows numeric format` — that's intentional. A
    # silent rollback truncation would lose real money.
    for table, column, precision, scale, default in _WIDEN:
        narrow_p = precision
        narrow_s = 2
        op.execute(
            f"ALTER TABLE {table} "
            f"ALTER COLUMN {column} TYPE NUMERIC({narrow_p}, {narrow_s})"
        )
        if default is not None:
            # Restore the 2-decimal default (2.00 for the gym rate).
            old_default = default.rsplit(".", 1)[0] + "." + default.rsplit(".", 1)[1][:2]
            op.execute(
                f"ALTER TABLE {table} "
                f"ALTER COLUMN {column} SET DEFAULT {old_default}"
            )
