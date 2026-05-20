# GymPass — CLAUDE.md

> Authoritative handbook for Claude Code when working in this repo.
> Keep it **accurate** over **aspirational**: if reality drifts from this file, update the file in the same PR.

---

## 1 · What this repo actually is (today)

**Product:** GymPass — a single-subscription, multi-gym access app for Jordan. Members subscribe to a tier (**Silver / Gold / platinum / Diamond**) and check in at partner gyms by scanning a static QR code.

**Current repo state (staged in order of maturity):**

| Surface | Status | Location | Notes |
|---|---|---|---|
| Design system | ⚠️ External / not vendored | _(formerly `design/` — folder removed)_ | The Claude Design bundle (tokens / preview cards / member-app UI kit) was historically vendored at `design/`. It's no longer in the repo. Tokens now live in [mobile/lib/core/theme/gp_tokens.dart](mobile/lib/core/theme/gp_tokens.dart) (mobile) and as CSS variables under each Next app's `globals.css` (admin / gym-partner). **Source of visual truth = those files**, not a `design/` folder. |
| Member prototype (web) | 🟡 Working HTML/JSX | [Gym pass Mobile App/](Gym%20pass%20Mobile%20App/) + Vite scaffold at repo root | Legacy clickable prototype of 16 screens. Used for early stakeholder review; **not** the shipping app. |
| Backend API | 🟢 Pre-prod deployed | [backend/](backend/) | FastAPI 0.135 + SQLAlchemy 2 async + Alembic. 15 migrations applied. Live at `https://api.gym-pass.net`. |
| Member app (production) | 🟢 Built, side-load only | [mobile/](mobile/) | Flutter 3.38, full registration + tier picker + QR scanner. APK distributed via `gym-pass.net/downloads/gympass.apk` (built off-VM, scp'd in). Store listings deferred. |
| Admin dashboard | 🟢 Pre-prod deployed | [admin/](admin/) | Next.js 15 + next-intl, NextAuth → backend service-JWT exchange. Live at `https://admin.gym-pass.net`. |
| Gym partner portal | 🟢 Pre-prod deployed | [gym-partner/](gym-partner/) | Next.js 15 + next-intl. QR generator at `/qr`, live check-ins feed, payouts view. Live at `https://partner.gym-pass.net`. |
| Marketing website | 🟢 Pre-prod deployed | [website/](website/) | Next.js 15 shell serving Claude-Design `RegisterFlow.html` verbatim from `public/`. Live at `https://gym-pass.net`. Also serves the APK download. |
| Reverse proxy / TLS | 🟢 Live | [nginx/](nginx/) | Four vhosts + shared `ssl.conf` snippet + Cloudflare real-IP rewriting. Cloudflare Origin Cert valid 15 years; no certbot. |

**Pre-prod environment:** running on a single VM (35.203.162.232) behind Cloudflare. Stack brought up by [scripts/deploy.sh](scripts/deploy.sh); runbook in [docs/deploy.md](docs/deploy.md). `APP_ENV=development` — OTP fixed to `1234`, payments mocked, no real SMS. Real `production` mode is gated on a real SMS provider + payment gateway (see §15).

**Rule:** don't pretend a surface exists before it does. If you're scaffolding a new surface, follow the layout in §3 and call it out in the PR.

---

## 2 · Tech stack — authoritative

| Layer | Technology | Notes |
|---|---|---|
| **Design reference** | Token files only — see Section 1 | The `design/` folder is no longer vendored; tokens live in [mobile/lib/core/theme/gp_tokens.dart](mobile/lib/core/theme/gp_tokens.dart) + each Next app's CSS variables. |
| **Prototype preview** | React 18 + Vite 5 (Babel-in-browser JSX via CDN) | Root `package.json`. Used to view the Claude Design prototype. |
| **Member app (prod)** | Flutter 3.24+ (iOS + Android) | Single codebase, AR-first. |
| **Admin dashboard** | Next.js 14 App Router + TypeScript + Tailwind + next-intl | Talks to FastAPI over HTTPS. |
| **Backend API** | FastAPI 0.135+ (Python 3.12) | SQLAlchemy 2.0 async + Pydantic v2. |
| **Database** | PostgreSQL 16 | Single primary; Alembic migrations. |
| **Cache / broker / sessions** | Redis 7 | Shared by API, Celery, NextAuth session adapter. |
| **Python deps** | `uv` (Astral) | `pyproject.toml` + `uv.lock`. **Not** pip + requirements.txt. |
| **Background jobs** | Celery (Redis broker) | SMS, payouts, push notifications. |
| **Member auth** | FastAPI-issued JWT (access + refresh) — phone OTP or Google OAuth | Both paths mint the same JWT pair. |
| **Admin auth** | NextAuth.js (Email+Password and Google) → exchanges for service JWT against FastAPI | Redis session adapter. |
| **Reverse proxy** | nginx | TLS termination; only public-facing container. |
| **TLS** | Let's Encrypt via certbot (webroot) | Auto-renew daily. |
| **i18n (mobile)** | `flutter_localizations` + ARB files | AR default, EN parity. |
| **i18n (admin)** | `next-intl` | AR default with `dir="rtl"`. |
| **Logging** | stdout + `structlog` | Collected by Docker. Full observability stack deferred. |
| **Orchestration** | `docker compose` | One compose file for dev, override for prod. |

### Forbidden / avoid

- **No** Flask, Django, or Express — backend is FastAPI.
- **No** Prisma in admin — admin talks to FastAPI, never directly to the DB.
- **No** `pip install` / `requirements.txt` in backend — `uv` only.
- **No** Next.js server actions or route handlers that bypass FastAPI (except `/api/auth/[...nextauth]`).
- **No** Stripe — not viable in Jordan. Payments are mocked; real gateway decision is deferred.
- **No** inline hex colors in mobile or admin — pass through the token layer from [mobile/lib/core/theme/gp_tokens.dart](mobile/lib/core/theme/gp_tokens.dart).
- **No** user-facing strings in code — always ARB (mobile) or `messages/*.json` (admin).

---

## 3 · Repository layout (monorepo — target)

```
gym-pass-pro/
├── CLAUDE.md                         # ← you are here
├── README.md                         # Human-facing project readme
├── package.json                      # Vite prototype host (root)
├── index.html                        # Vite entry — legacy prototype host, now mostly idle since design/ was un-vendored
├── vite.config.js
├── docker-compose.yml                # Dev stack — hot-reload + per-service ports exposed
├── docker-compose.prod.yml           # Prod overlay — restart:always, ports unpublished except nginx
├── .env.example                      # Dev defaults
├── .env.prod.example                 # Prod template (copy to .env.prod on the VM)
├── .gitignore
│
│   (`design/` — Claude Design bundle — has been un-vendored. Tokens
│    now live in mobile/lib/core/theme/gp_tokens.dart and per-app
│    CSS variables. See Section 1.)
│
├── Gym pass Mobile App/              # Legacy prototype (pre-design-bundle import)
│   ├── Gym Pass Prototype.html       # Standalone entry
│   └── app/                          # colors_and_type.css, common.jsx, auth_screens.jsx, main_screens.jsx
│
├── docs/                             # 📚 Engineering references
│   ├── architecture.md               # Layered architecture + SOLID rationale
│   ├── tasks.md                      # Phased implementation plan
│   ├── database-schema.md            # DB tables, relations, indexes
│   ├── api-standards.md              # Endpoint conventions, error codes, versioning
│   ├── git-instructions.md           # Branching, commit, PR, release rules
│   ├── admin-run.md                  # Admin-app dev/run instructions
│   ├── gotchas.md                    # Working gotchas + Phase B triggers
│   ├── manual-test-plan.html         # Manual QA matrix
│   └── deploy.md                     # 🚀 VM bring-up + deploy runbook
│
├── backend/                          # FastAPI service — live at api.gym-pass.net
├── admin/                            # Next.js admin dashboard — live at admin.gym-pass.net
├── gym-partner/                      # Next.js partner portal — live at partner.gym-pass.net
├── website/                          # Next.js marketing shell — live at gym-pass.net
├── mobile/                           # Flutter member app (APK side-loaded from /downloads/)
├── nginx/                            # TLS-terminating reverse proxy (Cloudflare Origin Cert)
│   ├── conf.d/                       # Four vhosts (api / admin / partner / website) + cloudflare.conf
│   ├── snippets/ssl.conf             # Shared TLS block, mounted by every vhost
│   └── certs/                        # gym-pass.net.{pem,key} — gitignored; placed at deploy time
├── skills-lib/                       # Vendored Claude skills (read-only reference)
└── scripts/                          # deploy.sh, build-apk.sh, seed.py
```

**Folder boundaries are strict:** `backend/` must not import from `admin/` or `mobile/`, and vice versa. Cross-service contracts live in the OpenAPI schema that FastAPI emits; the admin consumes it through a generated client.

---

## 4 · Environment modes — dev vs production

Controlled by `APP_ENV` in `.env`. Two values only: `development` and `production`.

### Dev mode (`APP_ENV=development`)

- **SMS OTP:** not sent. Valid code is always `1234`. OTP endpoint logs the would-be code to stdout.
- **Payments:** fully mocked. Card / CliQ / Apple Pay calls return success after a 1.5s simulated delay.
- **Emails:** logged to stdout.
- **Google OAuth:** dev-only Google Cloud credentials.
- **Celery:** `task_always_eager=True` — in-process, no worker container required. A worker is still defined for parity testing.
- **CORS:** permissive (`*`) for localhost.
- **Debug:** FastAPI `debug=True`, pretty JSON, full stack traces.
- **DB:** `scripts/seed.py` bootstraps **only** gyms, plans, the admin bootstrap user, and one demo member — nothing else.

> **No other mocks.** The only sanctioned dev-mode mocks are SMS OTP and the payment provider. There is **no "demo mode" toggle**, **no `seed_demo_*.py` scripts**, **no hardcoded demo tickets/checkins/payouts/notifications**, and **no fallback/mock aggregates in admin dashboards**. If a UI renders empty in dev because no real rows exist, that is correct behaviour — do not paper over it with literals.

### Production mode (`APP_ENV=production`)

- **SMS OTP:** real provider (provider choice deferred — see §15 Open Questions).
- **Payments:** still mocked until a gateway is chosen; mock response is logged so it's obvious.
- **Emails:** real SMTP.
- **Google OAuth:** real Google Cloud credentials.
- **Celery:** full worker container running.
- **CORS:** locked to `https://admin.gym-pass.net` only.
- **Debug:** `debug=False`, generic error responses, detailed errors only in logs.
- **DB:** no seeding; migrations applied via short-lived migrator container on deploy.

### `.env.example` required keys

See [docs/architecture.md §8](docs/architecture.md) for the full list.

---

## 5 · Data model (pointer)

The canonical schema — tables, columns, constraints, indexes, and the reasoning behind each — lives in **[docs/database-schema.md](docs/database-schema.md)**. Do not document schema in this file.

Tiers: `silver`, `gold`, `platinum`, `diamond`. Categories: `gym`, `crossfit`, `martial`, `yoga`. Every domain mutation writes an `audit_log` entry (see §12 Working rules).

---

## 6 · API contract (pointer)

Endpoint naming, versioning, error-envelope shape, and pagination rules live in **[docs/api-standards.md](docs/api-standards.md)**. The FastAPI app is the single source of truth for endpoints; OpenAPI is auto-emitted at `/docs` (dev) and `/api/openapi.json`.

Error codes from the design spec (e.g. `AUTH_OTP_INVALID`, `CHECKIN_TIER_LOCKED`) are canonical and **must not be renamed**.

---

## 7 · Auth flows (pointer)

Full flows — phone OTP, Google OAuth, admin NextAuth ↔ service JWT exchange — are documented in [docs/architecture.md §5](docs/architecture.md). Summary:

- Members: two entry paths (phone OTP or Google), one JWT-pair session model.
- Admins: NextAuth owns the browser session; it exchanges for a short-lived service JWT against `POST /api/v1/admin/session-token` on each backend call. Backend only trusts service JWTs it issued itself.

---

## 8 · QR check-in flow (pointer)

Static QR per gym (encodes gym UUID only). All security is server-side. Full validation ladder in [docs/architecture.md §6](docs/architecture.md).

Rotating a gym's QR = regenerating its UUID via admin endpoint, which invalidates the old prints.

---

## 9 · Payments (currently mocked)

All payment code goes through `services/payment_service.py` behind a provider interface. Adding a real gateway later = implementing a new adapter class behind the same interface. **Do not** scatter gateway-specific code elsewhere.

Supported method tags in v1: `card`, `cliq`, `apple_pay`, `google_pay`. Dev mode accepts any of them. The mobile add-method sheet platform-gates the wallets — Apple Pay only on iOS, Google Pay only on Android — so a member is never offered a wallet they can't open.

---

## 10 · Internationalization & RTL

- **Default locale:** Arabic (AR) on both mobile and admin.
- **Mobile:** Cairo (AR) + Archivo (EN display) + Inter (EN body) + JetBrains Mono (labels). Defined in [mobile/lib/core/theme/gp_text.dart](mobile/lib/core/theme/gp_text.dart) with locale-aware accessors (`GPText.displayFor(lang, ...)`, `DisplayText` widget).
- **Admin:** system fonts; flips direction via `next-intl` + `dir="rtl"` on `<html>`.
- **Every** user-facing string is in `.arb` (mobile) or `messages/*.json` (admin). No inline literals.
- **Currency:** `45 JOD` (EN) / `٤٥ د.أ` (AR). Currency code/symbol after the number in both locales.
- **Numbers:** Western digits `0–9` in **both** locales — Jordanian convention for modern apps. Never Eastern Arabic digits (`٠–٩`) unless specifically styled for currency display.
- **Phone format:** `+962 7X XXX XXXX`.

---

## 11 · docker-compose (pointer)

Dev stack: `docker-compose.yml` — bind-mounted source for hot reload, each Next service bound to its own host port.

Prod overlay: `docker-compose.prod.yml` — services pinned to `target: runner`, ports unpublished except nginx 80/443, `env_file: [.env.prod]` per service, `restart: always`. Build-args (`NEXTAUTH_SECRET`, `ADMIN_EXCHANGE_SECRET`) are read from `.env.prod` at build time so the Next.js apps' Zod env-schemas pass during `next build`.

TLS: Cloudflare Origin Cert mounted from `nginx/certs/gym-pass.net.{pem,key}` — gitignored, placed on the VM at deploy time. No certbot. Zone TLS mode must be **Full (strict)** in the Cloudflare panel.

Full topology — services, ports, volumes, nginx vhosts, Cloudflare real-IP rewriting — in [docs/architecture.md §7](docs/architecture.md). End-to-end VM bring-up + deploy runbook in [docs/deploy.md](docs/deploy.md).

---

## 12 · Working rules for Claude Code

These are non-negotiable during code changes:

1. **Token-driven UI.** No `design/` folder anymore; use [mobile/lib/core/theme/gp_tokens.dart](mobile/lib/core/theme/gp_tokens.dart) + [mobile/lib/core/theme/gp_text.dart](mobile/lib/core/theme/gp_text.dart) on mobile and the per-app `globals.css` CSS-variable layer on each Next app. Match existing screens; don't invent new colors / type ramps.
2. **Read this file's relevant section before touching a new area.** If something contradicts this file, ask — don't silently work around.
3. **Strict folder boundaries.** Backend code does not import from admin or mobile. Cross-service contracts go through the OpenAPI schema.
4. **No new dependencies without justification.** If a new library is needed, explain why the current stack doesn't cover it in the PR description.
5. **No hardcoded strings anywhere user-facing.** Always go through the i18n layer.
6. **No hardcoded hex colors** in mobile or admin. Mobile goes through [mobile/lib/core/theme/gp_tokens.dart](mobile/lib/core/theme/gp_tokens.dart) (`GP.*` constants + `gp.*` context palette). Admin / gym-partner go through the CSS variables (`--bg / --paper / --accent / --line / …`) defined in each app's `globals.css`.
7. **No raw SQL in endpoints** — SQLAlchemy models + services only.
8. **Every DB schema change needs an Alembic migration.** Never edit past migrations.
9. **Dev mode must remain frictionless.** OTP = `1234`, payments mocked, `scripts/seed.py` provides the minimal bootstrap. **Those are the only dev-mode mocks.** No "demo mode" flag, no `seed_demo_*` scripts, no hardcoded demo users / tickets / checkins / payouts / notifications anywhere in code, migrations, or UI. Do not add mock aggregates or fallback literals to hide API failures — empty states and error states are what the user wants to see.
10. **Tests ship with features.** A new endpoint without a service-layer test is incomplete.
11. **Audit-log every mutation.** If a service mutates DB state, it writes to `audit_log` in the same transaction.
12. **Defer the deferred.** SMS provider, payment gateway, and full observability stack are deliberately undecided. Do not pick one without asking.
13. **Follow SOLID in services.** Dependency injection via FastAPI's `Depends`; single-responsibility services; provider/adapter patterns for SMS, payments, push. See [docs/architecture.md §10](docs/architecture.md).
14. **Follow git flow in [docs/git-instructions.md](docs/git-instructions.md).** Branch naming, conventional commits, PR template, release cadence.

### When starting a new task

1. Read the relevant sections of this file and of [docs/tasks.md](docs/tasks.md).
2. If it's UI, scan the analogous existing screen for tokens / patterns. Mobile = `mobile/lib/features/<area>/presentation/`; Next apps = the matching route folder. Reuse the existing tokens, never invent new ones.
3. Summarize the plan in 3–5 lines before writing code.
4. Run existing tests first to confirm a clean baseline.
5. Keep changes scoped to one folder where possible.

### When unsure

**Ask.** Cheaper than rework.

---

## 13 · Testing strategy

- **Backend:** `pytest` + `httpx` + `pytest-asyncio`. Test DB is a separate Postgres schema spun up per test run. Target 80%+ coverage on `services/` and `api/`.
- **Admin:** Vitest + React Testing Library for components; Playwright for smoke E2E (login → dashboard → create-gym).
- **Mobile:** `flutter test` for widget + golden tests on key screens (sign-in, gym detail, buy-sheet, profile). Currently sparse — see Section 15 Open Questions.

CI runs all three on PR (GitHub Actions). A PR that drops backend coverage or fails mobile goldens cannot merge.

---

## 14 · Quick reference

### Common commands

```bash
# Prototype preview (current working surface)
npm install
npm run dev                           # Vite at http://localhost:5173

# Full dev stack (once backend/admin exist)
docker compose up -d
docker compose logs -f backend

# Migrations
docker compose run --rm migrator alembic revision --autogenerate -m "add X"
docker compose run --rm migrator alembic upgrade head

# Seed dev data
docker compose run --rm backend python scripts/seed.py

# Generate admin API client from OpenAPI
cd admin && npm run generate-api

# Flutter
cd mobile && flutter pub get && flutter run

# Tests
cd backend && uv run pytest
cd admin && npm test
cd mobile && flutter test
```

### Glossary

- **Tier** — Silver / Gold / platinum / Diamond; controls gym access and visit count.
- **Check-in** — A verified scan at a gym; creates a `checkins` + `payout_ledger` row.
- **Payout** — Monthly aggregation of `payout_ledger` entries per gym.
- **Service JWT** — Short-lived JWT the backend mints for admin dashboard server-to-server calls.
- **Static QR** — Each gym's QR encodes only its UUID. Security is server-side; rotate by regenerating the UUID.

---

## 15 · Open questions (update in PRs as they resolve)

- Which **SMS provider** for production? (Twilio / Unifonic / local Jordan provider?) — pre-prod runs `APP_ENV=development` with OTP `1234`; flipping to real `production` mode is gated on this.
- Which **payment gateway** for production? Stripe is ruled out.
- **APK distribution** — currently a single `app-release.apk` served from `gym-pass.net/downloads/`. Play Store + App Store listings deferred until SMS + payments are live.
- **Push notifications** — FCM + APNs directly, or through a service like OneSignal?
- **Observability stack** — Sentry alone, or Sentry + Grafana + Loki from day one? Pre-prod ships only stdout logging via Docker.

**Resolved:**
- ~~**Gym-owner portal** in v2 or keep reports email-based?~~ → Shipped: [gym-partner/](gym-partner/) (live at `partner.gym-pass.net`).
- ~~**TLS strategy** — Let's Encrypt via certbot, or Cloudflare Origin Cert?~~ → Cloudflare Origin Cert (15-year validity, no renewal automation needed).

---

## 16 · Pointers (reference docs)

- Architecture: [docs/architecture.md](docs/architecture.md)
- Tasks: [docs/tasks.md](docs/tasks.md)
- DB schema: [docs/database-schema.md](docs/database-schema.md)
- API standards: [docs/api-standards.md](docs/api-standards.md)
- Git flow: [docs/git-instructions.md](docs/git-instructions.md)
- Gotchas + Phase B triggers: [docs/gotchas.md](docs/gotchas.md)
- VM bring-up + deploy runbook: [docs/deploy.md](docs/deploy.md)
- Admin dev run: [docs/admin-run.md](docs/admin-run.md)
- Marketing site (design + serving): [website/README.md](website/README.md)
- Design tokens: [mobile/lib/core/theme/gp_tokens.dart](mobile/lib/core/theme/gp_tokens.dart) · [mobile/lib/core/theme/gp_text.dart](mobile/lib/core/theme/gp_text.dart) · each Next app's `globals.css`
