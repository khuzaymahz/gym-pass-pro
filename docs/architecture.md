# Architecture — GymPass

> Engineering blueprint for the full GymPass stack.
> Binds the design system ([design/](../design/)) to a production-grade monorepo.
> Applies SOLID consistently across backend, admin, and mobile.

---

## 1 · High-level topology

```
┌────────────────────────────────┐    ┌─────────────────────────────────┐
│   Member App (Flutter)         │    │   Admin Dashboard (Next.js)     │
│   iOS · Android · AR-first     │    │   Browser · AR-first RTL        │
└──────────────┬─────────────────┘    └──────────────┬──────────────────┘
               │ JWT (member)                        │ NextAuth session → Service JWT
               │ HTTPS                               │ HTTPS
               ▼                                     ▼
               ┌──────────────────────────────────────────┐
               │              nginx (TLS)                 │
               │   api.gym-pass.net · admin.gym-pass.net  │
               └──────┬────────────────────┬──────────────┘
                      │                    │
                      ▼                    ▼
         ┌────────────────────────────────────────┐
         │         FastAPI Backend (Python)       │
         │  api/  schemas/  services/  workers/   │
         └──────┬──────────────────┬──────────────┘
                │                  │
                ▼                  ▼
         ┌────────────┐     ┌───────────────┐
         │ PostgreSQL │     │  Redis (cache │
         │   16       │     │  + broker +   │
         │            │     │  admin sess.) │
         └────────────┘     └───────┬───────┘
                                    │
                                    ▼
                            ┌──────────────┐
                            │ Celery worker│
                            │ (SMS, payout │
                            │  aggregation,│
                            │  push)       │
                            └──────────────┘
```

- Only **nginx** is publicly exposed.
- **Postgres** and **Redis** are internal-only Docker services (no host ports in prod).
- **No** direct DB access from the admin — the admin always goes through FastAPI.

---

## 2 · Backend — FastAPI layered architecture

Five layers, strictly one-way dependencies: **api → services → repositories → models → db**.
Schemas (DTOs) sit beside `api/` and never leak ORM types back to the caller.

```
backend/app/
├── main.py                       # FastAPI entrypoint, wires routers, middleware, lifespan
├── config.py                     # Pydantic Settings — reads .env, single source of runtime config
│
├── api/                          # HTTP layer — thin: validate DTO, call service, return DTO
│   ├── deps.py                   # get_current_user, get_db, get_current_admin
│   └── v1/
│       ├── auth.py
│       ├── gyms.py
│       ├── plans.py
│       ├── subscriptions.py
│       ├── payments.py
│       ├── checkins.py
│       ├── notifications.py
│       └── admin/                # Admin-only endpoints, require role=admin
│           ├── gyms.py
│           ├── plans.py
│           ├── members.py
│           ├── subscriptions.py
│           ├── checkins.py
│           ├── payouts.py
│           └── audit.py
│
├── schemas/                      # Pydantic v2 request/response models — never return ORM objects
│   ├── auth.py
│   ├── gym.py
│   ├── plan.py
│   └── …
│
├── services/                     # Business logic, use-case oriented
│   ├── auth_service.py
│   ├── checkin_service.py        # Validation ladder (see §6)
│   ├── subscription_service.py
│   ├── payout_service.py
│   ├── payment_service.py        # Adapter boundary for gateway
│   ├── sms_service.py            # Adapter boundary for SMS provider
│   ├── notification_service.py
│   └── audit_service.py          # Writes audit_log in-transaction
│
├── repositories/                 # Thin wrappers over SQLAlchemy — pure data access, no business rules
│   ├── user_repo.py
│   ├── gym_repo.py
│   ├── subscription_repo.py
│   ├── checkin_repo.py
│   └── …
│
├── db/
│   ├── base.py                   # DeclarativeBase, naming conventions
│   ├── session.py                # async_sessionmaker, get_session
│   └── models/                   # SQLAlchemy 2.0 ORM — mirrors docs/database-schema.md
│       ├── user.py
│       ├── gym.py
│       ├── subscription.py
│       ├── checkin.py
│       └── …
│
├── core/
│   ├── security.py               # JWT encode/verify, password hashing (argon2)
│   ├── exceptions.py             # AppError base + error codes from design spec
│   ├── logging.py                # structlog config
│   └── i18n.py                   # Locale detection helper (Accept-Language + fallback)
│
├── providers/                    # Adapter interfaces + impls (§10 SOLID)
│   ├── sms/
│   │   ├── base.py               # class SmsProvider(Protocol)
│   │   ├── mock.py               # dev default
│   │   ├── twilio.py             # (placeholder)
│   │   └── unifonic.py           # (placeholder)
│   ├── payments/
│   │   ├── base.py               # class PaymentProvider(Protocol)
│   │   └── mock.py
│   └── push/
│       ├── base.py
│       └── fcm.py
│
├── workers/
│   ├── celery_app.py
│   └── tasks/
│       ├── sms.py                # async_send_otp(phone, code)
│       ├── payouts.py            # monthly_aggregate_payouts()
│       └── notifications.py
│
└── tests/
    ├── conftest.py               # Test DB fixture per-run schema
    ├── factories/                # Factory-Boy style fixtures
    ├── unit/                     # Services, providers, utils
    ├── api/                      # httpx-driven route tests
    └── e2e/
```

