#!/usr/bin/env bash
#
# scripts/build-apk.sh — build release APKs pointed at the real
# api.gym-pass.net backend and drop them into the marketing site's
# public/ folder.
#
# Produces TWO files:
#   - gympass.apk           — arm64-v8a only (~28 MB). Primary
#                             download served at
#                             https://gym-pass.net/downloads/gympass.apk
#                             Covers every Android 64-bit device,
#                             which is effectively every phone made
#                             since ~2018.
#   - gympass-universal.apk — fat APK (~74 MB) with all three ABIs
#                             (armeabi-v7a + arm64-v8a + x86_64).
#                             Fallback for the rare pre-2018 32-bit
#                             phone where the arm64 build won't
#                             install.
#
# Why two: 64-bit phones are the realistic GymPass audience in
# Jordan, and three-quarters of the fat APK's bytes are native libs
# they never run. Forcing a 74 MB download on every member to cover
# the long tail of armeabi-v7a-only devices is bandwidth waste in
# a country where most plans are still metered.
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
readonly OUTPUT_APK_UNIVERSAL="$OUTPUT_DIR/gympass-universal.apk"
# Both `flutter build apk` invocations write to the same path.
# Copy out between builds before the second one overwrites.
readonly FLUTTER_APK_OUT="mobile/build/app/outputs/flutter-apk/app-release.apk"

log()  { printf '\033[1;33m[apk]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[apk]\033[0m %s\n' "$*" >&2; exit 1; }

# Print size + sha256 for an already-published APK. Splits the
# sidecar `.sha256` file next to it so anyone who downloads can
# verify the bytes against `/downloads/gympass.apk.sha256`.
summarize() {
  local dst=$1 label=$2
  local size_mb sha
  size_mb=$(du -m "$dst" | cut -f1)
  sha=$(sha256sum "$dst" | awk '{print $1}')
  log "  ${label}:"
  log "    path:   $dst"
  log "    size:   ${size_mb} MB"
  log "    sha256: $sha"
  echo "$sha  $(basename "$dst")" > "$dst.sha256"
}

# ---------- Sanity --------------------------------------------------
command -v flutter >/dev/null 2>&1 || fail "flutter not on PATH"
[[ -f "$DEFINES_FILE" ]] \
  || fail "missing $DEFINES_FILE. Copy from $DEFINES_FILE.example and fill in."

grep -q "API_BASE_URL" "$DEFINES_FILE" || fail "$DEFINES_FILE has no API_BASE_URL"

mkdir -p "$OUTPUT_DIR"

# ---------- Build --------------------------------------------------
log "flutter pub get…"
( cd mobile && flutter pub get )

# Pass 1: arm64-v8a only — the primary download. `--target-platform`
# strips the other two ABIs at build time, so the resulting APK is
# ~28 MB instead of ~74 MB. Refuses to install on a 32-bit-only
# Android (would silently fail to launch otherwise) which is the
# correct behaviour — those users follow the universal fallback URL.
log "flutter build apk --release --target-platform android-arm64  (primary, slim)…"
( cd mobile && flutter build apk --release \
    --target-platform android-arm64 \
    --dart-define-from-file="../$DEFINES_FILE" )
[[ -f "$FLUTTER_APK_OUT" ]] || fail "arm64 build did not produce $FLUTTER_APK_OUT"
# Copy out NOW before the second build overwrites this path.
cp "$FLUTTER_APK_OUT" "$OUTPUT_APK"

# Pass 2: fat APK covering every architecture — the fallback download
# for the rare pre-2018 device that doesn't speak arm64. Same code,
# no `--target-platform` flag = Flutter's default which bundles every
# ABI it supports for Android.
log "flutter build apk --release  (fallback, universal fat APK)…"
( cd mobile && flutter build apk --release \
    --dart-define-from-file="../$DEFINES_FILE" )
[[ -f "$FLUTTER_APK_OUT" ]] || fail "universal build did not produce $FLUTTER_APK_OUT"
cp "$FLUTTER_APK_OUT" "$OUTPUT_APK_UNIVERSAL"

# ---------- Print summary -----------------------------------------
log "APKs ready:"
summarize "$OUTPUT_APK" "primary (arm64-v8a)"
summarize "$OUTPUT_APK_UNIVERSAL" "universal (all ABIs)"
log
log "Publish by deploying the website service (files served as"
log "  /downloads/gympass.apk            ← default link"
log "  /downloads/gympass-universal.apk  ← fallback for pre-2018 devices)."
