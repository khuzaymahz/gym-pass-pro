"""drop Arabic gym name columns

Gyms are now English-name-only: the member app, admin, and partner portal
all display `name_en` regardless of locale, so the parallel Arabic name
carried no value and drifted from the English one. This drops both:

  - `gyms.name_ar`
  - `partner_applications.gym_name_ar`

Forward-only data loss is intentional (the columns are no longer read
anywhere). The downgrade re-creates the columns NOT NULL via a transient
empty-string default so existing rows satisfy the constraint; the original
data cannot be recovered.

Revision ID: 0025_drop_gym_name_ar
Revises: 0024_fk_supporting_indexes
Create Date: 2026-06-27 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0025_drop_gym_name_ar"
down_revision = "0024_fk_supporting_indexes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_column("gyms", "name_ar")
    op.drop_column("partner_applications", "gym_name_ar")


def downgrade() -> None:
    # Re-add NOT NULL with a transient default so pre-existing rows are
    # valid, then drop the default to match the original (no-default) shape.
    op.add_column(
        "gyms",
        sa.Column("name_ar", sa.Text(), nullable=False, server_default=""),
    )
    op.alter_column("gyms", "name_ar", server_default=None)
    op.add_column(
        "partner_applications",
        sa.Column("gym_name_ar", sa.Text(), nullable=False, server_default=""),
    )
    op.alter_column("partner_applications", "gym_name_ar", server_default=None)
