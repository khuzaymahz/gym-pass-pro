"""Idempotent admin-user bootstrap, safe in any APP_ENV.

Split out of `scripts/seed.py` because seed.py is dev-only (refuses to
run in staging/production), but the admin user *does* need to exist in
those environments — without this script, a fresh staging DB has no
way to log into the admin dashboard.

Two entry points:
  - `ensure_admin(session)` — async helper, reuse from within another
    transaction (e.g. `seed.py` calls it as part of its dev bootstrap).
  - `python -m scripts.bootstrap_admin` — standalone CLI; opens its
    own session. This is what the `migrator` compose service runs
    after `alembic upgrade head`.

Idempotent in both forms: if the admin already exists, the existing
row is left untouched. Reason: the operator may have rotated the
password through the admin UI, and we shouldn't reset it just because
they redeployed.
"""

from __future__ import annotations

import asyncio

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.config import get_settings
from app.core.security import hash_password
from app.db.enums import Locale, Role
from app.db.models import User
from app.db.session import get_engine
from app.utils.ids import uuid7


async def ensure_admin(session: AsyncSession) -> str | None:
    """Create the bootstrap admin if missing.

    Returns the email of the admin that was created, or `None` if the
    config skipped bootstrap or the row already existed. Caller is
    responsible for committing the session.
    """
    settings = get_settings()

    if not (settings.admin_bootstrap_email and settings.admin_bootstrap_password):
        return None

    existing = (
        await session.execute(
            select(User).where(User.email == settings.admin_bootstrap_email)
        )
    ).scalar_one_or_none()

    if existing is not None:
        return None

    session.add(
        User(
            id=uuid7(),
            email=settings.admin_bootstrap_email,
            first_name="GymPass",
            last_name="Admin",
            # Mirror the legacy `name` column so admin list views that
            # still read it stay coherent until it's retired.
            name="GymPass Admin",
            password_hash=hash_password(settings.admin_bootstrap_password),
            role=Role.ADMIN,
            locale=Locale.EN,
        )
    )
    return settings.admin_bootstrap_email


async def main() -> None:
    settings = get_settings()
    if not (settings.admin_bootstrap_email and settings.admin_bootstrap_password):
        print(
            "bootstrap_admin: ADMIN_BOOTSTRAP_EMAIL or _PASSWORD unset — "
            "skipping. Set both in your .env to enable the first-login admin."
        )
        return

    factory = async_sessionmaker(get_engine(), expire_on_commit=False)
    async with factory() as session:
        created = await ensure_admin(session)
        if created:
            await session.commit()
            print(f"bootstrap_admin: created {created!r}")
        else:
            print(
                f"bootstrap_admin: admin {settings.admin_bootstrap_email!r} "
                "already exists — leaving in place."
            )


if __name__ == "__main__":
    asyncio.run(main())