### Request lifecycle

```
HTTP → nginx → uvicorn → FastAPI router (api/v1/…)
     → Pydantic DTO validation
     → dependency resolution (deps.py: auth, db session)
     → service call  (services/*_service.py)
     → repository call (repositories/*_repo.py)
     → SQLAlchemy model  (db/models/*.py)
     → DB
     ◄ DTO shaped by schemas/*.py
HTTP ◄
```

**Transaction boundary:** one per request, opened in `get_session`, committed by the service on success, rolled back on exception. Audit entries are written **inside** the same transaction as the mutation.

---

## 3 · Admin — Next.js 14 App Router

```
admin/
├── app/
│   ├── layout.tsx                # HTML shell, dir from locale
│   ├── (auth)/
│   │   └── login/page.tsx
│   ├── (dashboard)/
│   │   ├── layout.tsx            # auth guard, shell
│   │   ├── page.tsx              # overview / KPIs
│   │   ├── gyms/
│   │   ├── plans/
│   │   ├── members/
│   │   ├── subscriptions/
│   │   ├── checkins/
│   │   ├── payouts/
│   │   ├── audit/
│   │   └── settings/
│   └── api/
│       └── auth/[...nextauth]/   # ONLY server route allowed — NextAuth callback
│
├── components/
│   ├── ui/                       # Primitives: Button, Pill, Card, Chip, Input (token-driven)
│   ├── tables/                   # Paginated, sortable tables
│   ├── forms/                    # React Hook Form + zod
│   └── charts/                   # Recharts wrappers for payout, check-in trends
│
├── lib/
│   ├── api/
│   │   ├── client.ts             # Typed fetch wrapper — injects service JWT
│   │   └── generated/            # OpenAPI-generated client (npm run generate-api) — DO NOT EDIT
│   ├── auth.ts                   # NextAuth config (providers, callbacks, adapters)
│   ├── i18n.ts                   # next-intl config
│   └── tokens.ts                 # Imports design tokens into Tailwind theme
│
├── messages/
│   ├── en.json
│   └── ar.json
│
└── tailwind.config.ts            # Tokens sourced from design/project/colors_and_type.css values
```

**Auth flow:**

1. User signs into NextAuth (Credentials or Google).
2. On each request to FastAPI, admin client calls `POST /api/v1/admin/session-token` exchanging the session cookie for a **short-lived service JWT** (5 min TTL).
3. Client caches the service JWT until near expiry, then refreshes.
4. FastAPI verifies the service JWT signed by its own secret — only trusts self-minted tokens.

**No Prisma. No direct DB calls. No Next.js route handlers other than `/api/auth/[...nextauth]`.**

---

## 4 · Mobile — Flutter member app

