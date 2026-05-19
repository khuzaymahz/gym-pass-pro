# Operations runbook

Day-2 operator reference for the GymPass VM stack. Everything in
this doc presumes you're SSH'd into the VM at the project root
(`/opt/gympass` by convention). For local dev, use `make dev-up`
instead and ignore this file.

For the **self-hosted mail server** (Mailu — admin UI, webmail, SMTP,
IMAP), see [`docs/mail.md`](mail.md). It's an opt-in compose overlay
with its own bring-up, DNS, and troubleshooting requirements.

---

## Resource budget (single-VM staging)

The staging stack runs on one Contabo VPS (11 GiB RAM, 6 vCPU, NVMe
SSD). `docker-compose.staging.yml` pins explicit memory limits +
reservations on every long-lived service so a runaway worker can't
OOM the database, and so the kernel has predictable headroom for the
page cache and SSH:

| Service        | Limit  | Reservation | Notes                                       |
|----------------|--------|-------------|---------------------------------------------|
| `db`           | 2.5 G  | 512 M       | Postgres `shared_buffers=2G` + WAL/work_mem |
| `redis`        | 256 M  | 64 M        | `maxmemory=256mb`, `allkeys-lru`            |
| `backend`      | 1 G    | 256 M       | 2 uvicorn workers × ~250 M + headroom       |
| `celery-worker`| 768 M  | 128 M       | `--concurrency=4`, 4 procs × ~150 M         |
| `celery-beat`  | 128 M  | 32 M        | Single scheduler proc                       |
| `admin`        | 512 M  | 128 M       | Next.js production runner                   |
| `gym-partner`  | 512 M  | 128 M       | Next.js production runner                   |
| `website`      | 384 M  | 64 M        | Next.js, mostly static                      |
| `migrator`     | 512 M  | —           | One-shot; exits, no reservation             |
| `nginx`        | 128 M  | 32 M        | Small even under load                       |

Sum of limits ≈ 7.5 GiB, leaving ~3.5 GiB of host headroom for kernel
+ page cache + sshd + burst absorption. Combined with the 4 GiB swap
file (set up in the host-bootstrap bundle, see deploy.md), the kernel
has roughly 7.5 GiB of slack before the OOM killer touches anything.

If the **mail overlay** is loaded (`docker-compose.mail.yml`), add
~1.5 GiB on top (its own resource caps are pinned in that file's
header).

### Postgres tuning rationale

`docker-compose.staging.yml` overrides the stock Postgres config:

```
shared_buffers=2GB                 # ~25% of host RAM, the documented sweet spot
effective_cache_size=6GB           # planner hint for kernel+PG cache combined
work_mem=16MB                      # per-query × per-sort: 50 conn × 1 sort = 800 MB ceiling
maintenance_work_mem=256MB         # speeds VACUUM / CREATE INDEX
max_connections=50                 # we have ~6 services × ~5 conns avg = headroom
random_page_cost=1.1               # NVMe SSD; default 4.0 assumes HDD seeks
effective_io_concurrency=200       # NVMe parallel I/O
wal_buffers=16MB
checkpoint_completion_target=0.9   # spread checkpoint I/O to avoid spikes
```

The defaults are sized for a Raspberry Pi (`shared_buffers=128MB`,
`random_page_cost=4.0`). On a real VM they leave Postgres re-fetching
from the kernel page cache constantly and biased toward sequential
scans even when an index would be cheaper. Don't revert these unless
you're moving to a managed DB (where the provider sets its own).

### Per-service log rotation

Every long-lived service in the staging overlay has its own
`logging:` block (`max-size: 10m`, `max-file: 3–5`). This is
belt-and-braces with the host's `/etc/docker/daemon.json` — if the
daemon defaults ever get reset, individual containers still rotate
on their own and a runaway log can't fill the disk.

---

## Bring-up: idempotent `migrator` one-shot

The staging compose includes a one-shot `migrator` service that runs
on every `up -d` and exits as soon as it's done:

```bash
# What it runs (from docker-compose.staging.yml):
uv run alembic upgrade head
uv run python -m scripts.bootstrap_admin
```

Both steps are idempotent — safe to re-run on every deploy. `backend`,
`celery-worker`, and `celery-beat` all depend on it with
`service_completed_successfully` so they never start against a
half-migrated schema.

### Why a separate service vs running inline in backend's command

