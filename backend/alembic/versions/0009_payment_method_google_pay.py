"""add google_pay to payment_method_enum

Adds the `google_pay` value to the existing `payment_method_enum`
Postgres type so the mobile app's Android wallet path can be persisted.
The mobile sheet now offers Apple Pay only on iOS and Google Pay only
on Android — keeping each platform's native wallet without forcing the
other onto a member who can't open it.

`ALTER TYPE … ADD VALUE` runs outside a transaction (Postgres
restriction), so the migration disables the autocommit wrapper for
this single op.

Revision ID: 0009_payment_method_google_pay
Revises: 0008_subscription_pauses
Create Date: 2026-05-01 00:00:00.000000
"""

from __future__ import annotations

from alembic import op

revision = "0009_payment_method_google_pay"
down_revision = "0008_subscription_pauses"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # `ALTER TYPE … ADD VALUE` cannot run inside a transaction in
    # Postgres < 12 with the default Alembic config, and even on 12+
    # it's safer to commit before the ADD VALUE so a later op in the
    # same transaction doesn't rollback the enum change.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE payment_method_enum ADD VALUE IF NOT EXISTS 'google_pay'"
        )


def downgrade() -> None:
    # Postgres has no native `ALTER TYPE … DROP VALUE`. To remove the
    # value we'd have to:
    #   1. Repoint every column using the enum to a new type that
    #      omits the value.
    #   2. Drop the old type, rename the new one back.
    # That's destructive and risks losing rows that already use
    # `google_pay`. Leave the value in place on downgrade — additive
    # enum migrations don't need to be reversed for safety.
    pass