```
mobile/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── app.dart                  # MaterialApp.router + theme + localization wiring
│   │
│   ├── core/
│   │   ├── config/               # AppConfig (dev/prod via --dart-define)
│   │   ├── di/                   # get_it + injectable registration
│   │   ├── errors/               # AppException, Failure types, error-code mapping
│   │   ├── network/              # Dio client, AuthInterceptor, RetryInterceptor
│   │   ├── router/               # go_router config + guards
│   │   ├── storage/              # flutter_secure_storage wrapper
│   │   ├── theme/                # Token mapping from design/colors_and_type.css → ThemeData
│   │   └── l10n/                 # Generated from ARB
│   │
│   ├── features/                 # Feature-first organization (§10 SRP)
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── datasources/  # remote (Dio) + local (secure storage)
│   │   │   │   ├── models/       # JSON-serializable DTOs
│   │   │   │   └── repositories/ # Impl of domain contract
│   │   │   ├── domain/
│   │   │   │   ├── entities/     # Pure Dart, framework-free
│   │   │   │   ├── repositories/ # Abstract contracts
│   │   │   │   └── usecases/     # RequestOtp, VerifyOtp, SignInGoogle, RefreshToken
│   │   │   └── presentation/
│   │   │       ├── screens/      # SplashScreen, LoginScreen, OtpScreen, RegisterScreen
│   │   │       ├── widgets/
│   │   │       └── cubit/ or bloc/
│   │   ├── home/
│   │   ├── gyms/                 # Browse, detail
│   │   ├── checkin/              # QR scan, success
│   │   ├── plans/                # Tier picker, upgrade
│   │   ├── payment/              # Mock gateway UI
│   │   ├── subscription/         # My plan, visits remaining
│   │   ├── notifications/
│   │   └── profile/              # Settings, logout, locale switch
│   │
│   └── l10n/
│       ├── app_ar.arb            # Default
│       └── app_en.arb
│
├── assets/
│   ├── icons/                    # Exported from design/project/assets/icons.svg
│   └── fonts/                    # Cairo, Archivo, Inter, JetBrainsMono, Instrument Serif
│
├── ios/
├── android/
└── test/
    ├── unit/                     # Usecases, cubits, mappers
    ├── widget/                   # Screen + widget tests
    └── golden/                   # Screen goldens for the 16 prototype screens
```

**State management:** Cubit/Bloc (`flutter_bloc`), per feature. DI via `get_it` + `injectable`. Navigation via `go_router` with auth guard.

**Pattern:** Clean Architecture with three inner layers (`data` → `domain` ← `presentation`). Domain has no Flutter or third-party imports — only pure Dart. Enforced by `import_lint`/`dart_code_metrics` rules.

---

## 5 · Auth flows (detail)

### Member — Phone OTP

```
Flutter                                       FastAPI                     Redis
   │                                             │                           │
   │ POST /api/v1/auth/otp/request {phone}       │                           │
   ├─────────────────────────────────────────▶   │                           │
   │                                             │ Hash(code) + TTL 5m       │
   │                                             ├──────────────────────────▶│
   │                                             │                           │
   │                                             │ Enqueue SMS task (prod)   │
   │                                             │ or log "1234" (dev)       │
   │ 200 {ok: true}                              │                           │
   │◄────────────────────────────────────────────│                           │
   │                                             │                           │
   │ POST /api/v1/auth/otp/verify {phone, code}  │                           │
   ├─────────────────────────────────────────▶   │                           │
   │                                             │ Compare hash, consume     │
   │                                             ├──────────────────────────▶│
   │                                             │ Issue access + refresh    │
   │ 200 {accessToken, refreshToken, user, isNewUser}                        │
   │◄────────────────────────────────────────────│                           │
```

If `isNewUser=true`, Flutter routes to Register screen; else Home (if has subscription) or Plans.

### Member — Google OAuth

1. Flutter obtains Google ID token via native SDK (`google_sign_in`).
2. `POST /api/v1/auth/google {idToken}` — backend verifies against Google's JWKS.
3. Backend creates or finds user by `google_sub`, issues the same JWT pair.

Both paths return the same payload shape: `{accessToken, refreshToken, user, isNewUser}`.

### Admin — NextAuth ↔ Service JWT

```
Browser ──► NextAuth (Credentials or Google) ──► session cookie (Redis-adapter backed)
Browser ──► POST /api/v1/admin/session-token  (with NextAuth session cookie forwarded)
   ◄── {serviceToken, expiresAt}  (TTL 5 min, signed with backend's own secret)
Browser ──► any backend call with Authorization: Bearer <serviceToken>
```

The admin client caches `serviceToken` in memory and refreshes ~30s before expiry. Admin users have `role=admin` set manually in the DB for v1 (no signup flow).

### JWT specifics

