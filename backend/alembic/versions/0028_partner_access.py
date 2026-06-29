"""partner_access — many-to-many partner↔gym for multi-branch chains

Replaces the implicit 1:1 `users.gym_id` (kept as a legacy "primary gym"
pointer) with an explicit membership table, so one partner login can own
or operate multiple branches. Back-fills an `owner` row for every existing
active gym_owner, so current single-gym partners are unchanged.

Revision ID: 0028_partner_access
Revises: 0027_merge_heads
Create Date: 2026-06-29 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0028_partner_access"
down_revision = "0027_merge_heads"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE TYPE partner_access_role_enum AS ENUM ('owner', 'manager')")
    op.create_table(
        "partner_access",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("gym_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "role",
            postgresql.ENUM(
                "owner", "manager", name="partner_access_role_enum", create_type=False
            ),
            nullable=False,
            server_default="owner",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name="fk_partner_access_user_id_users", ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["gym_id"], ["gyms.id"], name="fk_partner_access_gym_id_gyms", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_partner_access"),
        sa.UniqueConstraint("user_id", "gym_id", name="uq_partner_access_user_gym"),
    )
    op.create_index("ix_partner_access_user", "partner_access", ["user_id"])
    op.create_index("ix_partner_access_gym", "partner_access", ["gym_id"])
    # Back-fill: every active gym_owner with a linked gym becomes an owner of it.
    op.execute(
        """
        INSERT INTO partner_access (id, user_id, gym_id, role, created_at)
        SELECT gen_random_uuid(), id, gym_id, 'owner', now()
        FROM users
        WHERE role = 'gym_owner' AND gym_id IS NOT NULL AND deleted_at IS NULL
        """
    )


def downgrade() -> None:
    op.drop_index("ix_partner_access_gym", table_name="partner_access")
    op.drop_index("ix_partner_access_user", table_name="partner_access")
    op.drop_table("partner_access")
    op.execute("DROP TYPE partner_access_role_enum")
