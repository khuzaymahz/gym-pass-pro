#!/usr/bin/env bash
# PostToolUse hook — format the just-edited file by extension, mirroring CI.
#
# Fast formatters only (no analyze / no `dart fix` — those spin up an analysis
# server and would stall every edit). CI still runs the full lint/analyze gate;
# this just keeps local edits clean so CI rarely rejects on formatting.
#
# Reads the Claude Code hook JSON from stdin and pulls tool_input.file_path.
set -uo pipefail

f="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"
[ -z "$f" ] && exit 0
[ -f "$f" ] || exit 0

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

case "$f" in
  "$root"/mobile/*.dart)
    ( cd "$root/mobile" && dart format "$f" ) >/dev/null 2>&1 || true
    ;;
  "$root"/backend/*.py)
    # Keep formatting + import-sorting autofixes, but make two rules
    # UNFIXABLE because their "cleanups" silently break runtime behaviour
    # under `from __future__ import annotations`:
    #   F401 — deletes an import added a beat before its use lands,
    #          breaking Pydantic forward-refs / FastAPI DI.
    #   UP037 — unquotes `Annotated["Redis", Depends(...)]` where the type
    #          is a TYPE_CHECKING-only import; FastAPI can then no longer
    #          resolve it and demotes the dependency to a 422'ing query
    #          param. Both have bitten us; disabled here.
    ( cd "$root/backend" \
        && uv run ruff format "$f" \
        && uv run ruff check --fix --unfixable F401,UP037 "$f" ) >/dev/null 2>&1 || true
    ;;
  "$root"/admin/*.ts|"$root"/admin/*.tsx|\
  "$root"/gym-partner/*.ts|"$root"/gym-partner/*.tsx|\
  "$root"/website/*.ts|"$root"/website/*.tsx)
    app="${f#"$root"/}"; app="${app%%/*}"
    ( cd "$root/$app" && npx --no-install prettier --write "$f" && npx --no-install eslint --fix "$f" ) >/dev/null 2>&1 || true
    ;;
esac

exit 0
