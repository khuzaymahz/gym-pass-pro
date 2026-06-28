"""merge migration heads: drop_gym_name_ar + device_tokens

Revision ID: 0027_merge_heads
Revises: 0025_drop_gym_name_ar, 0026_device_tokens
Create Date: 2026-06-28

"""
from alembic import op

revision = "0027_merge_heads"
down_revision = ("0025_drop_gym_name_ar", "0026_device_tokens")
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
