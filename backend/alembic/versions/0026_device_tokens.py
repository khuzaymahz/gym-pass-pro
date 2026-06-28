"""device_tokens table for FCM / APNs push delivery

Revision ID: 0026_device_tokens
Revises: 0025_day_pass_one_active
Create Date: 2026-06-28
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0026_device_tokens"
down_revision = "0025_day_pass_one_active"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE TYPE device_platform_enum AS ENUM ('android', 'ios')"
    )
    op.create_table(
        "device_tokens",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("token", sa.Text(), nullable=False),
        sa.Column(
            "platform",
            postgresql.ENUM(
                "android", "ios", name="device_platform_enum", create_type=False
            ),
            nullable=False,
            server_default="android",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_device_tokens_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_device_tokens"),
        sa.UniqueConstraint("token", name="uq_device_tokens_token"),
    )
    op.create_index(
        "ix_device_tokens_user_id", "device_tokens", ["user_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_device_tokens_user_id", table_name="device_tokens")
    op.drop_table("device_tokens")
    op.execute("DROP TYPE device_platform_enum")
