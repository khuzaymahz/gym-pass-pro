"""partner-dashboard hot-path indexes

The partner overview endpoint (`GET /api/v1/partner/gym/metrics/overview`)
issues ~12 sequential aggregate queries on every render. Six of them
filter `checkins` by `(gym_id, status='success', scanned_at >= since)`
and two filter `payout_ledger` by `(gym_id, created_at >= since)`.

Existing coverage:
- `ix_checkins_gym_scanned_at` (gym_id, scanned_at) — unfiltered. The
  planner uses it but still fetches non-success rows from the heap and
  filters them out, which is wasted work on a table where the success
  ratio is already ~95%+ but skews under failure spikes.
- `ix_checkins_success_user_scanned_at` (user_id, scanned_at) WHERE
  status='success' — sized for the per-user tier-budget check, NOT
  for per-gym aggregates.
- `ix_payout_ledger_gym_payout` (gym_id, payout_id) — covers the
  admin "what's in this batch" lookup, NOT the time-bucketed dashboard
  sums.

Two new partial indexes close the gap:

1. `ix_checkins_gym_success_scanned` (gym_id, scanned_at DESC) WHERE
   status='success' — mirror of the user-keyed partial. Smaller than a
   full per-(gym, status) index because failures are filtered out;
   directly satisfies the partner aggregate WHERE clause without a
   recheck.

2. `ix_payout_ledger_gym_created` (gym_id, created_at DESC) — drives
   `_success_payout_sum` and `_revenue_per_day_since`. The existing
   composite on `(gym_id, payout_id)` answers a different question
   (which entries belong to a batch) and can't satisfy a time-range
   sum efficiently.

Both use `IF NOT EXISTS` so reruns after a partial deploy are safe.
We deliberately don't `CONCURRENTLY` here because the migrator runs
once at deploy time on a small dataset; if the partner dashboard
ever grows to scale where index builds block writes, switch to
`CREATE INDEX CONCURRENTLY` in a separate post-deploy step.

Revision ID: 0014_partner_indexes
Revises: 0013_users_gym_id
Create Date: 2026-05-09 04:00:00.000000
"""

from __future__ import annotations

from alembic import op


revision = "0014_partner_indexes"
down_revision = "0013_users_gym_id"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_checkins_gym_success_scanned "
        "ON checkins (gym_id, scanned_at DESC) "
        "WHERE status = 'success'"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_payout_ledger_gym_created "
        "ON payout_ledger (gym_id, created_at DESC)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_checkins_gym_success_scanned")
    op.execute("DROP INDEX IF EXISTS ix_payout_ledger_gym_created")
