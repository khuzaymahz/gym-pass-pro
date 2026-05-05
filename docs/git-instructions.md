# Git Instructions — GymPass

> Branch model, commit rules, PR expectations, release rhythm.
> Short, enforceable, and mandatory — diverging "just this once" usually causes the biggest messes later.

---

## 1 · Branching model — GitHub Flow (with release tags)

We use **trunk-based development** with short-lived feature branches. No long-lived `develop` branch.

```
main ──────────────────●───●───●──────●──────●──────●──●──────
                        \  ↑    \     ↑       \     ↑
                         \ merge \   merge     \   merge
                          ●──●    ●──●          ●──●
                          feat/otp  fix/tier-lock   chore/deps
```

- `main` is **always deployable.** Every merge to `main` passes CI and, after Phase 4, triggers a prod deploy.
- Feature branches are short (≤ 3 days ideally; ≤ 1 week max). Longer work splits into stacked PRs.
- No "release branches" — we tag commits on `main` instead (see §7).

### Branch naming

```
<type>/<short-kebab-summary>[-<issue-id>]
```

| Type prefix | Use |
|---|---|
| `feat/` | New feature or endpoint. |
| `fix/` | Bug fix. |
| `chore/` | Tooling, deps, CI, non-feature. |
| `refactor/` | No behavior change. |
| `docs/` | Documentation only. |
| `test/` | Test-only changes. |
| `perf/` | Perf change, no behavior change. |
| `hotfix/` | Emergency production fix, branches from tag, merges to `main`. |

Examples: `feat/otp-rate-limit-42`, `fix/checkin-tier-lock-regression`, `chore/uv-bump-0.5`.

---

## 2 · Commit messages — Conventional Commits

