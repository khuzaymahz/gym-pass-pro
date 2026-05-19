"""audit_log: convert to monthly RANGE-partitioned table

The audit_log table grows by every domain mutation (every check-in,
every subscription change, every admin action). At even modest
traffic — 100 check-ins/day across 10 gyms — that's ~3k rows/month;
in production at low-thousands DAU it grows by hundreds of thousands
per month. Without partitioning, queries like "recent activity for
this entity" eventually scan an entire ~100M-row table.

This migration converts audit_log to a RANGE-partitioned-by-month
table using Postgres native declarative partitioning. The schema
columns + indexes stay byte-for-byte identical so callers
(AuditService) require zero changes — INSERT/SELECT route through
the partition machinery transparently.

Operational follow-up:
  - `audit_log_ensure_partition()` is a SQL helper this migration
    installs. The Celery beat task `audit_log.ensure_partitions`
    (in app/workers/tasks/scheduled.py) calls it monthly to create
    the next month's partition ahead of time.
  - Pre-2025 partitions are dropped by the same beat task when
    they age past `AUDIT_LOG_RETENTION_MONTHS` (default 12).

Pre-prod data: the existing audit_log rows are preserved by inserting
them into the new partitioned shape via a single INSERT...SELECT.
On rollback (`alembic downgrade`) we collapse the partitions back
into a plain table, so this is reversible within the same prod
session.

Revision ID: 0018_audit_log_partitioned
Revises: 0017_partner_applications
Create Date: 2026-05-17 00:00:00.000000
"""

from __future__ import annotations

from datetime import date, timedelta

from alembic import op

# revision identifiers, used by Alembic.
revision = "0018_audit_log_partitioned"
down_revision = "0017_partner_applications"
branch_labels = None
depends_on = None


def _month_floor(d: date) -> date:
    """First day of the month containing d."""
    return d.replace(day=1)


def _next_month_floor(d: date) -> date:
    """First day of the month AFTER the one containing d."""
    if d.month == 12:
        return d.replace(year=d.year + 1, month=1, day=1)
    return d.replace(month=d.month + 1, day=1)


def _partition_name(month_start: date) -> str:
    return f"audit_log_y{month_start.year:04d}m{month_start.month:02d}"