- The **dev compose** bakes `alembic upgrade head && python -m
  scripts.seed && exec uvicorn` into the backend's command. The
  **staging overlay** replaces that with bare gunicorn (4 workers).
  Without `migrator`, all 4 gunicorn workers would race to run
  migrations at startup — one wins, three error.
- A single "schema is ready" gate lets backend / celery-worker /
  celery-beat all wait on the same condition instead of each
  replicating migration logic.
- Migration failure produces a clean signal (the `migrator` service
  exits non-zero, `docker compose up` reports the failure plainly)
  instead of being buried in worker startup logs.

### `bootstrap_admin.py`

[`backend/scripts/bootstrap_admin.py`](../backend/scripts/bootstrap_admin.py)
is the canonical admin-user bootstrap. Two entry points:

- `python -m scripts.bootstrap_admin` — what the `migrator` service
  runs. Opens its own DB session, commits if it created a row, exits.
- `ensure_admin(session)` — async helper called from `scripts.seed`
  in dev so the dev seed and the staging migrator follow the exact
  same code path.

**Idempotent and non-destructive**: if `ADMIN_BOOTSTRAP_EMAIL` already
exists, the row is left alone — the operator may have rotated the
password through the admin UI, and a redeploy shouldn't reset it.

`ADMIN_BOOTSTRAP_EMAIL` / `ADMIN_BOOTSTRAP_PASSWORD` in `.env.staging`
control the bootstrap. Unset both to skip (script prints a message
and exits cleanly).

### Re-running the migrator manually

If you want to force migrations to run without bringing the whole
stack down:

```bash
docker compose -f docker-compose.yml -f docker-compose.staging.yml \
  --env-file .env.staging \
  up --no-deps --force-recreate migrator
```

The mail overlay has its own `mail-init` one-shot service that runs
the equivalent for Mailu (admin bootstrap + DKIM key generation).
See [docs/mail.md §4](mail.md).

---

## Adminer (DB browser) — opt-in, loopback-only

Adminer used to start by default on every `docker compose up -d` and
publish `0.0.0.0:8080` — meaning the staging VM exposed an
internet-reachable DB browser whenever the dev compose was applied
(which the staging overlay does extend). That's now closed:

- `docker-compose.yml` puts adminer behind the **`dev-tools`
  profile** — `docker compose up -d` no longer touches it.
- The port binding is **`127.0.0.1:8080:8080`** — loopback only —
  so even if you start it manually on the VM, it isn't reachable
  from the public IP.

To use it locally:

```bash
# Local dev only — explicit opt-in.
docker compose --profile dev-tools up -d adminer
# Open http://localhost:8080 — login: db / POSTGRES_USER / POSTGRES_PASSWORD / POSTGRES_DB
```

For DB access on the staging VM, prefer `psql` through the container:

```bash
docker compose -f docker-compose.yml -f docker-compose.staging.yml \
  --env-file .env.staging exec db psql -U gympass
```

Or SSH-tunnel adminer for an ad-hoc GUI session, e.g.
`ssh -L 8080:localhost:8080 vm`, then start adminer on the VM with
the `--profile dev-tools` flag.

---

## Reverse proxy: mail vhost always rendered

`nginx/nginx.conf` includes `mail.conf` unconditionally, even when
the mail overlay isn't loaded. This is intentional:
[`nginx/templates/mail.conf.template`](../nginx/templates/mail.conf.template)
uses a `resolver 127.0.0.11 valid=10s` + variable `set $mail_upstream
"mail-front:443"` + `proxy_pass https://$mail_upstream` pattern.

The variable form defers DNS resolution from nginx-start time to
request time. So:

- **Mail overlay running**: hits to `mail.<domain>` resolve and proxy
  to `mail-front:443` identically to a hardcoded `upstream` block.
- **Mail overlay not loaded**: `mail-front` doesn't exist in Docker
  DNS. nginx still boots cleanly (it doesn't try to resolve at
  start). A request to `mail.<domain>` returns HTTP 502 instead of
  taking the proxy down.

If you change `nginx/conf.d/mail.conf` to use a static `upstream`
block, the staging stack will fail to start any time the mail overlay
isn't part of the compose invocation.

The `MAIL_DOMAIN` env var is included in `NGINX_ENVSUBST_FILTER` and
defaults to `mail.gym-pass.net` — so the template renders cleanly
regardless of whether `.env.mail` is loaded.

