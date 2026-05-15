#!/usr/bin/env bash
#
# scripts/build-apk.sh — build a release APK pointed at the real
# api.gym-pass.net backend and drop it into the marketing site's
# public/ folder so https://gym-pass.net/downloads/gympass.apk
# serves it.
#
# Runs anywhere Flutter is installed (laptop or VM). Doesn't depend
# on docker. Produces a single artefact and prints its SHA-256 so
# you can verify the file you downloaded matches what was built.
#
# Pre-reqs:
#   - flutter on PATH (3.38+ tested)
#   - Android SDK + cmdline-tools (Flutter prompts on first build)
#   - `mobile/dart_defines.prod.json` exists (cp from .example)
#   - Optional: a release keystore at `mobile/android/key.properties`
#     for signing. Without it the APK is debug-signed — fine for
#     side-loaded pre-prod testing, NOT for the Play Store.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

readonly DEFINES_FILE="mobile/dart_defines.prod.json"
readonly OUTPUT_DIR="website/public/downloads"
readonly OUTPUT_APK="$OUTPUT_DIR/gympass.apk"

log()  { printf '\033[1;33m[apk]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[apk]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- Sanity --------------------------------------------------
command -v flutter >/dev/null 2>&1 || fail "flutter not on PATH"
[[ -f "$DEFINES_FILE" ]] \
  || fail "missing $DEFINES_FILE. Copy from $DEFINES_FILE.example and fill in."

# Quick guard: catch the placeholder so we don't ship an APK pointed
# at a bogus URL.
grep -q "API_BASE_URL" "$DEFINES_FILE" || fail "$DEFINES_FILE has no API_BASE_URL"

# ---------- Build --------------------------------------------------
log "flutter pub get…"
( cd mobile && flutter pub get )

# We build a single fat APK (--release, all ABIs in one file) so the
# marketing site can serve it from one URL. For Play-Store distribution
# later we'd switch to --split-per-abi or an AAB — both shrink the
# download but break the "one file on the website" UX.
log "flutter build apk --release --dart-define-from-file=$DEFINES_FILE…"
( cd mobile && flutter build apk --release \
    --dart-define-from-file="../$DEFINES_FILE" )

readonly BUILT_APK="mobile/build/app/outputs/flutter-apk/app-release.apk"
[[ -f "$BUILT_APK" ]] || fail "flutter build did not produce $BUILT_APK"

# ---------- Stage to website public/ ------------------------------
mkdir -p "$OUTPUT_DIR"
cp "$BUILT_APK" "$OUTPUT_APK"

size_mb=$(du -m "$OUTPUT_APK" | cut -f1)
sha=$(sha256sum "$OUTPUT_APK" | awk '{print $1}')

log "APK ready:"
log "  path:   $OUTPUT_APK"
log "  size:   ${size_mb} MB"
log "  sha256: $sha"
log
log "Publish by deploying the website service (the file is served as"
log "  /downloads/gympass.apk by the Next.js public/ directory)."

# Write the sha alongside so /downloads/gympass.apk.sha256 is also
# served — anyone who downloads the APK can verify the bytes.
echo "$sha  gympass.apk" > "$OUTPUT_APK.sha256"