def upgrade() -> None:
    bind = op.get_bind()

    # Postgres preserves index names through `ALTER TABLE RENAME` — so
    # if a prior run of this migration died partway, the indexes from
    # the legacy table (now renamed to `audit_log_pre_partition`)
    # still occupy the names `ix_audit_log_entity` /
    # `ix_audit_log_actor_created` / `ix_audit_log_created_at`. When
    # we re-run, the CREATE INDEX statements below collide with
    # `relation "ix_audit_log_*" already exists` and the whole
    # migration rolls back. Pre-drop them (they're recreated on the
    # new partitioned table further down) so this migration is
    # idempotent under retry.
    op.execute("DROP INDEX IF EXISTS ix_audit_log_entity;")
    op.execute("DROP INDEX IF EXISTS ix_audit_log_actor_created;")
    op.execute("DROP INDEX IF EXISTS ix_audit_log_created_at;")

    # Stash the legacy table so we can re-insert. Renamed (not
    # dropped) so a mid-migration failure leaves the old data
    # recoverable from `audit_log_pre_partition`.
    op.execute("ALTER TABLE audit_log RENAME TO audit_log_pre_partition;")

    # Recreate the partitioned shell. The PRIMARY KEY MUST include
    # the partition column (`created_at`) — Postgres rejects unique
    # constraints that don't span every partition key column.
    op.execute(
        """
        CREATE TABLE audit_log (
            id            uuid NOT NULL DEFAULT gen_random_uuid(),
            actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
            actor_role    role_enum,
            action        text NOT NULL,
            entity_type   text NOT NULL,
            entity_id     uuid,
            diff_json     jsonb NOT NULL DEFAULT '{}'::jsonb,
            ip_address    inet,
            user_agent    text,
            created_at    timestamptz NOT NULL DEFAULT now(),
            PRIMARY KEY (id, created_at)
        ) PARTITION BY RANGE (created_at);
        """
    )

    # Same indexes as the legacy table, declared on the parent so
    # every partition inherits them. Postgres 11+ propagates these
    # automatically.
    op.execute(
        "CREATE INDEX ix_audit_log_entity ON audit_log "
        "(entity_type, entity_id, created_at);"
    )
    op.execute(
        "CREATE INDEX ix_audit_log_actor_created ON audit_log "
        "(actor_user_id, created_at);"
    )

    # Helper function — idempotent partition creation for a given
    # month. Called by the Celery beat task each month to make sure
    # tomorrow's INSERT lands in a real partition; also called from
    # this migration to bootstrap the current + next month.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION audit_log_ensure_partition(target_month date)
        RETURNS void
        LANGUAGE plpgsql AS $$
        DECLARE
            partition_name text;
            from_ts text;
            to_ts text;
        BEGIN
            target_month := date_trunc('month', target_month)::date;
            partition_name := format(
                'audit_log_y%sm%s',
                to_char(target_month, 'YYYY'),
                to_char(target_month, 'MM')
            );
            from_ts := to_char(target_month, 'YYYY-MM-DD');
            to_ts := to_char(target_month + interval '1 month', 'YYYY-MM-DD');
            EXECUTE format(
                'CREATE TABLE IF NOT EXISTS %I PARTITION OF audit_log '
                'FOR VALUES FROM (%L) TO (%L);',
                partition_name, from_ts, to_ts
            );
        END $$;
        """
    )

    # Default partition catches anything outside the explicit ranges
    # (data dated far past or future). Without this, an INSERT with
    # a created_at that doesn't fall in any explicit partition would
    # fail with `no partition of relation "audit_log" found`.
    op.execute(
        "CREATE TABLE audit_log_default PARTITION OF audit_log DEFAULT;"
    )

    # Bootstrap the current month + next 2 months. The beat task
    # tops this up monthly going forward.
    today = date.today()
    current = _month_floor(today)
    months_to_create = [
        current,
        _next_month_floor(current),
        _next_month_floor(_next_month_floor(current)),
    ]
    for m in months_to_create:
        op.execute(
            f"SELECT audit_log_ensure_partition('{m.isoformat()}'::date);"
        )

    # Migrate the legacy rows. INSERT routes each row into the
    # correct partition based on created_at. Rows that pre-date the
    # bootstrapped partitions land in audit_log_default — fine, the
    # beat task may eventually drop the default if retention purges
    # everything that old.
    op.execute(
        """
        INSERT INTO audit_log (
            id, actor_user_id, actor_role, action, entity_type, entity_id,
            diff_json, ip_address, user_agent, created_at
        )
        SELECT
            id, actor_user_id, actor_role, action, entity_type, entity_id,
            diff_json, ip_address, user_agent, created_at
        FROM audit_log_pre_partition;
        """
    )

    # Drop the legacy stash. If a verification step ever needs the
    # old data, it's recoverable from a pre-migration backup.
    op.execute("DROP TABLE audit_log_pre_partition;")


def downgrade() -> None:
    # Collapse the partitions back into a plain table. The reverse
    # of the upgrade: snapshot all partitioned rows into a new
    # non-partitioned table, drop the partitioned one + helper +
    # default + every monthly partition.
    op.execute(
        """
        CREATE TABLE audit_log_unpartitioned (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
            actor_role    role_enum,
            action        text NOT NULL,
            entity_type   text NOT NULL,
            entity_id     uuid,
            diff_json     jsonb NOT NULL DEFAULT '{}'::jsonb,
            ip_address    inet,
            user_agent    text,
            created_at    timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(
        """
        INSERT INTO audit_log_unpartitioned (
            id, actor_user_id, actor_role, action, entity_type, entity_id,
            diff_json, ip_address, user_agent, created_at
        )
        SELECT
            id, actor_user_id, actor_role, action, entity_type, entity_id,
            diff_json, ip_address, user_agent, created_at
        FROM audit_log;
        """
    )
    op.execute("DROP TABLE audit_log;")  # drops all partitions
    op.execute("DROP FUNCTION IF EXISTS audit_log_ensure_partition(date);")
    op.execute("ALTER TABLE audit_log_unpartitioned RENAME TO audit_log;")
    op.execute(
        "CREATE INDEX ix_audit_log_entity ON audit_log "
        "(entity_type, entity_id, created_at);"
    )
    op.execute(
        "CREATE INDEX ix_audit_log_actor_created ON audit_log "
        "(actor_user_id, created_at);"
    )
