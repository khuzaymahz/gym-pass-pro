"""users.gym_id (1:1 partner ↔ gym) + partner indexes.

Split out from 0012 because the partial unique index references
`role = 'gym_owner'` — and Postgres won't let you use a freshly-added
enum value in the same transaction that added it. By the time this
migration runs, 0012 has already committed the enum value, so the
WHERE clause is safe.

Adds:
  - `users.gym_id` (nullable UUID FK → gyms.id, ON DELETE SET NULL)
  - `uq_users_gym_owner_gym_id` partial unique on (gym_id) WHERE
    role='gym_owner' AND gym_id IS NOT NULL AND deleted_at IS NULL,
    enforcing the product invariant: at most one active gym-owner
    login per gym.
  - `ix_users_gym_id` non-unique index for the partner-portal
    `WHERE gym_id = :id` lookup path.

Revision IDs ≤ 32 chars to fit `alembic_version.version_num`.

Revision ID: 0013_users_gym_id
Revises: 0012_gym_owner_role
Create Date: 2026-05-08 00:00:01.000000
"""

from __future__ import annotations

from alembic import op

revision = "0013_users_gym_id"
down_revision = "0012_gym_owner_role"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS gym_id uuid
        REFERENCES gyms(id) ON DELETE SET NULL
        """
    )
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_users_gym_owner_gym_id
        ON users (gym_id)
        WHERE role = 'gym_owner'
          AND gym_id IS NOT NULL
          AND deleted_at IS NULL
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_users_gym_id
        ON users (gym_id)
        WHERE gym_id IS NOT NULL
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_users_gym_id")
    op.execute("DROP INDEX IF EXISTS uq_users_gym_owner_gym_id")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS gym_id")
