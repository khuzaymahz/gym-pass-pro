# Operations runbook

Day-2 operator reference for the GymPass VM stack. Everything in
this doc presumes you're SSH'd into the VM at the project root
(`/opt/gympass` by convention). For local dev, use `make dev-up`
instead and ignore this file.

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
