# Tasks — GymPass Implementation Plan

> Phased build plan. Each phase has a clear exit criterion. Tasks inside a phase can be parallelized where dependencies allow; the header dependencies block the next phase.
> Every task lists its **acceptance** — the check that says "done."

Legend: `[M]` mobile · `[B]` backend · `[A]` admin · `[I]` infra/devx · `[D]` docs/design · `[T]` tests

---

## Phase 0 — Foundations (repo + prototype alive)

**Goal:** prototype runs locally, monorepo structure is in place, docs are alive.
**Exit:** `npm run dev` at repo root boots the Claude Design member-app prototype; every surface folder exists as a stub; CLAUDE.md + docs/ are in place and cross-linked.

| # | Task | Acceptance |
|---|---|---|
| 0.1 `[I]` | Initialize git repo; commit baseline (this plan + CLAUDE.md + design/). | `git log` shows initial commit. |
| 0.2 `[D]` | Import Claude Design bundle into [design/](../design/). | Folder present with README, project/, chats/. |
| 0.3 `[I]` | Create [index.html](../index.html), [vite.config.js](../vite.config.js), [src/main.jsx](../src/main.jsx) that mount the existing prototype JSX. | `npm run dev` opens the 16-screen prototype without console errors. |
| 0.4 `[I]` | Add `.gitignore`, `.editorconfig`, `.nvmrc`. | Lint-clean baseline. |
| 0.5 `[I]` | Create empty `backend/`, `admin/`, `mobile/`, `nginx/`, `scripts/` folders with README stubs pointing at [architecture.md](architecture.md). | Folders exist with a READMEs explaining "not yet implemented." |
| 0.6 `[D]` | Finalize all docs: architecture, tasks, schema, api-standards, git-instructions. | All five files linked from CLAUDE.md §16 and cross-link each other. |
| 0.7 `[I]` | Set up GitHub Actions skeleton: lint + typecheck jobs per package (noop when the package is empty). | First push runs CI green. |

---

## Phase 1 — Backend MVP

**Goal:** a FastAPI backend that can authenticate a member, list gyms and plans, accept a check-in, and expose OpenAPI.
**Exit:** `docker compose up backend db redis` + running `curl` against the main member endpoints returns real data.

### 1.1 Bootstrap

| # | Task | Acceptance |
|---|---|---|
| 1.1.1 `[B][I]` | `uv init` in `backend/`; pin Python 3.12; add FastAPI, SQLAlchemy 2 async, asyncpg, Pydantic v2, alembic, structlog, passlib[argon2], python-jose. | `uv lock` resolves; `uv run python -c "import fastapi"` ok. |
| 1.1.2 `[B][I]` | `Dockerfile` + entrypoint (uvicorn in dev, gunicorn+uvicorn workers in prod). | `docker build ./backend` succeeds. |
| 1.1.3 `[I]` | `docker-compose.yml` with `db`, `redis`, `migrator`, `backend`. | `docker compose up -d` starts all four. |
| 1.1.4 `[B]` | `config.py` Pydantic Settings reads `.env`. | Invalid env → app fails to boot with a readable error. |
| 1.1.5 `[B]` | `core/logging.py` structlog JSON + request-id middleware. | Logs include `request_id` and `APP_ENV`. |

### 1.2 Schema + migrations

| # | Task | Acceptance |
|---|---|---|
| 1.2.1 `[B]` | SQLAlchemy models for every table in [database-schema.md](database-schema.md). | Import-linter passes; `mypy` green. |
| 1.2.2 `[B]` | Alembic init; autogenerate first migration `0001_init`. | `alembic upgrade head` applies cleanly on empty DB. |
| 1.2.3 `[B]` | `scripts/seed.py` — 6 gyms, 4 plans, 2 test members. | `docker compose run --rm backend python scripts/seed.py` fills the DB. |

### 1.3 Auth

| # | Task | Acceptance |
|---|---|---|
| 1.3.1 `[B]` | `providers/sms/base.py` Protocol + `providers/sms/mock.py` (logs OTP). | Dev OTP always `1234`; verified by a unit test. |
| 1.3.2 `[B]` | `services/auth_service.py` — `request_otp`, `verify_otp`, `sign_in_google`, `refresh`. Hashes OTP; stores in Redis 5m TTL. | Unit tests cover success + each failure branch with the right error codes. |
| 1.3.3 `[B]` | `core/security.py` — JWT encode/verify; argon2 password hashing. | Tokens round-trip; tampered tokens reject. |
| 1.3.4 `[B]` | `api/v1/auth.py` — `/otp/request`, `/otp/verify`, `/google`, `/refresh`. | httpx-driven API tests green for all branches. |
| 1.3.5 `[B]` | `api/deps.py` — `get_current_user`, `get_current_admin`. | 401 on missing/invalid JWT; 403 on role mismatch. |

