"""Unique partial index: one active day pass per (user, gym)

The application-layer guard in DayPassService.purchase() already
refuses a second active pass for the same (user, gym) via an
active_for_user_gym() query, but an advisory-lock gap or a concurrent
payment retry arriving before the first transaction commits can still
produce duplicates. This index makes the invariant unconditional at
the storage layer.

UNIQUE WHERE status = 'active' is intentional: a user may accumulate
multiple USED / EXPIRED / REFUNDED rows for the same gym (history),
and that's fine. The uniqueness constraint only applies to the *active*
slice — there can be at most one live pass per (user, gym) at any moment.

Revision ID: 0025_day_pass_one_active
Revises: 0024_fk_supporting_indexes
Create Date: 2026-06-27
"""

from alembic import op

revision = "0025_day_pass_one_active"
down_revision = "0024_fk_supporting_indexes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE UNIQUE INDEX uq_day_passes_one_active_per_user_gym
        ON day_passes (user_id, gym_id)
        WHERE status = 'active';
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_day_passes_one_active_per_user_gym;")
