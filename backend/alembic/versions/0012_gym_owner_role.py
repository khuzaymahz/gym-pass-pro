"""Add 'gym_owner' value to role_enum.

Postgres forbids referencing a newly-added enum value in the same
transaction that added it ("unsafe use of new value" / asyncpg
`UnsafeNewEnumValueUsageError`). The follow-up migration 0013 needs
to reference `'gym_owner'` in a partial unique index, so the value
must land — and commit — before that migration runs. Alembic
commits between migration files, which is exactly the boundary we
need; this migration is therefore intentionally tiny.

`autocommit_block` keeps the `ALTER TYPE` outside the migration's
transaction. Even though `ALTER TYPE ... ADD VALUE` itself is legal
inside a transaction, autocommitting it side-steps a separate
PostgreSQL restriction (some PG versions disallow `ALTER TYPE` in a
multi-statement transaction block) and matches the documented
Alembic pattern for enum additions.

Revision identifiers are kept short (≤ 32 chars) so they fit
`alembic_version.version_num`, which is `varchar(32)` by default —
longer ids overflow the bookkeeping UPDATE that runs after the
migration body, leaving a half-applied state in the DB.

Revision ID: 0012_gym_owner_role
Revises: 0011_rename_emerald_to_platinum
Create Date: 2026-05-08 00:00:00.000000
"""

from __future__ import annotations

from alembic import op

revision = "0012_gym_owner_role"
down_revision = "0011_rename_emerald_to_platinum"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE role_enum ADD VALUE IF NOT EXISTS 'gym_owner'"
        )


def downgrade() -> None:
    # PostgreSQL has no `ALTER TYPE DROP VALUE`. The 'gym_owner' label
    # stays orphaned in the enum on downgrade; harmless because no
    # rows reference it after migration 0013 is reverted.
    pass
