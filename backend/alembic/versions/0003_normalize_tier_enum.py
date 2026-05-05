"""normalize tier_enum: platinum -> emerald

Some dev databases were initialized from an earlier 0001_init revision that
named the third tier 'platinum'. The canonical name is 'emerald'. Rename in
place so existing rows (plans, gyms, subscriptions) keep their data.

Revision ID: 0003_normalize_tier_enum
Revises: 0002_gym_photos
Create Date: 2026-04-23 00:00:00.000000
"""

from __future__ import annotations

from alembic import op

revision = "0003_normalize_tier_enum"
down_revision = "0002_gym_photos"
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


def downgrade() -> None:
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
