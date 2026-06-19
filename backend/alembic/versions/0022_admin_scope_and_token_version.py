"""admin_scope sub-role + users.token_version

Two columns on `users`, both required for the role-split + session-
invalidation hardening:

1. `admin_scope` — sub-role for `role='admin'` users. Three values:
   `super` / `ops` / `viewer`. Stored as a nullable native PG enum
   so existing admin rows (which predate this column) come up NULL
   and are treated as `super` by the API layer for back-compat. New
   admins minted via `AdminUserService.create_admin` default to
   `ops` at the application level.

2. `token_version` — monotonically bumped on every credential
   rotation (password reset, force-logout, deactivate). Tokens
   carry the version they were minted with; the auth dep rejects
   mismatches. Without this, resetting an admin's password didn't
   invalidate their live JWTs — the attacker keeps acting as
   admin until the natural TTL elapses (15 min for access, 30 d
   for refresh).

Neither column is on the hot path of any existing query, so adding
them on a non-empty table costs only the DDL — no rewrite, no index
lock storm. Safe to apply online.

Revision ID: 0022_admin_scope_and_token_version
Revises: 0021_jod_money_scale_3
Create Date: 2026-06-19 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0022_admin_scope_and_token_version"
down_revision = "0021_jod_money_scale_3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Native PG enum for `admin_scope`. Mirrors the pattern every
    # other enum in the schema uses.
    op.execute(
        "CREATE TYPE admin_scope_enum AS ENUM ('super', 'ops', 'viewer')"
    )
    admin_scope_enum = sa.dialects.postgresql.ENUM(
        "super",
        "ops",
        "viewer",
        name="admin_scope_enum",
        create_type=False,
    )
    op.add_column(
        "users",
        sa.Column("admin_scope", admin_scope_enum, nullable=True),
    )
    op.add_column(
        "users",
        sa.Column(
            "token_version",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    # Grandfather the existing bootstrap admin (any row currently
    # holding role='admin') to `super` so they don't lose any
    # capability on this deploy. New admins minted after this
    # migration land at ops via the application default.
    op.execute(
        "UPDATE users SET admin_scope = 'super' "
        "WHERE role = 'admin' AND admin_scope IS NULL"
    )


def downgrade() -> None:
    op.drop_column("users", "token_version")
    op.drop_column("users", "admin_scope")
    op.execute("DROP TYPE admin_scope_enum")
