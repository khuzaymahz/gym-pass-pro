"""gym logo alignment metadata

Some partner logos are stacked marks (icon over text) where a centred
`object-cover` crop chops the bottom letters off, and some are
transparent-background marks that need `object-contain` to render
without colour bleeding into the surrounding chip. Storing the
intended fit + vertical position alongside the URL lets the partner
choose once, in the upload flow, and have every surface — sidebar
avatar, member-app gym card, profile circle — render the logo the
same way.

Schema is a JSONB column rather than two scalar columns so the field
can grow into x/y percentages or background colour later without a
schema migration. NULL is treated as the default `{fit: "cover",
position: "center"}` by every reader, so existing rows render
unchanged.

Revision ID: 0015_gym_logo_alignment
Revises: 0014_partner_indexes
Create Date: 2026-05-09 06:00:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "0015_gym_logo_alignment"
down_revision = "0014_partner_indexes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "gyms",
        sa.Column(
            "logo_alignment",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("gyms", "logo_alignment")
