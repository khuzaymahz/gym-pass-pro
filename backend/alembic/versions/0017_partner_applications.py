"""partner_applications: gym-onboarding request queue

Adds a `partner_applications` table to back the public "Join Us"
flow on the partner portal. Gym owners submit a form with all the
fields needed to spin up a real gym + a partner user, plus their
chosen password (bcrypt-hashed at submit time so it can be copied
verbatim into `users.password_hash` on approval).

A pending row creates NO `gyms` or `users` records — the gym is
invisible to members until an admin clicks Approve. On approval
the row's data becomes a `Gym` + a `gym_owner` `User`, both
referenced back via FK so the audit trail is preserved.

Status:
  pending  — submitted, awaiting admin review
  approved — admin clicked approve; gym + user rows created
  rejected — admin clicked reject; row retained for audit

Revision ID: 0017_partner_applications
Revises: 0016_gym_audience_gender
Create Date: 2026-05-16 02:00:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "0017_partner_applications"
down_revision = "0016_gym_audience_gender"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create the new enum BEFORE the table, then reference it from
    # the column with `create_type=False`. `sa.Enum(create_type=False)`
    # would normally suppress alembic's auto-create, but in practice
    # alembic re-emits CREATE TYPE for ANY new SAEnum it sees inside
    # an op.create_table call regardless of the flag — observed
    # behaviour, not documented. The two-step pattern (explicit
    # CREATE TYPE + postgresql.ENUM with create_type=False) is the
    # reliable workaround.
    status_enum = postgresql.ENUM(
        "pending", "approved", "rejected",
        name="application_status_enum",
        create_type=True,
    )
    status_enum.create(op.get_bind(), checkfirst=True)

    category_enum_existing = postgresql.ENUM(
        "gym", "crossfit", "martial", "yoga",
        name="category_enum",
        create_type=False,
    )
    audience_enum_existing = postgresql.ENUM(
        "mixed", "female_only", "male_only",
        name="audience_gender_enum",
        create_type=False,
    )

    op.create_table(
        "partner_applications",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "status",
            postgresql.ENUM(
                name="application_status_enum",
                create_type=False,
            ),
            nullable=False,
            server_default="pending",
        ),
        # Owner-side fields — what becomes the gym_owner User row on approval.
        sa.Column("owner_name", sa.Text(), nullable=False),
        sa.Column("owner_phone", sa.Text(), nullable=False),
        sa.Column("owner_email", sa.Text(), nullable=True),
        sa.Column("password_hash", sa.Text(), nullable=False),
        # Gym-side fields — what becomes the Gym row on approval.
        sa.Column("gym_name_en", sa.Text(), nullable=False),
        sa.Column("gym_name_ar", sa.Text(), nullable=False),
        sa.Column("gym_area", sa.Text(), nullable=False),
        sa.Column("gym_address_en", sa.Text(), nullable=False),
        sa.Column("gym_address_ar", sa.Text(), nullable=False),
        sa.Column("gym_lat", sa.Numeric(9, 6), nullable=False),
        sa.Column("gym_lng", sa.Numeric(9, 6), nullable=False),
        sa.Column("gym_category", category_enum_existing, nullable=False),
        sa.Column(
            "gym_audience_gender",
            audience_enum_existing,
            nullable=False,
            server_default="mixed",
        ),
        sa.Column("gym_phone", sa.Text(), nullable=True),
        sa.Column(
            "amenities",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        sa.Column(
            "opening_hours",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        # Media — URLs (relative to media_url_prefix) of files already
        # uploaded via the public /partner-applications/upload endpoint
        # before the form is submitted.
        sa.Column("logo_url", sa.Text(), nullable=True),
        sa.Column(
            "photo_urls",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        # Admin review trail.
        sa.Column("admin_notes", sa.Text(), nullable=True),
        sa.Column(
            "reviewed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "reviewed_by_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        # Backrefs to the created entities on approval.
        sa.Column(
            "approved_gym_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("gyms.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "approved_owner_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "submitted_from_ip",
            sa.Text(),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_index(
        "ix_partner_applications_status",
        "partner_applications",
        ["status"],
    )
    # Uniqueness on owner_phone is intentionally NOT enforced — a
    # rejected applicant might re-apply with the same phone. The
    # business rule "one user per phone" is enforced at approval
    # time (the service checks for an existing user before creating).


def downgrade() -> None:
    op.drop_index("ix_partner_applications_status", table_name="partner_applications")
    op.drop_table("partner_applications")
    op.execute("DROP TYPE IF EXISTS application_status_enum")
