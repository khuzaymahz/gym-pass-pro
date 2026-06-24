#!/usr/bin/env bash
# PreToolUse hook — protect sensitive / lockstep files from accidental edits.
#
# Exit 2 => block the edit and surface the message to Claude.
# Exit 0 with a NOTE on stderr => allow, but leave an advisory in the transcript.
#
# Grounded in the project knowledge graph:
#   - .env/lock files: never machine-edited.
#   - committed Alembic migrations: CLAUDE.md rule "never edit past migrations"
#     (and a >32-char revision id has already broken backend boot once).
#   - mobile l10n triplet: the three LARGEST node-clusters in the whole graph
#     (Mobile i18n Base/EN/AR) move in lockstep; the ARB is stale so a plain
#     `flutter gen-l10n` deletes getters. Steer edits through /l10n-sync.
set -uo pipefail

f="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"
[ -z "$f" ] && exit 0
base="$(basename "$f")"

# --- Hard blocks -----------------------------------------------------------
case "$base" in
  .env|.env.*|*.env)
    echo "BLOCKED: $base is an environment/secrets file. Edit it manually outside Claude." >&2
    exit 2 ;;
esac

case "$base" in
  uv.lock|package-lock.json|pnpm-lock.yaml|yarn.lock|pubspec.lock)
    echo "BLOCKED: $base is a lock file — regenerate it via its package manager, don't hand-edit." >&2
    exit 2 ;;
esac

case "$f" in
  */backend/alembic/versions/*.py)
    echo "BLOCKED: $base is a committed Alembic migration. Never edit past migrations — create a new one with /create-migration. If you genuinely must amend it, do so manually." >&2
    exit 2 ;;
esac

# --- Advisory (allowed) ----------------------------------------------------
case "$f" in
  */mobile/lib/l10n/app_localizations*.dart|*/mobile/lib/l10n/app_*.arb)
    echo "NOTE: l10n files move in lockstep (base + EN + AR + ARB). Prefer /l10n-sync so the triplet stays even, and do NOT run 'flutter gen-l10n' — the ARB is stale and it will delete generated getters." >&2 ;;
esac

exit 0