---

## DB backups

### Setup (one-time per host)

```bash
# Create the backup directory writable by the operator user.
sudo mkdir -p /backups
sudo chown "$USER":"$USER" /backups
chmod 750 /backups

# Test the script runs cleanly. Writes one fresh archive into
# /backups/ and prints its size + sha256.
bash scripts/db-backup.sh

# Install the nightly cron entry. Edit your user's crontab:
crontab -e
```

Add the line:

```cron
0 2 * * * cd /opt/gympass && bash scripts/db-backup.sh >> /var/log/gympass-backup.log 2>&1
```

`02:00` is conservative for Jordan time (UTC+3) — well past the
typical traffic floor and well before the morning admin shift.

### Off-host upload (optional)

Set `BACKUP_BUCKET` to any `aws s3 cp` / `rclone copy`-compatible
URI in `.env.staging` (or `.env.prod`) and the script pushes
each fresh archive there. Local copies still age out per
`BACKUP_RETENTION_DAYS` (default 7); the bucket's own lifecycle
policy handles its retention.

```bash
BACKUP_BUCKET=s3://gympass-backups-prd/db/
```

### Restore drill (do this once after setup)

Validates that the dumps are actually restorable. Cheap to run on
a throwaway Postgres container; do it in staging the same week
you set the cron up.

```bash
# 1. Pull the latest backup from /backups/.
ls -t /backups/gympass-*.sql.gz | head -1

# 2. Start a throwaway Postgres on a different port + name so it
#    can't accidentally clobber the live one.
docker run --rm -d --name gympass-restore-test \
  -e POSTGRES_PASSWORD=resttest \
  -e POSTGRES_DB=gympass_restore \
  -e POSTGRES_USER=gympass \
  -p 5433:5432 \
  postgres:16-alpine

# 3. Replay the dump.
gunzip < /backups/gympass-LATEST.sql.gz \
  | docker exec -i gympass-restore-test pg_restore \
      -U gympass -d gympass_restore --clean --if-exists

# 4. Verify row counts roughly match production.
docker exec gympass-restore-test psql -U gympass -d gympass_restore \
  -c "SELECT 'users', count(*) FROM users
      UNION ALL SELECT 'gyms', count(*) FROM gyms
      UNION ALL SELECT 'checkins', count(*) FROM checkins
      UNION ALL SELECT 'subscriptions', count(*) FROM subscriptions;"

# 5. Tear it down.
docker stop gympass-restore-test
```

If row counts on the throwaway match the live DB (within today's
delta), the backup chain is verified end-to-end. Re-drill at
least quarterly — a backup you've never restored isn't a backup.

---

## Sentry — turning error tracking on

The SDK is already wired in every surface (backend / admin /
partner / mobile). All four init paths are no-ops until you set
the DSN env var. Order of operations to flip it on:

1. **Create a Sentry project** per environment. Conventional
   names: `gympass-backend-stg`, `gympass-admin-stg`,
   `gympass-partner-stg`, `gympass-mobile-stg` (and the matching
   `-prd` set for production).

2. **Capture each project's DSN** (Settings → Client Keys → DSN).
   You'll get four URLs of the shape
   `https://<hash>@<org>.ingest.sentry.io/<project-id>`.

3. **Per surface — staging VM**:

   ```bash
   # In .env.staging on the VM:
   SENTRY_DSN=<backend-dsn>
   SENTRY_TRACES_SAMPLE_RATE=0.1
   APP_RELEASE=gympass-backend@0.1.0-stg

   # In docker-compose.staging.yml the admin + partner services
   # also receive SENTRY_DSN via env_file:
   # (already wired in their environment maps)
   ```

   Then restart: `make staging-down && make staging-up`.

4. **Mobile** — DSN is a build-time `--dart-define`. Edit
   `mobile/dart_defines.prod.json`:

   ```json
   {
     "SENTRY_DSN": "https://<mobile-dsn>",
     "APP_RELEASE": "gympass-mobile@0.1.0",
     "APP_ENV": "production"
   }
   ```

   Rebuild the APK: `bash scripts/build-apk.sh`. The new APK ships
   with the DSN compiled in.