### 1.4 Core resources

| # | Task | Acceptance |
|---|---|---|
| 1.4.1 `[B]` | `api/v1/gyms.py` — list (filters: category, tier, area), get-by-id. Cursor pagination. | Returns seeded gyms; filter tests pass. |
| 1.4.2 `[B]` | `api/v1/plans.py` — list plans. | Returns 4 tier plans. |
| 1.4.3 `[B]` | `api/v1/subscriptions.py` — purchase flow stub (calls mock payment). | Creates `subscriptions` + `payments` rows; audit entries written. |
| 1.4.4 `[B]` | `providers/payments/base.py` + `providers/payments/mock.py` (1.5s delay, random txn_id). | Unit test verifies delay and success payload. |
| 1.4.5 `[B]` | `api/v1/checkins.py` — POST with full validation ladder ([architecture.md §6](architecture.md)). | Each error branch returns the exact error code from [api-standards.md](api-standards.md). |
| 1.4.6 `[B]` | `api/v1/notifications.py` — list + mark-read. | Returns seeded notifications scoped to the user. |
| 1.4.7 `[B]` | `services/audit_service.py` — `write(actor, action, entity, diff)` used by every mutation service. | Every 1.4.x mutation inserts an audit row. |

### 1.5 Admin endpoints (thin slice)

| # | Task | Acceptance |
|---|---|---|
| 1.5.1 `[B]` | `POST /api/v1/admin/session-token` — accepts NextAuth cookie proxy, returns short-lived service JWT. | E2E test with a seeded admin account passes. |
| 1.5.2 `[B]` | Admin CRUD for gyms (`/api/v1/admin/gyms`). | Create/read/update/archive round-trip; rotate-QR issues new UUID. |
| 1.5.3 `[B]` | Admin read endpoints for plans, members, subscriptions, checkins, payouts, audit. | Returns the right data with cursor pagination. |

### 1.6 Workers (lean)

| # | Task | Acceptance |
|---|---|---|
| 1.6.1 `[B]` | Celery app; dev uses `task_always_eager=True`. | `celery inspect ping` works in prod mode. |
| 1.6.2 `[B]` | `tasks/sms.py` — takes phone + code; in mock it logs. | Invoked from auth service in both sync and async modes. |
| 1.6.3 `[B]` | `tasks/payouts.py` — monthly aggregate per gym. | Unit test: 30 checkins → one payout row, correct sum. |

### 1.7 Tests + CI

| # | Task | Acceptance |
|---|---|---|
| 1.7.1 `[T]` | `conftest.py` — isolated Postgres schema per test run; transactional rollback fixtures. | `uv run pytest -q` green on a clean checkout. |
| 1.7.2 `[T]` | Coverage gate ≥ 80% on `services/` + `api/`. | CI fails below the threshold. |
| 1.7.3 `[I]` | GitHub Action `backend.yml` — install uv, run pytest, upload coverage. | PR status shows green check. |

**Phase 1 exits when** a member can, end-to-end against the deployed backend: request OTP → verify → see plans → purchase (mock) → list gyms → check in → see audit trail.

---

## Phase 2 — Member App (Flutter) MVP

**Goal:** ship a Flutter app that implements every screen in the 16-screen prototype, wired to Phase 1 backend, AR-default.
**Exit:** `flutter run` on iOS simulator and Android emulator shows a fully functional app matching goldens for all 16 screens.

### 2.1 Bootstrap

| # | Task | Acceptance |
|---|---|---|
| 2.1.1 `[M]` | `flutter create mobile` (org: `net.gympass`); pin Flutter 3.24+. | `flutter doctor` clean. |
| 2.1.2 `[M]` | Add deps: `flutter_bloc`, `get_it`, `injectable`, `dio`, `go_router`, `flutter_secure_storage`, `google_sign_in`, `mobile_scanner` (QR), `flutter_localizations`, `intl`, `cached_network_image`. | `pubspec.lock` committed. |
| 2.1.3 `[M]` | `core/theme/` — port tokens from [design/project/colors_and_type.css](../design/project/colors_and_type.css) into `ThemeData` (dark default, light override). | Visual diff: colors match CSS tokens exactly. |
| 2.1.4 `[M]` | Fonts in `assets/fonts/` (Archivo, Inter, JetBrainsMono, Instrument Serif, Cairo). | Text renders correctly in both AR + EN. |
| 2.1.5 `[M]` | `core/l10n/` — `app_ar.arb` default, `app_en.arb` parity. RTL wrapping works. | Switching locale flips `Directionality`. |
| 2.1.6 `[M]` | `core/router/` — go_router with auth guard + splash redirect. | Unauthenticated users land at /auth/login. |
| 2.1.7 `[M]` | `core/network/dio_client.dart` + `AuthInterceptor` + `RetryInterceptor`. | 401 triggers refresh; refresh fail triggers logout. |
| 2.1.8 `[M]` | `core/di/` — `get_it` + `injectable` with generated bindings. | `flutter pub run build_runner build` clean. |

