# GymPass — CLAUDE.md

> Authoritative handbook for Claude Code when working in this repo.
> Keep it **accurate** over **aspirational**: if reality drifts from this file, update the file in the same PR.

---

## 1 · What this repo actually is (today)

**Product:** GymPass — a single-subscription, multi-gym access app for Jordan. Members subscribe to a tier (**Silver / Gold / platinum / Diamond**) and check in at partner gyms by scanning a static QR code.

**Current repo state (staged in order of maturity):**

| Surface | Status | Location | Notes |
|---|---|---|---|
| Design system | ✅ Authoritative | [design/](design/) | Imported from Claude Design bundle — tokens, preview cards, member-app UI kit. **Source of visual truth.** |
| Member prototype (web) | 🟡 Working HTML/JSX | [Gym pass Mobile App/](Gym%20pass%20Mobile%20App/) + Vite scaffold at repo root | Clickable prototype of 16 screens. Used for stakeholder review; **not** the shipping app. |
| Member app (production) | 🔴 Not started | `mobile/` (planned) | Flutter, per design spec §14. |
| Backend API | 🔴 Not started | `backend/` (planned) | FastAPI + PostgreSQL. |
| Admin dashboard | 🔴 Not started | `admin/` (planned) | Next.js + next-intl. |

**Rule:** don't pretend a surface exists before it does. If you're scaffolding a new surface, follow the layout in §3 and call it out in the PR.

---

## 2 · Tech stack — authoritative

| Layer | Technology | Notes |
|---|---|---|
| **Design reference** | HTML/CSS prototypes + `colors_and_type.css` tokens | Under [design/](design/). Treat as read-only spec. |
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
- **No** inline hex colors in mobile or admin — pass through the token layer from [design/colors_and_type.css](design/project/colors_and_type.css).
- **No** user-facing strings in code — always ARB (mobile) or `messages/*.json` (admin).

---

## 3 · Repository layout (monorepo — target)

