#!/usr/bin/env bash
#
# scripts/build-apk.sh — build release APKs pointed at the real
# api.gym-pass.net backend and drop them into the marketing site's
# public/ folder.
#
# Produces FOUR files in website/public/downloads/:
#   - gympass.apk            — arm64-v8a only (~32 MB). PRIMARY
#                              direct download served at
#                              https://gym-pass.net/downloads/gympass.apk
#                              Lightest APK that actually runs on
#                              every modern Android (Google has
#                              required 64-bit since 2019).
#   - gympass-arm32.apk      — armeabi-v7a only (~28 MB). Smallest
#                              binary; only for pre-2019 32-bit
#                              phones. Will NOT install on a
#                              modern 64-bit-only device.
#   - gympass-x64.apk        — x86_64 only (~35 MB). Android-x86,
#                              ChromeOS, BlueStacks / desktop
#                              emulators.
#   - gympass-universal.apk  — fat APK (~83 MB) with every ABI
#                              bundled. The "if-in-doubt" fallback
#                              and what we use for sideload QA on
#                              unknown devices.
#
# Why all four: most of the audience needs `gympass.apk` (arm64),
# but the universal stays available for first-time installers who
# don't know their CPU, and the per-arch variants stay available
# for the long tail (legacy 32-bit ARM, x86 emulators).
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
readonly OUTPUT_APK_ARM32="$OUTPUT_DIR/gympass-arm32.apk"
readonly OUTPUT_APK_X64="$OUTPUT_DIR/gympass-x64.apk"
readonly OUTPUT_APK_UNIVERSAL="$OUTPUT_DIR/gympass-universal.apk"

# Per-ABI builds land at predictable paths thanks to --split-per-abi.
# The non-split (universal) build writes to app-release.apk.
readonly FLUTTER_OUT_DIR="mobile/build/app/outputs/flutter-apk"
readonly FLUTTER_APK_ARM64="$FLUTTER_OUT_DIR/app-arm64-v8a-release.apk"
readonly FLUTTER_APK_ARM32="$FLUTTER_OUT_DIR/app-armeabi-v7a-release.apk"
readonly FLUTTER_APK_X64="$FLUTTER_OUT_DIR/app-x86_64-release.apk"
readonly FLUTTER_APK_UNIVERSAL="$FLUTTER_OUT_DIR/app-release.apk"

log()  { printf '\033[1;33m[apk]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[apk]\033[0m %s\n' "$*" >&2; exit 1; }

# Print size + sha256 for an already-published APK. Writes a
# sidecar `.sha256` file next to it so anyone who downloads can
# verify the bytes against `/downloads/<file>.sha256`.
summarize() {
  local dst=$1 label=$2
  local size_mb sha
  size_mb=$(du -m "$dst" | cut -f1)
  sha=$(sha256sum "$dst" | awk '{print $1}')
  log "  ${label}:"
  log "    path:   $dst"
  log "    size:   ${size_mb} MB"
  log "    sha256: $sha"
  printf '%s  %s\n' "$sha" "$(basename "$dst")" > "$dst.sha256"
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

# Pass 1: --split-per-abi produces ONE apk per ABI in a single
# build. Output paths above. This gets us all three slim variants
# (arm64-v8a, armeabi-v7a, x86_64) at once — much faster than three
# separate --target-platform passes.
log "flutter build apk --release --split-per-abi  (slim per-arch variants)…"
( cd mobile && flutter build apk --release \
    --split-per-abi \
    --dart-define-from-file="../$DEFINES_FILE" )
[[ -f "$FLUTTER_APK_ARM64" ]] || fail "split build did not produce $FLUTTER_APK_ARM64"
[[ -f "$FLUTTER_APK_ARM32" ]] || fail "split build did not produce $FLUTTER_APK_ARM32"
[[ -f "$FLUTTER_APK_X64"   ]] || fail "split build did not produce $FLUTTER_APK_X64"
cp "$FLUTTER_APK_ARM64" "$OUTPUT_APK"
cp "$FLUTTER_APK_ARM32" "$OUTPUT_APK_ARM32"
cp "$FLUTTER_APK_X64"   "$OUTPUT_APK_X64"

# Pass 2: universal fat APK — no flag = Flutter bundles every ABI.
# Used as the "I don't know which one to pick" download.
log "flutter build apk --release  (universal fat APK)…"
( cd mobile && flutter build apk --release \
    --dart-define-from-file="../$DEFINES_FILE" )
[[ -f "$FLUTTER_APK_UNIVERSAL" ]] || fail "universal build did not produce $FLUTTER_APK_UNIVERSAL"
cp "$FLUTTER_APK_UNIVERSAL" "$OUTPUT_APK_UNIVERSAL"

# ---------- Print summary -----------------------------------------
log "APKs ready:"
summarize "$OUTPUT_APK"           "primary (arm64-v8a) — direct download"
summarize "$OUTPUT_APK_ARM32"     "legacy  (armeabi-v7a) — pre-2019 32-bit"
summarize "$OUTPUT_APK_X64"       "x86_64 — emulators / ChromeOS"
summarize "$OUTPUT_APK_UNIVERSAL" "universal (all ABIs) — fallback"
log
log "Publish by deploying the website service:"
log "  /downloads/gympass.apk            ← default link (arm64)"
log "  /downloads/gympass-arm32.apk      ← legacy 32-bit ARM"
log "  /downloads/gympass-x64.apk        ← x86_64 emulators"
log "  /downloads/gympass-universal.apk  ← all-ABI fallback"
