"""gyms.audience_gender + checkin_status_enum.gender_locked

A meaningful chunk of Jordan's gym market is single-sex (women-only
studios are common; men-only barbell halls + martial-arts dojos
exist too). Modelling this as a first-class `audience_gender` field
on the gym row lets every surface — explore list, gym profile,
admin dashboard, partner profile form, and the check-in pipeline —
respect it consistently. The check-in service is the load-bearing
enforcement point: a male member who scans into a `female_only`
gym gets `CHECKIN_GENDER_LOCKED`, the failed scan is audited, and
the row never reaches the visit budget step.

Default is `mixed` — every existing gym becomes everyone-welcome
on migration, which matches the implicit pre-feature behaviour.

Revision ID: 0016_gym_audience_gender
Revises: 0015_gym_logo_alignment
Create Date: 2026-05-16 00:00:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0016_gym_audience_gender"
down_revision = "0015_gym_logo_alignment"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # New enum for the gym audience.
    op.execute(
        "CREATE TYPE audience_gender_enum AS ENUM "
        "('mixed', 'female_only', 'male_only')"
    )
    op.add_column(
        "gyms",
        sa.Column(
            "audience_gender",
            sa.Enum(
                "mixed", "female_only", "male_only",
                name="audience_gender_enum",
                create_type=False,
            ),
            nullable=False,
            server_default="mixed",
        ),
    )
    op.create_index(
        "ix_gyms_audience_gender", "gyms", ["audience_gender"]
    )

    # Extend the existing checkin status enum with the new lock reason.
    # ALTER TYPE ... ADD VALUE is the standard idiom; it must run
    # outside a transaction in pre-12 Postgres, but Postgres 16 (the
    # repo's stack) accepts it inside one, so no special handling.
    op.execute(
        "ALTER TYPE checkin_status_enum ADD VALUE IF NOT EXISTS "
        "'gender_locked'"
    )


def downgrade() -> None:
    # Drop the column and its enum. The `gender_locked` value on
    # checkin_status_enum is left in place — Postgres has no
    # ALTER TYPE DROP VALUE, and re-creating the enum just to
    # rewind one value would break any existing checkin rows that
    # already used it.
    op.drop_index("ix_gyms_audience_gender", table_name="gyms")
    op.drop_column("gyms", "audience_gender")
    op.execute("DROP TYPE IF EXISTS audience_gender_enum")
