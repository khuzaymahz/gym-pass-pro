#!/usr/bin/env bash
#
# scripts/smoke.sh — verify a GymPass stack is reachable end-to-end.
#
# Usage:
#   scripts/smoke.sh                                 # defaults to local dev
#   scripts/smoke.sh http://localhost:8000           # local dev backend
#   scripts/smoke.sh https://stg-api.gym-pass.net    # staging
#   scripts/smoke.sh https://api.gym-pass.net        # production
#
# Hits /health on the backend root, plus the four hostnames if a
# `*.gym-pass.net` API base is passed (those imply nginx is fronting
# the stack and the marketing / admin / partner subdomains exist).
# Anything 2xx/3xx is OK; 4xx/5xx is a failure.
#
# Replaces the inline smoke loop in scripts/deploy.sh so the same
# check is callable from local dev, CI, the Makefile, and the
# deploy script.

set -euo pipefail

API_BASE="${1:-http://localhost:8000}"

log()  { printf '\033[1;33m[smoke]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[smoke]\033[0m %s\n' "$*" >&2; exit 1; }

# Always probe /health on the backend root.
TARGETS=("$API_BASE/health")

# When pointed at a public hostname (anything resolving to
# *.gym-pass.net) also probe the other three surfaces. The hostname
# pattern is the operator's signal that nginx is in front; for
# `localhost:8000` we don't have a marketing / admin / partner to
# hit on the same origin.
if [[ "$API_BASE" =~ stg-api\.gym-pass\.net ]]; then
  TARGETS+=(
    "https://stg.gym-pass.net"
    "https://stg-admin.gym-pass.net"
    "https://stg-partner.gym-pass.net"
  )
elif [[ "$API_BASE" =~ ^https://api\.gym-pass\.net ]]; then
  TARGETS+=(
    "https://gym-pass.net"
    "https://admin.gym-pass.net"
    "https://partner.gym-pass.net"
  )
fi

failed=0
for url in "${TARGETS[@]}"; do
  # `-k` tolerates self-signed (in case Cloudflare's proxy is
  # disabled mid-deploy and we're hitting the origin cert directly).
  # `-L` follows the apex→canonical redirects nginx sets up.
  # `--max-time 10` keeps a hung backend from stalling the script.
  status=$(curl -s -k -o /dev/null -w "%{http_code}" -L --max-time 10 "$url" || echo "000")
  if [[ "$status" =~ ^[23] ]]; then
    log "  $url  ✓  ($status)"
  else
    printf '\033[1;31m[smoke]\033[0m   %s  ✗  (%s)\n' "$url" "$status" >&2
    failed=1
  fi
done

if (( failed )); then
  fail "one or more smoke checks failed."
fi

log "Smoke OK."
