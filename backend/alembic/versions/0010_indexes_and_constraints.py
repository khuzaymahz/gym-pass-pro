"""perf indexes, CHECK constraints, gender enum expansion

Closes the database hotspots and integrity gaps the production audit
flagged:

1. **audit_log time index** — admin queries against the audit timeline
   (`/admin/audit?since=2026-04-01`) currently full-scan the table.
2. **checkins success-only index** — the `count_success_since_for_user`
   call runs on every check-in and tier renewal; a partial index over
   only SUCCESS rows is a fraction of the size of the full index.
3. **notifications (user_id, created_at desc)** — the "my unread
   notifications" feed orders by created_at; without this index the
   planner sorts in memory.
4. **subscriptions.visits_used >= 0** — defensive CHECK; an off-by-
   one in the increment path would otherwise silently wrap negative.
5. **plans.price_jod >= 0** + **duration_months > 0** — same kind of
   guard. Existing migration only constrains monthly_visits.
6. **gender_enum.prefer_not_to_say** — added per the privacy audit;
   members shouldn't be forced to disclose. ALTER TYPE ADD VALUE
   needs autocommit (Postgres restriction).

Revision ID: 0010_indexes_and_constraints
Revises: 0009_payment_method_google_pay
Create Date: 2026-05-01 00:30:00.000000

NOTE: Alembic's default `alembic_version.version_num` column is
`varchar(32)`. The previous revision id `0010_perf_indexes_and_constraints`
was 33 characters and overflowed on `INSERT INTO alembic_version`,
producing `StringDataRightTruncationError`. Keep new revision ids
≤ 32 chars or upgrade the alembic_version column width.
"""

from __future__ import annotations

from alembic import op

revision = "0010_indexes_and_constraints"
down_revision = "0009_payment_method_google_pay"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ---------- Indexes ----------
    # `IF NOT EXISTS` so a re-run after a partial failure doesn't
    # explode on already-present index names.
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_audit_log_created_at "
        "ON audit_log (created_at DESC)"
    )
    # Partial index — the only checkins scan we run for tier-budget
    # accounting cares only about SUCCESS rows. Keeps the index ~80%
    # smaller than a full per-status index would be.
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_checkins_success_user_scanned_at "
        "ON checkins (user_id, scanned_at DESC) "
        "WHERE status = 'success'"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_notifications_user_created "
        "ON notifications (user_id, created_at DESC)"
    )

    # ---------- CHECK constraints ----------
    # Wrap each in a try/except via plain SQL `IF NOT EXISTS` because
    # Alembic's `add_check_constraint` doesn't support IF NOT EXISTS
    # natively, and the migrator container shouldn't fail on a re-run.
    op.execute(
        "ALTER TABLE subscriptions "
        "DROP CONSTRAINT IF EXISTS ck_subscriptions_visits_used_nonneg"
    )
    op.execute(
        "ALTER TABLE subscriptions "
        "ADD CONSTRAINT ck_subscriptions_visits_used_nonneg "
        "CHECK (visits_used >= 0)"
    )
    op.execute(
        "ALTER TABLE plans "
        "DROP CONSTRAINT IF EXISTS ck_plans_price_jod_nonneg"
    )
    op.execute(
        "ALTER TABLE plans "
        "ADD CONSTRAINT ck_plans_price_jod_nonneg "
        "CHECK (price_jod >= 0)"
    )
    op.execute(
        "ALTER TABLE plans "
        "DROP CONSTRAINT IF EXISTS ck_plans_duration_months_positive"
    )
    op.execute(
        "ALTER TABLE plans "
        "ADD CONSTRAINT ck_plans_duration_months_positive "
        "CHECK (duration_months > 0)"
    )

    # ---------- Gender enum expansion ----------
    # ALTER TYPE … ADD VALUE cannot run inside a transaction in some
    # Postgres configurations; run in an autocommit block to be safe.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE gender_enum ADD VALUE IF NOT EXISTS 'prefer_not_to_say'"
        )


def downgrade() -> None:
    # Indexes are safe to drop on rollback.
    op.execute("DROP INDEX IF EXISTS ix_audit_log_created_at")
    op.execute("DROP INDEX IF EXISTS ix_checkins_success_user_scanned_at")
    op.execute("DROP INDEX IF EXISTS ix_notifications_user_created")
    # CHECK constraints — drop only the ones we added.
    op.execute(
        "ALTER TABLE subscriptions "
        "DROP CONSTRAINT IF EXISTS ck_subscriptions_visits_used_nonneg"
    )
    op.execute(
        "ALTER TABLE plans "
        "DROP CONSTRAINT IF EXISTS ck_plans_price_jod_nonneg"
    )
    op.execute(
        "ALTER TABLE plans "
        "DROP CONSTRAINT IF EXISTS ck_plans_duration_months_positive"
    )
    # Postgres has no native DROP VALUE on enums; leave the new
    # gender variant in place on downgrade. Same rationale as
    # 0009_payment_method_google_pay.