- Access: 15 min TTL, carries `{sub: user_id, role, tier}`.
- Refresh: 30 days TTL, opaque-ish (carries `sub` + rotation token ID tracked in Redis so refresh can be revoked).
- Algorithm: `HS256` with `JWT_SECRET`. Rotate by deploying new secret + dual-verify grace window.

---

## 6 · QR check-in validation ladder

Ordered — first failure returns immediately. Every branch writes an audit entry.

```
POST /api/v1/checkins {qrToken: <gym_uuid>, at: <iso8601>}
  Authorization: Bearer <member_access_token>

1. Auth            → 401 if invalid/expired token
2. QR resolves     → CHECKIN_QR_INVALID if no gym found with that UUID or gym.is_active=false
3. Subscription    → SUB_EXPIRED if no active subscription (status=active, not past expires_at)
4. Tier gate       → CHECKIN_TIER_LOCKED if member.tier.rank < gym.required_tier.rank
5. Visits budget   → CHECKIN_NO_VISITS if subscription.visits_used >= plan.monthly_visits (skip for diamond unlimited)
6. Rate limit      → RATE_LIMITED if same user checked in within last 30 min (Redis key w/ TTL)
7. On success:
     INSERT checkins(...)
     UPDATE subscriptions SET visits_used = visits_used + 1
     INSERT payout_ledger(gym_id, checkin_id, amount_jod = gym.per_visit_rate)
     INSERT audit_log(...)
     (single transaction — all or nothing)
   Return 201 {gym, visitsLeft, scannedAt}
```

**Rotating a QR:** admin calls `POST /api/v1/admin/gyms/{id}/rotate-qr` which issues a new UUID. Old prints decode to a now-unknown UUID → returns `CHECKIN_QR_INVALID`.

---

## 7 · docker-compose topology

### Dev (`docker-compose.yml`)

| Service | Image / Build | Purpose | Host port |
|---|---|---|---|
| `db` | `postgres:16-alpine` | Primary database | 5432 (localhost only) |
| `redis` | `redis:7-alpine` | Cache, sessions, broker | 6379 (localhost only) |
| `migrator` | `./backend` (alembic) | Runs `alembic upgrade head`, exits | — |
| `backend` | `./backend` | FastAPI `uvicorn --reload` | 8000 |
| `worker` | `./backend` (celery entrypoint) | Celery worker | — |
| `admin` | `./admin` | Next.js dev server | 3000 |

Named volumes: `pg_data`, `redis_data`. Bind mounts for code hot-reload in dev only.

### Prod (`docker-compose.prod.yml` overrides)

- Adds `nginx` (binds 80/443) + `certbot` sidecar.
- Removes dev bind mounts; uses built images.
- Backend runs `gunicorn -k uvicorn.workers.UvicornWorker --workers 4`.
- Admin runs `next start` from a built image.
- Network isolation: only `nginx` is on a public network; everything else is on a private `gp_internal` bridge network.

### nginx routing (prod)

- `admin.gym-pass.net` → `admin:3000`
- `api.gym-pass.net` → `backend:8000`
- HTTP → HTTPS redirect everywhere.
- TLS via Let's Encrypt; see §9.

---

## 8 · `.env.example` (authoritative)

```bash
# ─── App environment ───────────────────────────────────
APP_ENV=development                   # development | production

# ─── Database ──────────────────────────────────────────
POSTGRES_USER=gympass
POSTGRES_PASSWORD=changeme
POSTGRES_DB=gympass
POSTGRES_HOST=db
POSTGRES_PORT=5432

# ─── Redis ─────────────────────────────────────────────
REDIS_URL=redis://redis:6379/0
CELERY_BROKER_URL=redis://redis:6379/1
CELERY_RESULT_BACKEND=redis://redis:6379/2

# ─── Backend JWT ───────────────────────────────────────
JWT_SECRET=changeme-long-random-string
JWT_ACCESS_TTL_SECONDS=900            # 15 min
JWT_REFRESH_TTL_SECONDS=2592000       # 30 days
JWT_SERVICE_TTL_SECONDS=300           # 5 min (admin → backend)

# ─── Member app OAuth (Google) ─────────────────────────
GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=

# ─── SMS provider ──────────────────────────────────────
SMS_PROVIDER=mock                     # mock | twilio | unifonic
SMS_API_KEY=
SMS_SENDER_ID=GymPass

# ─── Push (FCM) ────────────────────────────────────────
FCM_SERVICE_ACCOUNT_JSON=

# ─── Admin (NextAuth) ──────────────────────────────────
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=changeme-long-random-string
NEXT_PUBLIC_API_URL=http://localhost:8000

# ─── Payments (deferred) ───────────────────────────────
PAYMENT_PROVIDER=mock                 # mock | … tbd
PAYMENT_MOCK_DELAY_MS=1500

# ─── Production domains ────────────────────────────────
ADMIN_DOMAIN=admin.gym-pass.net
API_DOMAIN=api.gym-pass.net
LETSENCRYPT_EMAIL=admin@gym-pass.net
```