```
gym-pass-pro/
├── CLAUDE.md                         # ← you are here
├── README.md                         # Human-facing project readme
├── package.json                      # Vite prototype host (root)
├── index.html                        # Vite entry (loads design/ prototype)
├── vite.config.js
├── docker-compose.yml                # Dev stack (once backend/admin land)
├── docker-compose.prod.yml           # Prod overrides
├── .env.example
├── .gitignore
│
├── design/                           # 🎨 SOURCE OF VISUAL TRUTH (read-only)
│   ├── README.md                     # Claude Design bundle readme — READ FIRST for UI work
│   ├── chats/                        # Original design-session transcript
│   └── project/
│       ├── README.md                 # Design-system overview (tokens, type, icons, voice)
│       ├── SKILL.md                  # Agent-skill spec
│       ├── colors_and_type.css       # Token source of truth — import everywhere
│       ├── assets/                   # Wordmark SVG, icon sprite
│       ├── fonts/                    # (CDN — no files needed)
│       ├── preview/                  # Token/component review cards
│       ├── uploads/                  # Original single-file design spec
│       └── ui_kits/
│           └── mobile_app/           # Interactive member-app prototype (16 screens)
│
├── Gym pass Mobile App/              # Legacy prototype (pre-design-bundle import)
│   ├── Gym Pass Prototype.html       # Standalone entry
│   └── app/                          # colors_and_type.css, common.jsx, auth_screens.jsx, main_screens.jsx
│
├── docs/                             # 📚 Engineering references
│   ├── architecture.md               # Layered architecture + SOLID rationale
│   ├── tasks.md                      # Phased implementation plan (ground truth for work)
│   ├── database-schema.md            # DB tables, relations, indexes
│   ├── api-standards.md              # Endpoint conventions, error codes, versioning
│   └── git-instructions.md           # Branching, commit, PR, release rules
│
├── backend/                          # FastAPI service (planned — see docs/architecture.md §2)
├── admin/                            # Next.js admin dashboard (planned — see docs/architecture.md §3)
├── mobile/                           # Flutter member app (planned — see docs/architecture.md §4)
├── nginx/                            # TLS-terminating reverse proxy (planned)
├── skills-lib/                       # Vendored Claude skills (read-only reference)
└── scripts/                          # dev.sh, seed.py, reset.sh (planned)
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
- **Mobile:** Cairo (AR) + Archivo (EN display) + Inter (EN body) + JetBrains Mono (labels). Full design spec in [design/project/README.md](design/project/README.md).
- **Admin:** system fonts; flips direction via `next-intl` + `dir="rtl"` on `<html>`.
- **Every** user-facing string is in `.arb` (mobile) or `messages/*.json` (admin). No inline literals.
- **Currency:** `45 JOD` (EN) / `٤٥ د.أ` (AR). Currency code/symbol after the number in both locales.
- **Numbers:** Western digits `0–9` in **both** locales — Jordanian convention for modern apps. Never Eastern Arabic digits (`٠–٩`) unless specifically styled for currency display.
- **Phone format:** `+962 7X XXX XXXX`.

---

## 11 · docker-compose (pointer)

Dev and prod stack topology — services, ports, volumes, nginx routing, certbot flow — live in [docs/architecture.md §7](docs/architecture.md).

---

## 12 · Working rules for Claude Code

These are non-negotiable during code changes:

1. **Read [design/README.md](design/README.md) and [design/project/README.md](design/project/README.md) before touching any UI.** The design is the source of visual truth, pixel-for-pixel within reason.
2. **Read this file's relevant section before touching a new area.** If something contradicts this file, ask — don't silently work around.
3. **Strict folder boundaries.** Backend code does not import from admin or mobile. Cross-service contracts go through the OpenAPI schema.
4. **No new dependencies without justification.** If a new library is needed, explain why the current stack doesn't cover it in the PR description.
5. **No hardcoded strings anywhere user-facing.** Always go through the i18n layer.
6. **No hardcoded hex colors** in mobile or admin. Go through the design tokens from [design/project/colors_and_type.css](design/project/colors_and_type.css).
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
2. If it's UI, read the relevant sections of [design/project/README.md](design/project/README.md) and the matching preview card under [design/project/preview/](design/project/preview/).
3. Summarize the plan in 3–5 lines before writing code.
4. Run existing tests first to confirm a clean baseline.
5. Keep changes scoped to one folder where possible.

### When unsure

**Ask.** Cheaper than rework.

---

## 13 · Testing strategy

- **Backend:** `pytest` + `httpx` + `pytest-asyncio`. Test DB is a separate Postgres schema spun up per test run. Target 80%+ coverage on `services/` and `api/`.
- **Admin:** Vitest + React Testing Library for components; Playwright for smoke E2E (login → dashboard → create-gym).
- **Mobile:** `flutter test` for widget tests; golden tests for the key screens from [design/project/ui_kits/mobile_app/](design/project/ui_kits/mobile_app/).

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

- Which **SMS provider** for production? (Twilio / Unifonic / local Jordan provider?)
- Which **payment gateway** for production? Stripe is ruled out.
- **Gym-owner portal** in v2 or keep reports email-based?
- **Push notifications** — FCM + APNs directly, or through a service like OneSignal?
- **Observability stack** — Sentry alone, or Sentry + Grafana + Loki from day one?

---

## 16 · Pointers (reference docs)

- Architecture: [docs/architecture.md](docs/architecture.md)
- Tasks: [docs/tasks.md](docs/tasks.md)
- DB schema: [docs/database-schema.md](docs/database-schema.md)
- API standards: [docs/api-standards.md](docs/api-standards.md)
- Git flow: [docs/git-instructions.md](docs/git-instructions.md)
- Design system: [design/README.md](design/README.md), [design/project/README.md](design/project/README.md)