### 2.2 Feature slices (per design spec — 16 screens)

Build in this order. Each slice: domain entities → usecases → data repo → presentation (cubit + screen + widgets) → widget test → golden test.

| # | Screen | Design ref | Acceptance |
|---|---|---|---|
| 2.2.1 | Splash | `design/project/ui_kits/mobile_app/screens.jsx` | Decides route based on auth + subscription. |
| 2.2.2 | Login | `screens.jsx` | Phone input with `+962` prefix mask. |
| 2.2.3 | OTP verify | `screens.jsx` | 4-cell input, blinking cursor, resend timer. |
| 2.2.4 | Register | `screens.jsx` | Name + optional email; creates user post-OTP. |
| 2.2.5 | Home | `screens.jsx` | Live greeting, active-plan card with visits pulse, CTAs. |
| 2.2.6 | Gyms browse | `screens.jsx` | Filter chips (category, tier, open-now). |
| 2.2.7 | Gym detail | `screens.jsx` | Cover, amenities grid, tier badge, check-in CTA. |
| 2.2.8 | Scan (QR) | `screens.jsx` | `mobile_scanner`, lime scanline animation. |
| 2.2.9 | Check-in success | `screens.jsx` | Lime ring pulse; visits-left chip. |
| 2.2.10 | Plans (pick a pass) | `screens.jsx` | 4 tier cards, compare features. |
| 2.2.11 | Payment (mock) | `screens.jsx` | Method toggle (card/cliq/apple_pay); 1.5s loader; respects mock adapter. |
| 2.2.12 | Welcome / success | `screens.jsx` | Confetti-free; typographic hit — "You're in." |
| 2.2.13 | My subscription | `screens.jsx` | Visit ring, renew-date, upgrade CTA. |
| 2.2.14 | Notifications | `screens.jsx` | List, read/unread, deep-links. |
| 2.2.15 | Profile | `screens.jsx` | Account card, locale switch, logout. |
| 2.2.16 | Settings | `screens.jsx` | Theme, locale, privacy links. |

### 2.3 Tests

| # | Task | Acceptance |
|---|---|---|
| 2.3.1 `[T][M]` | Widget tests for every screen's core interactions. | `flutter test` green. |
| 2.3.2 `[T][M]` | Goldens for 16 screens at AR + EN, dark + light = 64 goldens. | CI diffs fail on regression. |
| 2.3.3 `[T][M]` | Unit tests for every usecase + cubit. | ≥ 80% coverage on `domain/` + `presentation/*cubit*`. |
| 2.3.4 `[I]` | GitHub Action `mobile.yml` — `flutter analyze` + `flutter test`. | PR status green. |

**Phase 2 exits when** the app reaches feature parity with the 16-screen prototype and goldens pass on CI.

---

## Phase 3 — Admin Dashboard MVP

**Goal:** a minimal operational admin that lets staff manage gyms, plans, view checkins, and run monthly payouts.
**Exit:** an admin can log in, create a gym, see check-ins, and mark a payout as paid.

### 3.1 Bootstrap

| # | Task | Acceptance |
|---|---|---|
| 3.1.1 `[A]` | `create-next-app` in `admin/` (App Router, TS, Tailwind). Add `next-intl`, `next-auth@v5`, `react-hook-form`, `zod`, `recharts`, `@tanstack/react-query`. | `npm run dev` boots. |
| 3.1.2 `[A]` | Tailwind theme sourced from [design/project/colors_and_type.css](../design/project/colors_and_type.css) tokens. | No literal hex in Tailwind config. |
| 3.1.3 `[A]` | `lib/auth.ts` — NextAuth with Credentials + Google; Redis adapter. | Admin can sign in with seeded creds. |
| 3.1.4 `[A]` | `lib/api/client.ts` — typed fetch; service-JWT exchange + in-memory cache. | Cached token reused across requests. |
| 3.1.5 `[A]` | `npm run generate-api` — OpenAPI-TS client to `lib/api/generated/`. | Regenerating idempotent; committed diff is readable. |
| 3.1.6 `[A]` | i18n (`next-intl`): AR default, `dir="rtl"` on `<html>`. | Every user-facing string is in `messages/*.json`. |