---

## 9 · TLS — Let's Encrypt

- `certbot` with nginx **webroot challenge**.
- Cert storage is a named volume `letsencrypt_data` shared between `nginx` and `certbot`.
- First-time issuance (manual one-liner):

```bash
docker compose run --rm certbot certonly --webroot -w /var/www/certbot \
  -d admin.gym-pass.net -d api.gym-pass.net \
  -m $LETSENCRYPT_EMAIL --agree-tos --no-eff-email
```

- Renewal runs daily via a cron container (`certbot renew --quiet`). nginx reloads cert on `SIGHUP`.

If traffic grows and justifies it, move TLS termination to Cloudflare in front of nginx and drop certbot.

---

## 10 · SOLID applied

### Single Responsibility

- **Endpoint modules** in `api/v1/` only parse, authorize, call a service, and shape response. No business rules.
- **Services** in `services/` each own exactly one use case family (auth, check-in, subscription, payout). A service doesn't call another service; it composes repositories and providers.
- **Repositories** in `repositories/` only read/write. No branching on domain rules.
- **Flutter features** mirror this: `presentation/` drives, `domain/usecases/` decides, `data/` fetches.

### Open/Closed

- **Adapters** (`providers/sms`, `providers/payments`, `providers/push`) are opened for extension, closed for modification. Adding Twilio doesn't touch existing code — just a new `TwilioSmsProvider` registered via DI and selected by `SMS_PROVIDER`.
- **Tier rules** for check-in validation are table-driven (tier ranks in DB), not switch-case in code. Adding a tier = migration + seed, no service edits.

### Liskov Substitution

- Every provider implements its `Protocol` fully — `MockPaymentProvider` and `FutureGatewayProvider` are interchangeable from `PaymentService`'s POV.
- Flutter `Repository` abstract contracts are swap-in-swap-out for test doubles.

### Interface Segregation

- Providers expose **narrow** Protocols — `SmsProvider.send_otp(phone, code) -> None` and nothing else. If push needs a richer surface, that's a separate Protocol (`PushProvider.send_notification(...)`).
- Admin's generated API client surface is **split per resource**, not one god-client, so a feature page imports only what it uses.

### Dependency Inversion

- Services depend on **abstractions** (`SmsProvider`, `PaymentProvider`, `UserRepo`), not concretions.
- Wiring happens in `main.py` lifespan + FastAPI `Depends`; tests override with fakes via `app.dependency_overrides`.
- Flutter mirrors this: usecases take interfaces, DI container (`get_it` + `injectable`) wires concrete impls at runtime; tests wire in-memory fakes.

### Enforcement

