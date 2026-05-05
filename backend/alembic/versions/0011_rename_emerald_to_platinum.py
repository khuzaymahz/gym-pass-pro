"""rename tier_enum: emerald -> platinum

Revives the original "platinum" name for the third tier. Migration 0003
went the other direction (platinum -> emerald) when the project briefly
adopted the gemstone naming; product has since moved back to the
metals-and-stones progression (silver, gold, platinum, diamond).

PostgreSQL supports `ALTER TYPE ... RENAME VALUE` since v10, so the
rename is in-place — no row updates needed; existing subscriptions /
plans / gyms keep their identity.

Revision ID: 0011_rename_emerald_to_platinum
Revises: 0010_indexes_and_constraints
Create Date: 2026-05-05 00:00:00.000000
"""

from __future__ import annotations

from alembic import op

revision = "0011_rename_emerald_to_platinum"
down_revision = "0010_indexes_and_constraints"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
          IF EXISTS (
            SELECT 1 FROM pg_enum e
            JOIN pg_type t ON t.oid = e.enumtypid
            WHERE t.typname = 'tier_enum' AND e.enumlabel = 'emerald'
          ) AND NOT EXISTS (
            SELECT 1 FROM pg_enum e
            JOIN pg_type t ON t.oid = e.enumtypid
            WHERE t.typname = 'tier_enum' AND e.enumlabel = 'platinum'
          ) THEN
            ALTER TYPE tier_enum RENAME VALUE 'emerald' TO 'platinum';
          END IF;
        END$$;
        """
    )


def downgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
          IF EXISTS (
            SELECT 1 FROM pg_enum e
            JOIN pg_type t ON t.oid = e.enumtypid
            WHERE t.typname = 'tier_enum' AND e.enumlabel = 'platinum'
          ) AND NOT EXISTS (
            SELECT 1 FROM pg_enum e
            JOIN pg_type t ON t.oid = e.enumtypid
            WHERE t.typname = 'tier_enum' AND e.enumlabel = 'emerald'
          ) THEN
            ALTER TYPE tier_enum RENAME VALUE 'platinum' TO 'emerald';
          END IF;
        END$$;
        """
    )
