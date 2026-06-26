---
name: create-migration
description: Create and apply a new Alembic migration for the FastAPI backend safely — autogenerate via the migrator container, validate the revision id length, and never touch past migrations. Use whenever a SQLAlchemy model/schema change needs a DB migration.
disable-model-invocation: true
---

# create-migration

Generate a new Alembic revision for `backend/` the repo's way: through the
migrator/backend container, with `uv`, and with the guardrails this project has
already been bitten by.

## Hard rules (from CLAUDE.md §12)

- **Every schema change needs a migration.** No model edit ships without one.
- **Never edit a past migration.** Forward-only. (The PreToolUse guard blocks
  edits to `backend/alembic/versions/*` for this reason.)
- **Revision id ≤ 32 chars.** `alembic_version.version_num` is `VARCHAR(32)`.
  A longer id (e.g. `0022_admin_scope_and_token_version`, 33 chars) crash-loops
  backend boot. Keep the slug short.
- **Audit-log every mutation** at the service layer — not the migration's job,
  but the change this migration backs almost certainly needs an `audit_log`
  write. Flag it if missing.

## Steps

1. **Confirm the model change is in place** under `backend/app/db/` (or wherever
   the SQLAlchemy model lives) so `--autogenerate` has something to diff.
2. **Pick a short message.** Name the slug so the full revision id stays
   ≤ 32 chars. Format is usually `NNNN_short_slug`. Count it before running.
3. **Autogenerate:**
   ```bash
   docker compose run --rm migrator alembic revision --autogenerate -m "short_slug"
   ```
   (or `cd backend && uv run alembic revision --autogenerate -m "short_slug"` if
   running outside compose).
4. **Validate the new file:**
   - Open the generated file in `backend/alembic/versions/`.
   - Assert `len(revision) <= 32` and `down_revision` points at the prior head.
   - Read the `upgrade()`/`downgrade()` — autogenerate misses server defaults,
     enum changes, and index renames. Fix by hand *in this new file*.
   ```bash
   # quick length check on the newest migration
   newest=$(ls -t backend/alembic/versions/*.py | head -1)
   grep -nE "^revision" "$newest"
   ```
5. **Apply:**
   ```bash
   docker compose run --rm migrator alembic upgrade head
   ```
6. **Verify** the backend still boots and tests pass:
   ```bash
   cd backend && uv run pytest -q
   ```

## If you renamed an existing revision id

You must also update the `down_revision` of the migration that pointed at the
old id, and `git mv` the file. This is the one case where a "past" file changes
— do it deliberately and check the chain with `uv run alembic history`.