### 3.2 Pages

| # | Page | Acceptance |
|---|---|---|
| 3.2.1 `[A]` | `/login` | Credentials + Google buttons; redirects to dashboard on success. |
| 3.2.2 `[A]` | `/` (overview KPIs) | Shows total members, active subs, checkins-this-month, payouts-due. |
| 3.2.3 `[A]` | `/gyms` | Table + create/edit dialog; rotate-QR action. |
| 3.2.4 `[A]` | `/plans` | Table + toggle active. |
| 3.2.5 `[A]` | `/members` | Table, filter by tier, view profile drawer. |
| 3.2.6 `[A]` | `/subscriptions` | Table, status filter, cancel action. |
| 3.2.7 `[A]` | `/checkins` | Table with gym/member filters + timeline view. |
| 3.2.8 `[A]` | `/payouts` | Group by gym, month selector, mark-as-paid workflow. |
| 3.2.9 `[A]` | `/audit` | Paginated audit log with actor + action + diff viewer. |
| 3.2.10 `[A]` | `/settings` | Admin account, theme, locale. |

### 3.3 Tests

| # | Task | Acceptance |
|---|---|---|
| 3.3.1 `[T][A]` | Vitest + RTL component tests for every form. | All form validation paths covered. |
| 3.3.2 `[T][A]` | Playwright smoke: login → create gym → assert in list → sign out. | Runs in CI. |
| 3.3.3 `[I]` | GitHub Action `admin.yml`. | PR status green. |

**Phase 3 exits when** the admin can run the business end-to-end without SSH'ing into the DB.

---

## Phase 4 — Prod readiness

**Goal:** deploy end-to-end on a single VM.
**Exit:** `admin.gym-pass.net` and `api.gym-pass.net` are live with valid TLS; a real member can check in on a device connected to the prod API.

| # | Task | Acceptance |
|---|---|---|
| 4.1 `[I]` | `docker-compose.prod.yml` with nginx + certbot sidecar; switch backend to gunicorn. | `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d` yields working prod stack on a VM. |
| 4.2 `[I]` | nginx conf: HTTP→HTTPS, subdomains, gzip, sensible timeouts. | SSL Labs A grade. |
| 4.3 `[I]` | Let's Encrypt first issuance + daily renewal cron. | Cert visible in the volume; `certbot renew --dry-run` passes. |
| 4.4 `[I]` | CI/CD: on merge to `main` → build images → SSH deploy → `alembic upgrade head`. | Green deploy notification in Slack (optional). |
| 4.5 `[B]` | Prod-mode switches verified: CORS locked, debug off, seed disabled. | Manual checklist signed off. |
| 4.6 `[B][A][M]` | Sentry DSNs wired on all three surfaces. | Error in staging appears in Sentry within 30s. |
| 4.7 `[I]` | Backup script for Postgres — daily dump to encrypted object storage. | Restore test succeeds. |
| 4.8 `[M]` | Prep iOS + Android release builds; Google Play internal + TestFlight slots. | Installable on two real devices. |

---

## Phase 5 — Post-MVP (deferred / optional)

- **Real SMS provider** (choose Twilio vs Unifonic vs local).
- **Real payment gateway** (research Jordanian options; Stripe ruled out).
- **Push notifications** end-to-end (FCM + APNs).
- **Class booking** in-app.
- **Gym-owner portal** (v2).
- **Social/referral features.**
- **Grafana + Loki + Tempo observability stack** once traffic warrants.
- **Android App Bundle + iOS store submissions.**

---

## Working-rule reminders

- **SOLID every service.** Providers behind Protocols; services single-responsibility; routes thin.
- **i18n every string.** ARB/messages or it's a bug.
- **Tokens every color.** No hex outside [design/project/colors_and_type.css](../design/project/colors_and_type.css).
- **Audit every mutation.** Same transaction, every time.
- **Tests ship with features.** No merge otherwise.

---

## Tracking

Track progress in a GitHub Project board with four columns (`Backlog`, `In Progress`, `In Review`, `Done`). Each task above becomes an issue; the task ID here maps to the issue title prefix (e.g. `1.4.5 — Check-in validation ladder`).
