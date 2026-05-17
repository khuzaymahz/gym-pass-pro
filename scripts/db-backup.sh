#!/usr/bin/env bash
#
# scripts/db-backup.sh — nightly Postgres logical backup.
#
# Runs on the host that owns the `db` docker compose service.
# Streams `pg_dump --format=custom` out of the container, gzips
# it, drops the archive in `${BACKUP_DIR}/`, and prunes anything
# older than `${BACKUP_RETENTION_DAYS}` (default 7 local copies).
#
# Optional off-host upload: if `${BACKUP_BUCKET}` is set (any s3-
# compatible URI accepted by `aws s3 cp` / `rclone copy`), the
# fresh archive is also pushed there. The local copy stays so a
# disaster that takes out networking still leaves an on-disk
# snapshot to restore from.
#
# Cron entry (drop into the VM operator's crontab — `crontab -e`):
#
#   0 2 * * * cd /opt/gympass && bash scripts/db-backup.sh >> /var/log/gympass-backup.log 2>&1
#
# Restore (smoke-test once after the first successful run):
#
#   gunzip < /backups/gympass-2026-05-17.sql.gz \
#     | docker compose exec -T db pg_restore -U gympass -d gympass --clean --if-exists
#
# Format-custom (`-Fc`) is used (not plain SQL) because it streams
# faster, compresses better, and supports `--clean --if-exists`
# selective restore. The `.sql.gz` extension is kept for
# operator readability — the bytes themselves are pg_dump's
# binary custom format.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

readonly BACKUP_DIR="${BACKUP_DIR:-/backups}"
readonly BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
readonly DB_USER="${POSTGRES_USER:-gympass}"
readonly DB_NAME="${POSTGRES_DB:-gympass}"
readonly DB_SERVICE="${DB_SERVICE:-db}"
readonly TS="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
readonly OUT="${BACKUP_DIR}/${DB_NAME}-${TS}.sql.gz"

log()  { printf '\033[1;33m[db-backup]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[db-backup]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- Sanity --------------------------------------------------
command -v docker >/dev/null 2>&1 || fail "docker not on PATH"
[[ -d "$BACKUP_DIR" ]] || mkdir -p "$BACKUP_DIR" \
  || fail "could not create $BACKUP_DIR (run as root or pre-create + chmod)"

# Refuse to run if the db container isn't healthy — corrupt mid-write
# dumps are worse than a missed nightly slot.
status=$(docker compose ps --format json "$DB_SERVICE" 2>/dev/null \
  | python -c "import sys,json; rows=[json.loads(l) for l in sys.stdin if l.strip()]; print(rows[0].get('Health','none') if rows else 'absent')" 2>/dev/null || echo "absent")
if [[ "$status" != "healthy" && "$status" != "none" ]]; then
  fail "db service not healthy (status=$status). Refusing backup."
fi

# ---------- Dump ----------------------------------------------------
log "Dumping $DB_NAME → $OUT"
if ! docker compose exec -T "$DB_SERVICE" pg_dump \
       -U "$DB_USER" -d "$DB_NAME" \
       --format=custom --compress=6 --no-owner --no-acl \
     | gzip --rsyncable > "$OUT"; then
  rm -f "$OUT"
  fail "pg_dump pipeline failed"
fi

# Smoke: any archive smaller than 1 KB is almost certainly an error
# response from pg_dump that got gzipped.
size=$(stat -c %s "$OUT" 2>/dev/null || stat -f %z "$OUT" 2>/dev/null || echo 0)
if (( size < 1024 )); then
  rm -f "$OUT"
  fail "backup file suspiciously small ($size bytes) — refusing to keep."
fi
log "  size: $(( size / 1024 )) KB"

# ---------- Off-host (optional) ------------------------------------
if [[ -n "${BACKUP_BUCKET:-}" ]]; then
  if command -v aws >/dev/null 2>&1; then
    log "  uploading via aws s3 cp → $BACKUP_BUCKET/"
    aws s3 cp "$OUT" "$BACKUP_BUCKET/" --only-show-errors || \
      log "  WARN: s3 upload failed; local copy retained"
  elif command -v rclone >/dev/null 2>&1; then
    log "  uploading via rclone copy → $BACKUP_BUCKET/"
    rclone copy "$OUT" "$BACKUP_BUCKET/" || \
      log "  WARN: rclone upload failed; local copy retained"
  else
    log "  WARN: BACKUP_BUCKET set but neither aws nor rclone on PATH"
  fi
fi

# ---------- Prune --------------------------------------------------
# Keep only the most recent N days locally. Off-host bucket keeps
# its own retention (lifecycle policies handle that side).
log "Pruning local backups older than ${BACKUP_RETENTION_DAYS} days"
find "$BACKUP_DIR" -maxdepth 1 -name "${DB_NAME}-*.sql.gz" -type f \
  -mtime "+${BACKUP_RETENTION_DAYS}" -print -delete | \
  sed 's/^/  removed: /'

log "Done."