- **Backend:** import-linter rules prevent `api/` from importing `db.models`, and prevent `services/` from importing anything from `api/`.
- **Flutter:** `dart_code_metrics` + custom lint prevent `domain/` from importing anything outside `domain/` and core types.
- **Admin:** an ESLint rule forbids direct `@prisma/*` or raw DB imports (Prisma isn't in the project anyway — rule is a guardrail).

---

## 11 · Observability (v1, lean)

- **Logs:** `structlog` JSON to stdout; Docker collects. Request ID middleware propagates a correlation ID end-to-end.
- **Metrics:** deferred. Prometheus exporter stubbed but not wired.
- **Errors:** Sentry on backend + admin + mobile (three separate DSNs).
- **Audit trail:** `audit_log` table is the business-event stream. Every mutation inserts one row in-transaction with `{actor, action, entity, diff}`.

Full Grafana/Loki/Tempo stack is explicitly deferred — revisit once traffic or incident volume justifies it.

---

## 12 · Security baseline

- Argon2 for any stored secrets (admin password hashes).
- JWT secrets in `.env`; rotated by deploying new value with a grace period.
- CORS locked to the admin domain in prod.
- Rate limiting on auth endpoints (Redis, 10 req/min per IP for `/auth/otp/request`, 5 req/min per phone).
- SQL injection — no raw SQL; always SQLAlchemy.
- XSS — Next.js escapes by default; Flutter doesn't render HTML.
- CSRF — admin uses SameSite=Lax session cookie + origin check on NextAuth; service JWT is Authorization-header only (not a cookie).
- Secrets never logged. `structlog` has a filter that redacts keys matching `*token*`, `*secret*`, `*password*`.

---

## 13 · Performance notes

- Postgres indexes — see [database-schema.md](database-schema.md) §Indexes.
- N+1 prevented via `selectinload` / `joinedload` in repositories; lint rule flags `.relationship.lazy="select"` outside explicit eager loads.
- Admin list pages paginate (cursor) — no `/gyms?limit=10000`.
- Flutter list screens use `ListView.builder` + `CachedNetworkImage`.
- Redis caches:
  - `gym:{uuid}` metadata — 5 min TTL, invalidated on admin update.
  - `otp:{phone}` — 5 min TTL, single-use.
  - `rate:{route}:{key}` — sliding window counters.

---

## 14 · Cross-service contract

FastAPI is the single source of truth. Every other surface consumes it:

- **Admin:** runs `npm run generate-api` (wraps `openapi-typescript` or `orval`) against the running backend or a checked-in `openapi.json`. Generated client lives in `admin/lib/api/generated/` and is **not hand-edited**.
- **Flutter:** DTOs are hand-written (the design spec has explicit Dart contracts), but the endpoint surface is reviewed against `/api/openapi.json` in CI — a drift detector fails the build if endpoints or error codes change shape.
- **Error codes** are a shared enum — the backend defines them; the admin imports them from generated types; Flutter keeps a hand-maintained enum that's diffed against the backend's exported list in CI.

---

## 15 · Prototype preview (today's working surface)

Before backend/admin/mobile land, the repo hosts a **Vite-based React prototype** that renders the Claude Design member-app UI kit.

```
index.html               # Vite entrypoint — mounts #root
vite.config.js           # React plugin, aliases design/ for asset imports
src/
├── main.jsx             # Bootstraps <PrototypeApp/>
└── PrototypeApp.jsx     # Imports existing prototype JSX + CSS from design/ or "Gym pass Mobile App/app/"
```

This is **review-only**. It exists so stakeholders can click through all 16 screens while the real apps are being built. Once the Flutter app reaches feature parity for a screen, the prototype can stop being the reference for that screen.

---

## 16 · Refactor triggers — when to do Phase B

The backend evolved through **Phase A** (router folders by
audience: `api/v1/member/`, `api/v1/admin/`, `api/v1/partner/`).
**Phase B** is internal: move `services/`, `repositories/`,
`schemas/`, and `models/` from flat files into per-domain folders
under `app/domains/<concept>/`.

Don't do Phase B preemptively. Do it the first time **any** of
these triggers fires:

| Trigger | Threshold | Action |
|---|---|---|
| `schemas/admin.py` line count | > 600 | Split into per-concept files: `schemas/admin/users.py`, `schemas/admin/payouts.py`, etc. The schemas you can't find first. |
| Any single service file | > 400 lines OR > 20 methods | Extract into `app/domains/<concept>/service.py`. `auth_service.py` (59 awaits today) is the leading candidate. |
| Cross-domain coupling | A service imports from > 3 other services | The implicit domain is now real. Make it explicit with a folder. |
| Repo-per-table count | > 25 flat files in `repositories/` | Group by domain. |
| Adding a 4th audience or new client | — | Reorganise before adding, not after. |

When a trigger fires, the move is a `git mv`-heavy refactor with
no logic change — same shape as the Phase A audience-folder move
(commit `42b303e`). Don't combine the move with feature work in
the same PR.

### What NOT to use as a trigger

- "It feels like the right time." (it doesn't — you're avoiding a real bug)
- "We might split it into microservices someday." (we won't, see §1)
- "Our team grew." (it probably hasn't — different problem)

---

*Next: read [tasks.md](tasks.md) for the phased implementation plan.*
