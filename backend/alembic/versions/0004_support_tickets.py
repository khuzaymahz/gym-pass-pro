"""support tickets

Revision ID: 0004_support_tickets
Revises: 0003_normalize_tier_enum
Create Date: 2026-04-23 00:30:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0004_support_tickets"
down_revision = "0003_normalize_tier_enum"
branch_labels = None
depends_on = None

CATEGORY = ("bug", "complaint", "feature", "account", "payment", "gym_issue", "other")
PRIORITY = ("low", "normal", "high", "urgent")
STATUS = ("open", "in_progress", "waiting_user", "resolved", "closed")


def upgrade() -> None:
    bind = op.get_bind()

    postgresql.ENUM(*CATEGORY, name="ticket_category_enum").create(bind, checkfirst=True)
    postgresql.ENUM(*PRIORITY, name="ticket_priority_enum").create(bind, checkfirst=True)
    postgresql.ENUM(*STATUS, name="ticket_status_enum").create(bind, checkfirst=True)

    category_enum = postgresql.ENUM(*CATEGORY, name="ticket_category_enum", create_type=False)
    priority_enum = postgresql.ENUM(*PRIORITY, name="ticket_priority_enum", create_type=False)
    status_enum = postgresql.ENUM(*STATUS, name="ticket_status_enum", create_type=False)

    op.create_table(
        "support_tickets",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "category", category_enum, nullable=False, server_default=sa.text("'other'")
        ),
        sa.Column(
            "priority", priority_enum, nullable=False, server_default=sa.text("'normal'")
        ),
        sa.Column(
            "status", status_enum, nullable=False, server_default=sa.text("'open'")
        ),
        sa.Column("subject", sa.Text(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column(
            "assigned_admin_id", postgresql.UUID(as_uuid=True), nullable=True
        ),
        sa.Column(
            "meta",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
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
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"],
            name="fk_support_tickets_user_id_users",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["assigned_admin_id"], ["users.id"],
            name="fk_support_tickets_assigned_admin_id_users",
            ondelete="SET NULL",
        ),
    )
    op.create_index(
        "ix_support_tickets_status_created",
        "support_tickets",
        ["status", "created_at"],
    )
    op.create_index("ix_support_tickets_user_id", "support_tickets", ["user_id"])
    op.create_index(
        "ix_support_tickets_assigned", "support_tickets", ["assigned_admin_id"]
    )

    op.create_table(
        "support_ticket_messages",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("ticket_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("author_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column(
            "is_internal_note",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["ticket_id"], ["support_tickets.id"],
            name="fk_support_ticket_messages_ticket_id",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["author_user_id"], ["users.id"],
            name="fk_support_ticket_messages_author_id",
            ondelete="CASCADE",
        ),
    )
    op.create_index(
        "ix_support_ticket_messages_ticket",
        "support_ticket_messages",
        ["ticket_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_support_ticket_messages_ticket", table_name="support_ticket_messages"
    )
    op.drop_table("support_ticket_messages")
    op.drop_index("ix_support_tickets_assigned", table_name="support_tickets")
    op.drop_index("ix_support_tickets_user_id", table_name="support_tickets")
    op.drop_index("ix_support_tickets_status_created", table_name="support_tickets")
    op.drop_table("support_tickets")
    op.execute("DROP TYPE IF EXISTS ticket_status_enum")
    op.execute("DROP TYPE IF EXISTS ticket_priority_enum")
    op.execute("DROP TYPE IF EXISTS ticket_category_enum")
