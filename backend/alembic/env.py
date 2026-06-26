from __future__ import annotations

import asyncio
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context
from app.config import get_settings
from app.db import models  # noqa: F401  — registers all ORM models with Base.metadata
from app.db.base import Base

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata
settings = get_settings()
config.set_main_option("sqlalchemy.url", settings.sqlalchemy_url())


def _include_object(object_, name, type_, reflected, compare_to) -> bool:
    """Keep autogenerate from touching the monthly `audit_log` partitions.

    `audit_log` is RANGE-partitioned (migration 0018); its child tables
    (`audit_log_yYYYYmMM`) and their indexes are created at runtime by the
    partition-management function, NOT declared in the ORM metadata. Without
    this filter, every `alembic revision --autogenerate` / `alembic check`
    emits spurious `drop_table` / `remove_index` ops for them — noise that
    masks real drift. The parent `audit_log` table is in the metadata and is
    NOT filtered.
    """
    partition_table = None
    if type_ == "table":
        partition_table = name
    elif getattr(object_, "table", None) is not None:
        partition_table = object_.table.name
    # Child partitions are `audit_log_default` and `audit_log_yYYYYmMM`;
    # the parent table is exactly `audit_log` (not filtered).
    return not (partition_table and partition_table.startswith("audit_log_"))


def _compare_type(
    context_, inspected_column, metadata_column, inspected_type, metadata_type
) -> bool | None:
    """Treat unbounded ``String`` as equal to Postgres ``TEXT``.

    The models use bare ``Mapped[str]`` (i.e. ``String`` with no length),
    which Postgres stores as ``TEXT``. The default comparator flags this on
    every run as a cosmetic ``TEXT() -> String()`` "type change", which would
    make ``alembic check`` perpetually fail and useless as a CI gate.
    Returning ``False`` here means "no change"; returning ``None`` falls back
    to the default comparison so real changes (e.g. Numeric scale) still fire.
    """
    from sqlalchemy import String, Text

    inspected_is_text = isinstance(inspected_type, Text)
    metadata_is_unbounded_string = (
        isinstance(metadata_type, String)
        and not isinstance(metadata_type, Text)
        and getattr(metadata_type, "length", None) is None
    )
    if inspected_is_text and metadata_is_unbounded_string:
        return False
    return None


def _compare_server_default(
    context_,
    inspected_column,
    metadata_column,
    inspected_default,
    metadata_default,
    rendered_metadata_default,
) -> bool | None:
    """Ignore the ``audit_log.id`` default mismatch.

    ``audit_log`` is RANGE-partitioned (migration 0018). Postgres does not
    reflect a partitioned *parent* table's column defaults the way it does a
    plain table, so the ``id`` ``gen_random_uuid()`` default shows as a
    spurious ``modify_default`` on every run even though it is present and
    working. Returning ``False`` means "no change"; ``None`` elsewhere keeps
    the default comparator fully active for every other column.
    """
    if metadata_column.table.name == "audit_log" and metadata_column.name == "id":
        return False
    return None


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=_compare_type,
        compare_server_default=_compare_server_default,
        include_object=_include_object,
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=_compare_type,
        compare_server_default=_compare_server_default,
        include_object=_include_object,
    )
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
        future=True,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
