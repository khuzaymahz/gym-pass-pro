"""gym logo url

Revision ID: 0006_gym_logo
Revises: 0005_user_detail_and_referrals
Create Date: 2026-04-25 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0006_gym_logo"
down_revision = "0005_user_detail_and_referrals"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("gyms", sa.Column("logo_url", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("gyms", "logo_url")
