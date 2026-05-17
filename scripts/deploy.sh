#!/usr/bin/env bash
#
# scripts/deploy.sh — staging deployment runner.
#
# Runs on the staging VM. Assumes:
#   - You're sitting in the project root (`/opt/gympass` typically).
#   - Docker + Compose v2 are installed and your user is in `docker`.
#   - `.env.staging` exists and is filled in (copy from .env.staging.example).
#   - `nginx/certs/gym-pass.net.pem` and `gym-pass.net.key` exist
#     (the Cloudflare Origin Cert covers *.gym-pass.net + apex, so
#     the same cert serves the stg-* hostnames).
#   - The repo is already cloned (this script doesn't pull — leave that
#     to the operator so a half-clone never gets deployed by accident).
#
# What it does, in order:
#   1. Sanity checks (env file, cert files, expected free disk).
#   2. Pulls the latest images for the third-party services (postgres,
#      redis, nginx) so they're current.
#   3. Builds the four app images (backend, admin, gym-partner, website).
#   4. Brings the stack up.
#   5. Runs alembic upgrade head against the live DB.
#   6. Smoke-tests every public endpoint via scripts/smoke.sh.
#
# Idempotent — re-running picks up any new commit on the deploy branch
# and rolls forward. Failures abort early; partial state survives.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

readonly COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.staging.yml --env-file .env.staging)
readonly REQUIRED_FILES=(
  ".env.staging"
  "nginx/certs/gym-pass.net.pem"
  "nginx/certs/gym-pass.net.key"
)
readonly SMOKE_API_BASE="https://stg-api.gym-pass.net"

log()  { printf '\033[1;33m[deploy]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[deploy]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- 1. Sanity checks ----------------------------------------
log "Sanity checks…"
for f in "${REQUIRED_FILES[@]}"; do
  [[ -f "$f" ]] || fail "missing required file: $f"
done

# Cert file should be a PEM CERTIFICATE; key should NOT be world-readable.
head -n 1 nginx/certs/gym-pass.net.pem | grep -q "BEGIN CERTIFICATE" \
  || fail "nginx/certs/gym-pass.net.pem doesn't look like a PEM cert"
key_mode=$(stat -c '%a' nginx/certs/gym-pass.net.key)
if [[ "$key_mode" != "600" && "$key_mode" != "400" ]]; then
  log "WARN: gym-pass.net.key permission is $key_mode (expected 600). Fixing."
  chmod 600 nginx/certs/gym-pass.net.key
fi

# 5 GB free is a soft floor for an image build + DB volume headroom.
free_kb=$(df --output=avail -k . | tail -1)
if (( free_kb < 5_000_000 )); then
  fail "less than 5GB free disk available on the deploy root. Aborting before fill-up."
fi

# Confirm we can talk to Docker.
docker info >/dev/null 2>&1 || fail "docker daemon unreachable. Is the user in the docker group?"

# ---------- 2. Pull third-party images ------------------------------
log "Pulling third-party images (postgres, redis, nginx)…"
"${COMPOSE[@]}" pull db redis nginx

# ---------- 3. Build app images ------------------------------------
log "Building app images (backend, admin, gym-partner, website)…"
"${COMPOSE[@]}" build --pull backend admin gym-partner website

# ---------- 4. Bring the stack up -----------------------------------
# Down-then-up rather than up-d-rebuild: cleaner restart semantics, and
# we *want* a brief outage on deploy (it's pre-prod). Production-grade
# would be a rolling restart or blue/green; out of scope here.
log "Restarting the stack…"
"${COMPOSE[@]}" down --remove-orphans
"${COMPOSE[@]}" up -d

# ---------- 5. Migrations ------------------------------------------
# Backend's entrypoint already runs `alembic upgrade head`, but doing
# it explicitly via `exec` is faster on re-deploys (no full backend
# restart needed for migration-only changes) and surfaces failures
# immediately on the deployer's terminal.
log "Running alembic upgrade head…"
"${COMPOSE[@]}" exec -T backend uv run alembic upgrade head

# ---------- 6. Smoke tests ------------------------------------------
log "Waiting for nginx + backends to be healthy…"
sleep 6

# Delegate to scripts/smoke.sh so the same probe runs from CI, the
# Makefile (`make smoke-staging`), and the local dev box. Anything
# non-zero exit is a deploy failure.
if ! bash "$ROOT/scripts/smoke.sh" "$SMOKE_API_BASE"; then
  fail "smoke checks failed. Check 'docker compose logs --tail=200'."
fi

log "Deploy OK."