Every commit message follows [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <imperative summary>

<optional body — what + why, never how>

<optional footer — BREAKING CHANGE:, Refs: #42, Co-Authored-By: …>
```

### Types (matching branch prefixes)

`feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `perf`, `build`, `ci`, `revert`.

### Scopes (first token)

One of: `backend`, `admin`, `mobile`, `design`, `infra`, `docs`, `meta`.
For cross-cutting changes, omit the scope.

### Examples

```
feat(backend): add CHECKIN_TIER_LOCKED validation

Blocks check-in when member tier rank is below gym required_tier.
Adds error code + httpx test covering silver→emerald path.

Refs: #87
```

```
fix(mobile): correct JOD currency placement in AR

Currency code must follow the numeric value in both locales.
Was rendering as "د.أ ٤٥" instead of "45 د.أ".
```

```
chore(infra): bump alpine base images to 3.20
```

### Rules

- **Imperative summary** (`add`, `fix`, `remove`) — not past tense.
- **≤ 72 chars** in the summary line.
- **Body wraps at 100 chars.**
- **No emoji in commit messages.** (UI emoji ban extends here.)
- **Squash merging is the default** — PR title becomes the merge commit, so the PR title must also be a conventional commit (see §4).

---

## 3 · What lives in a single commit

- One logical change per commit on a branch — but we squash on merge, so local commit granularity is your own.
- The **merged commit** on `main` (after squash) represents one reviewable unit of work.
- Never mix `feat` + unrelated `refactor` in one merged commit.

---

## 4 · Pull Requests

### Title

Same rules as commit messages — **PR title IS the squash-merge commit message**. Reviewers reject PRs with titles like "WIP" or "fixes".

### Description template

`.github/pull_request_template.md`:

```markdown
## Summary
- What changed
- Why

## Screenshots / Demo
(UI changes only — before / after GIF or still)

## Test plan
- [ ] Unit tests added/updated
- [ ] Manual: <scenario 1>
- [ ] Manual: <scenario 2>

## Checklist
- [ ] Read CLAUDE.md §12 (working rules)
- [ ] Updated [docs/](../docs/) if the contract shifted
- [ ] Migration reviewed + reversible
- [ ] No new dependency without a paragraph justifying it
- [ ] No hex literals (mobile/admin) / no raw SQL (backend) / no inline strings
- [ ] i18n for all user-facing strings
- [ ] Audit log updated for any mutation
```

### Size

- **Target ≤ 300 lines of diff.** Bigger PRs get split or pre-reviewed in design.
- **Vendored code or generated code** (e.g. OpenAPI client) is excluded from the size rule — label as `generated` and review structurally, not line-by-line.

### Reviews

- **One approval** required from a maintainer; two for schema or auth changes.
- Author never merges their own PR unless the maintainer explicitly says so.
- Review comments prefixed:
  - `nit:` — opinion, optional.
  - `q:` — question, not blocking.
  - (no prefix) — blocking; must be resolved or the reviewer must explicitly waive it.

### Merge strategy

- **Squash and merge** is the default.
- Merge commit ("create a merge commit") is only for release-tag promotions.
- Rebase-and-merge allowed when a PR's commits are already clean, intentional history (e.g. stacked refactors).

---

## 5 · CI gates (cannot merge unless green)

- `backend.yml`: `uv run ruff check`, `uv run mypy`, `uv run pytest` with coverage gate ≥ 80% on `services/`+`api/`.
- `admin.yml`: `npm run lint`, `npm run typecheck`, `npm test`, `npm run build`.
- `mobile.yml`: `flutter analyze`, `flutter test`, goldens compared.
- `openapi-drift.yml`: diff `backend/openapi.json` vs the checked-in one — any drift must be committed.
- `commitlint.yml`: enforces Conventional Commits on the PR title (and on each commit for non-squash merges).
- `secret-scan.yml`: gitleaks on every push.

A **status check** named `ci/all-green` is a meta-check that must pass; branch protection requires it on `main`.

---

## 6 · Handling migrations

- Every backend PR that touches DB has an Alembic migration **in the same commit**.
- Migrations are **reviewed extra carefully** — a reviewer must explicitly sign off `migration: ok`.
- Never edit a merged migration — always fix-forward.
- If a migration is data-heavy (> 100k rows), it runs in a separate migration flagged `data-only` and the PR description explains the rollout strategy (backfill script + online alter).

See [docs/database-schema.md — Migration discipline](database-schema.md).

---

## 7 · Releases

- **Tag format:** `vMAJOR.MINOR.PATCH` on `main`.
- **Version policy:**
  - `PATCH` — bug fixes, no API changes.
  - `MINOR` — additive API changes, new features.
  - `MAJOR` — breaking API changes (new `/api/v2` line introduced).
- Tagging creates a GitHub Release; CI promotes the tagged images to the `release` tag on the registry.
- Prod deploy watches the `release` tag.

---

## 8 · Hotfixes

- Branch from the **tag of the currently deployed version**, not `main`.
- Fix + PR to `main` first (so the fix is in trunk).
- After merge, cherry-pick the merged squash commit onto the release tag → new patch tag (`v1.2.4`).
- Deploy the patch tag to prod; merge `main` → prod on next regular cadence.

---

## 9 · Reverts

- Prefer **forward fix** when possible.
- If a revert is the right call, use `git revert <sha>` (no force-push), not `git reset`.
- The revert PR title starts with `revert:` and links the original PR in the body.

---

## 10 · Branch protection (enforced server-side)

On `main`:

- Require pull request before merging.
- Require at least 1 approving review.
- Require status checks to pass (CI gates in §5).
- Require branches to be up-to-date before merging.
- Require signed commits (GPG or SSH). **All commits must be signed.**
- Dismiss stale approvals after new commits.
- Restrict who can push: nobody — everyone goes through PRs.
- **No force-push** to `main`, ever.

---

## 11 · Local git hygiene

### Pre-commit (via [pre-commit](https://pre-commit.com/))

Installed from `.pre-commit-config.yaml`:

- `ruff format` + `ruff check --fix` (Python).
- `prettier` + `eslint --fix` (admin).
- `dart format` + `flutter analyze` (mobile — where practical locally).
- `gitleaks` scan.
- `yamllint` + `markdownlint`.
- Block commits with `TODO:` or `FIXME:` unless a linked issue number is present (`TODO(#123): …`).

### Pre-push

- Runs the relevant test suite for the changed folder.
- Blocks push if `main` is the target (branch protection also blocks server-side).

### Never

- **Never commit secrets.** `.env*` (except `.env.example`) is gitignored. If a secret leaks, rotate immediately + use `git-filter-repo` — **do not** just `git revert`.
- **Never commit** built artifacts (`dist/`, `build/`, `.next/`, `node_modules/`, `.venv/`, `target/`).
- **Never commit** editor files (`.idea/`, `.vscode/` except shared settings).

---

## 12 · Examples — good & bad

### Good

```
feat(backend): add POST /api/v1/check-ins

Implements validation ladder:
  auth → qr resolves → active sub → tier rank → visits left → rate limit
Writes audit_log in the same transaction as the mutation.

Refs: #142
```

### Bad

```
updates
```

```
[WIP] quick fix for the gym thing, will clean up later
```

```
✨ Feature: users can now do so many things (amazing!!) 🚀
```

---

## 13 · When the rules fight you

- PRs too big? Split them. If you can't split, ask: "what belongs in this PR vs a follow-up?" and reduce to the smallest shippable slice.
- Review blocked on a bike-shed? Escalate to the maintainer for a decision. Move on.
- CI flaky? Fix the flake in a separate PR first — don't re-run until green. Flakes become systemic if we let them.

---

*Next: read [architecture.md](architecture.md) to see how the code maps to the contracts these rules protect.*