5. **Verify** — fire a synthetic error and confirm it lands in
   each Sentry project. For the backend:

   ```bash
   docker compose exec backend uv run python -c \
     "import sentry_sdk; sentry_sdk.capture_message('synthetic-staging-test')"
   ```

   For the Next surfaces, add a temporary `throw new Error(...)`
   in an unused page, hit it, and verify the event appears in the
   right project's Issues feed.

6. **Tune sample rates** if needed. The defaults are
   `traces_sample_rate=0.0` in dev, `0.1` staging, `0.05`
   production. Bump staging to `1.0` for the first week to catch
   slow-trace investigations, then revert.

---

## audit_log partition maintenance

### Migration 0018 — idempotent under retry

Migration `0018_audit_log_partitioned` converts `audit_log` from a
plain table into a Postgres-partitioned table. If a previous run died
partway through (e.g. transaction killed by an OOM, deploy reboot),
the legacy table will already be renamed to `audit_log_pre_partition`
— BUT Postgres preserves index names through `ALTER TABLE RENAME`, so
`ix_audit_log_entity` / `ix_audit_log_actor_created` /
`ix_audit_log_created_at` still occupy those names on the renamed
table.

On re-run, the migration's `CREATE INDEX` statements for the new
partitioned table would collide (`relation "ix_audit_log_*" already
exists`) and the whole migration would roll back into the same
half-state. The migration now pre-drops those three indexes
(`DROP INDEX IF EXISTS`) so it's safe to retry. **Don't remove those
guard statements** — they're the difference between a failed deploy
that you can simply re-run and a failed deploy that needs manual
psql intervention.

### Maintenance task

The `audit_log_maintenance` Celery beat task runs daily at
~03:00 local. Two halves:

  1. **Ensure** — creates next month's partition before any
     INSERT could need it.
  2. **Prune** — drops partitions older than
     `AUDIT_LOG_RETENTION_MONTHS` (default 12).

To inspect the current partition shape:

```bash
docker compose exec db psql -U gympass -d gympass \
  -c "SELECT c.relname,
             pg_size_pretty(pg_relation_size(c.oid)) AS size
      FROM pg_inherits i
      JOIN pg_class c ON c.oid = i.inhrelid
      JOIN pg_class p ON p.oid = i.inhparent
      WHERE p.relname = 'audit_log'
      ORDER BY c.relname;"
```

To force the maintenance task to run now (e.g. before a deploy
where you want to verify the next partition exists):

```bash
docker compose exec celery-worker celery -A app.workers.celery_app \
  call app.workers.tasks.scheduled.audit_log_maintenance
```

Tightening retention (e.g. for storage pressure):

```bash
# In .env.prod
AUDIT_LOG_RETENTION_MONTHS=6
```

Then restart the worker so the new env value is picked up:

```bash
docker compose restart celery-worker celery-beat
```

---

## Pre-commit hook (local — install once per clone)

```bash
make pre-commit-install
```

Symlinks `.git/hooks/pre-commit` to `scripts/pre-commit`. Catches:

- Python syntax errors in `backend/` (`python -m py_compile`)
- TypeScript errors in `admin/` / `gym-partner/` / `website/`
  (`tsc --noEmit`, scoped to the surface with staged files)
- Dart errors in `mobile/` (`flutter analyze`)

Lint warnings don't block. Set `GYMPASS_PRECOMMIT_STRICT=1` to
treat warnings as errors too.

---

## Local-CI parity

```bash
make ci            # everything
make ci-backend    # pytest only
make ci-mobile     # flutter analyze + flutter test
make ci-admin      # tsc + next build
make ci-partner
make ci-website
```

Mirrors the `.github/workflows/ci.yml` job matrix exactly, so a
PR that passes `make ci` locally will pass on the cloud runner.

---

## Release-on-tag

Pushing a tag matching `v*` triggers `.github/workflows/release.yml`:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow:

1. Builds the dual APKs (arm64 slim + universal fat) with
   `APP_ENV=production` baked in.
2. Reads `MOBILE_SENTRY_DSN` (GitHub Actions repo secret) and
   bakes it into the APK if set.
3. Creates a GitHub Release with auto-generated changelog.
4. Attaches both APKs + their `.sha256` manifest files as
   downloadable assets.

The marketing site is updated separately — when you want a new
APK to live at `/downloads/gympass.apk`, deploy the website
service after building (the build script already drops the APKs
into `website/public/downloads/`).
