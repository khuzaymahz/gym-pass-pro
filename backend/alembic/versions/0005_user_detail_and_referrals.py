"""user detail fields and referrals

Revision ID: 0005_user_detail_and_referrals
Revises: 0004_support_tickets
Create Date: 2026-04-23 02:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0005_user_detail_and_referrals"
down_revision = "0004_support_tickets"
branch_labels = None
depends_on = None

GENDER = ("male", "female")
REFERRAL_STATUS = ("pending", "converted", "expired")


def upgrade() -> None:
    bind = op.get_bind()

    postgresql.ENUM(*GENDER, name="gender_enum").create(bind, checkfirst=True)
    postgresql.ENUM(*REFERRAL_STATUS, name="referral_status_enum").create(
        bind, checkfirst=True
    )

    gender_enum = postgresql.ENUM(*GENDER, name="gender_enum", create_type=False)
    referral_status_enum = postgresql.ENUM(
        *REFERRAL_STATUS, name="referral_status_enum", create_type=False
    )

    op.add_column("users", sa.Column("first_name", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("last_name", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("gender", gender_enum, nullable=True))
    op.add_column("users", sa.Column("birthdate", sa.Date(), nullable=True))
    op.add_column(
        "users", sa.Column("last_active_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.add_column("users", sa.Column("referral_code", sa.Text(), nullable=True))
    op.add_column(
        "users",
        sa.Column(
            "invited_by_user_id", postgresql.UUID(as_uuid=True), nullable=True
        ),
    )

    op.create_foreign_key(
        "fk_users_invited_by_user_id_users",
        "users",
        "users",
        ["invited_by_user_id"],
        ["id"],
        ondelete="SET NULL",
    )

    # Split existing `name` into first_name / last_name (naive whitespace split).
    op.execute(
        """
        UPDATE users
        SET
          first_name = TRIM(SPLIT_PART(COALESCE(name, ''), ' ', 1)),
          last_name = NULLIF(
            TRIM(
              SUBSTRING(
                COALESCE(name, '')
                FROM POSITION(' ' IN COALESCE(name, '')) + 1
              )
            ),
            ''
          )
        WHERE name IS NOT NULL
          AND (first_name IS NULL AND last_name IS NULL)
        """
    )
    op.execute(
        """
        UPDATE users
        SET last_name = NULL
        WHERE last_name = first_name
        """
    )

    # Backfill referral_code for existing users.
    # Format: GP-XXXXXX (6-char uppercase alphanumeric, excluding ambiguous chars).
    # We derive from md5(id::text || clock_timestamp()) so we don't depend on
    # pgcrypto being enabled (gen_random_bytes lives there). Ambiguous chars
    # (O/0/I/1/L) are filtered via TRANSLATE before slicing to 6 chars.
    op.execute(
        """
        UPDATE users
        SET referral_code = 'GP-' || UPPER(
          SUBSTRING(
            TRANSLATE(md5(id::text || clock_timestamp()::text), '0oO1iIlL', '')
            FROM 1 FOR 6
          )
        )
        WHERE referral_code IS NULL
        """
    )

    op.create_index(
        "uq_users_referral_code",
        "users",
        ["referral_code"],
        unique=True,
        postgresql_where=sa.text("referral_code IS NOT NULL"),
    )
    op.create_index(
        "ix_users_invited_by_user_id", "users", ["invited_by_user_id"]
    )
    op.create_index(
        "ix_users_last_active_at", "users", ["last_active_at"]
    )

    op.create_table(
        "referrals",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "referrer_user_id", postgresql.UUID(as_uuid=True), nullable=False
        ),
        sa.Column(
            "invited_user_id", postgresql.UUID(as_uuid=True), nullable=False
        ),
        sa.Column(
            "status",
            referral_status_enum,
            nullable=False,
            server_default=sa.text("'pending'"),
        ),
        sa.Column("referral_code", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("converted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["referrer_user_id"], ["users.id"],
            name="fk_referrals_referrer_user_id_users",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["invited_user_id"], ["users.id"],
            name="fk_referrals_invited_user_id_users",
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint(
            "invited_user_id", name="uq_referrals_invited_user_id"
        ),
    )
    op.create_index(
        "ix_referrals_referrer_created",
        "referrals",
        ["referrer_user_id", "created_at"],
    )
    op.create_index("ix_referrals_status", "referrals", ["status"])


def downgrade() -> None:
    op.drop_index("ix_referrals_status", table_name="referrals")
    op.drop_index("ix_referrals_referrer_created", table_name="referrals")
    op.drop_table("referrals")

    op.drop_index("ix_users_last_active_at", table_name="users")
    op.drop_index("ix_users_invited_by_user_id", table_name="users")
    op.drop_index("uq_users_referral_code", table_name="users")

    op.drop_constraint(
        "fk_users_invited_by_user_id_users", "users", type_="foreignkey"
    )

    op.drop_column("users", "invited_by_user_id")
    op.drop_column("users", "referral_code")
    op.drop_column("users", "last_active_at")
    op.drop_column("users", "birthdate")
    op.drop_column("users", "gender")
    op.drop_column("users", "last_name")
    op.drop_column("users", "first_name")

    op.execute("DROP TYPE IF EXISTS referral_status_enum")
    op.execute("DROP TYPE IF EXISTS gender_enum")
