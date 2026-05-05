"""gym photos

Revision ID: 0002_gym_photos
Revises: 0001_init
Create Date: 2026-04-21 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0002_gym_photos"
down_revision = "0001_init"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "gym_photos",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("gym_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("url", sa.Text(), nullable=False),
        sa.Column(
            "sort_order", sa.Integer(), nullable=False, server_default=sa.text("0")
        ),
        sa.Column("alt_text_en", sa.Text(), nullable=True),
        sa.Column("alt_text_ar", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["gym_id"],
            ["gyms.id"],
            name="fk_gym_photos_gym_id_gyms",
            ondelete="CASCADE",
        ),
    )
    op.create_index(
        "ix_gym_photos_gym_sort", "gym_photos", ["gym_id", "sort_order"]
    )


def downgrade() -> None:
    op.drop_index("ix_gym_photos_gym_sort", table_name="gym_photos")
    op.drop_table("gym_photos")
