# Architecture Optimization & Local-Staging Plan — GymPass

> **Master plan synthesized from five parallel `code-reviewer` sub-agents** (backend, admin, gym-partner, flutter-code, flutter-design) on 2026-05-16. Scope is intentionally narrow: **architecture, file organization, inter-service communication, local-staging preparation, performance, security, clarity, SOLID & Uncle Bob principles**. No feature work. No UI redesign. No framework swaps.
>
> **Deployment model — the durable end-state.** Three docker-compose configurations, one base + two overlays, sharing the same images and code, differing only in env vars and overlay shape:
>
> - **`docker-compose.yml`** (base) — local development; hot reload; ports exposed; `APP_ENV=development` (OTP=`1234`, payments mocked, permissive CORS).
> - **`docker-compose.staging.yml`** (overlay) — production-like staging; **the same file runs on your laptop *and* on a VM staging server**; `APP_ENV=staging`; real secrets; SMS + payments still mocked; nginx terminates TLS at 80/443. Environment-specific bits (hostnames, certs, `.env.staging`) are file-mounted and gitignored, so the compose file itself is portable.
> - **`docker-compose.prod.yml`** (overlay) — production; `APP_ENV=production`; real SMS + payment providers; identical shape to staging; differs only in env vars and provider adapters.
>
> The deliverables of this plan are: (1) those three compose files + the env templates (`.env.example`, `.env.staging.example`, `.env.prod.example`), (2) nginx vhost templates that resolve `${SERVER_NAME}` at startup so the same vhost works for `*.gym-pass.local` and `*.gym-pass.net`, (3) the architecture and codegen work in §3, §3.7, §4.6, §6.0, §6.2.
>
> The full unedited per-surface handoffs are preserved in **Appendices A–E**. The master synthesis (§0–§6) cross-references them by section.

---

## 0 · Master TL;DR

### Health by surface

| Surface | Architecture | Communication | Security | Performance | SOLID/Clarity | Local-staging ready? |
|---|---|---|---|---|---|---|
| `backend/` | **strong** — clean api→services→repos→models, audit-log everywhere, rate-limited | strong — Pydantic is the contract, OpenAPI authoritative | **strong** — HMAC admin-exchange, JWT type-checking, no SQL-injection surfaces | strong — parallel aggregates, hot-path indexes, Redis cache | acceptable; 3 fat-but-focused services | **No — `staging` env value missing in `config.py`** |
| `admin/` | **strong** — App Router with route groups, env validated by Zod, server-component default | drift risk — 40+ hand-typed DTOs duplicated in partner | strong — Web Crypto HMAC, error boundaries, no leakage | **weak spots** — sequential awaits in layout, 100-item client-side filter on /gyms | acceptable; gyms page mixes server pagination + client filter | **Nearly — 3 fixes (§1.2)** |
| `gym-partner/` | strong — same as admin, plus realtime WS bridge with backoff | drift risk — `CheckinStatus.gender_locked` exists in partner only | **2 gaps** — `/join` skips client-side MIME validation, phone normalization duplicated | strong — WS not polling, coalesced exchanges | weak — `JoinForm.tsx` 415L, `Sidebar.tsx` 442L, no error boundary | **Nearly — 4 fixes (§1.3)** |
| `mobile/lib/` | **strong** — feature-first, zero cross-module presentation imports, WS lifecycle clean | weak — no DTO codegen, `freezed` paid-for but unused | **2 gaps for production** — Android release uses debug key; no `network_security_config.xml` | strong — token-refresh coalescing, image cache, biometric vault | weak — `SettingsPage` 1718L, `PlansPage` 1238L, `ExplorePageState` watches 6 providers | **Nearly — 1 fix (§1.4)** |
| `mobile/` design | strong — `ThemeExtension<GpColors>` wired, light/dark plumbed, l10n parity perfect (727 keys, zero drift) | weak — tokens live in Dart only; need a single `tokens.json` source | n/a | n/a | **3 enforcement gaps** — 6 hex literals + 19 `Colors.white/black` + 1 hardcoded `Text(...)` string | **Yes — but cosmetic fallout in light mode** |

### Headline calls

1. **Backend is the keystone:** add `Literal[..., "staging"]` to `config.py:19` and a staging branch in `validate_production_safety()`. Once that lands, every other surface can target the new env.
2. **Admin + partner are nearly local-staging-ready.** Surgical fixes only: one hardcoded URL, one parallel-fetch, one type-drift, one missing validator call, one error-boundary. No refactors.
3. **One real communication-contract bug:** `CheckinStatus.gender_locked` exists in partner's `sdk-types.ts:29` but not in admin's `sdk.ts:18`. Backend emits it. Admin will crash on the first cross-app query that returns one (§3.3).
4. **Mobile signing and `network_security_config.xml` aren't Phase-A blockers.** During staging you install on devices via `flutter run` or USB sideload, so the debug-signed APK works. Both become Phase-C production items (§2.6, §2.7) — fix before serving the APK over the public staging or prod nginx vhost. The only mobile blocker for Phase A is splitting `AppEnv.isDev` so the app stops mock-OTPing against the staging backend.
5. **Design tokens want one source of truth (JSON).** Five surfaces consume them today (Tailwind ×2, CSS, Flutter, backend tier enum). Drift will happen — preempt with `design/project/tokens.json` (§3.5).
6. **The architecture work lives in §3 + §6.2 (Phase B), not Phase A.** Phase A is the local-staging cutover (mostly bug fixes). The reorganization, codegen, packages, dependency rules — that's Phase B. New sections **§3.7 (Module dependency rules), §4.6 (Coding conventions), §6.0 (Target architecture)** below describe what the architecture *is* and *how it's enforced*, so the reorg has a target.

---

## 1 · Cross-cutting local-staging blockers (must land before `APP_ENV=staging` runs cleanly on your laptop)

The goal: a `docker compose -f docker-compose.yml -f docker-compose.staging.yml up` profile on your machine that mirrors a production stack — real secrets, tight CORS, mock SMS + payments, no debug, no auto-seeding — so production-only code paths get exercised weeks before any deploy.

### 1.1 Backend — add the `staging` env value

**Files:** `backend/app/config.py:19`, `backend/app/config.py:127` (`validate_production_safety`)

```python
app_env: Literal["development", "staging", "production"] = "development"
```

`validate_production_safety()` today only branches on `is_dev`. Add an explicit `staging` branch (Appendix A §7):

- Requires real `JWT_SECRET` (≥32 chars, not the dev sentinel)
- Requires real `ADMIN_EXCHANGE_SECRET`
- Requires real `POSTGRES_PASSWORD`
- **Relaxes** `ADMIN_BOOTSTRAP_PASSWORD` length (operator may keep dev creds)
- Keeps SMS + payment providers on `"mock"`
- Tightens CORS to the configured admin/partner origins (no wildcard) — these will be `https://admin.gym-pass.local` / `https://partner.gym-pass.local` in your local staging setup
- Keeps `debug=False` and the production error envelope

Also (Appendix A §4): replace `print(...)` in `app/providers/sms/mock_sms.py:25` with `log.info("mock_sms", phone=..., code=...)` so staging logs route through structlog.

### 1.2 Admin — 3 surgical fixes

1. **`src/app/(dashboard)/partner-applications/[id]/page.tsx:17`** — replace `process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://api.gym-pass.net"` with `env.API_BASE_URL` from `lib/env.ts`. The hardcoded fallback bypasses Zod validation.
2. **`src/app/(dashboard)/layout.tsx:25–31`** — wrap the two sequential `AdminSDK.ticketStats()` + `AdminSDK.listTickets()` in `Promise.all()`.
3. **`src/app/(dashboard)/gyms/page.tsx:47–80`** — currently fetches 100 gyms then filters client-side. Push category/tier/audience filters into the SDK call (backend already supports them) or document the 100-row ceiling.

### 1.3 Gym partner — 4 surgical fixes

1. **`src/lib/sdk-types.ts:29`** — `CheckinStatus` drift (`gender_locked`). Resolution decided in §3.3.
2. **`src/app/join/JoinForm.tsx:39–48, 51–65, 67–85`** — call the existing `validateImageFile()` from `lib/upload.ts` before `uploadFile()`. Fail fast with a localized error.
3. **`src/app/join/JoinForm.tsx:99` & login page** — phone normalization duplicated with subtly different logic. Extract to `lib/phone.ts` (`normalizeJordanianPhone(input: string): string`).
4. **`src/components/Sidebar.tsx`** — wrap gym-data-dependent sections in an error boundary. Malformed `openingHours` payload currently crashes the dashboard shell.

### 1.4 Flutter — 1 staging blocker (signing + network config moved to §2)

The signing config (`build.gradle.kts:59`) and the missing `network_security_config.xml` are quality issues for any APK you put in front of a real user — but since you are running staging locally and `flutter run`/installing via USB during dev, neither blocks the local-staging cutover. They move to §2 production blockers.

What *is* a staging blocker: **`mobile/lib/core/config/env.dart` — split `AppEnv.isDev` into `useMockAuth` + `isProduction`** (Appendix D §4). Without it, the mobile app keeps using mock OTP (`1234`) even when pointed at the local staging backend, defeating the whole point of staging.

Concretely:

```dart
class AppEnv {
  static const _env = String.fromEnvironment('APP_ENV', defaultValue: 'development');
  bool get isProduction => _env == 'production';
  bool get useMockAuth  => _env == 'development';   // staging + production both use real OTP
}
```

### 1.5 Flutter design — 3 token-discipline blockers (cosmetic; visible in light mode)

Staging is the first time light mode will be exercised against real backends:

1. **6 hex-color literals** — `tier_name_label.dart:116, 161–162`, `gym_detail_page.dart:744–745`, `explore_page.dart:1199`. Route through `GP.*` / `GPTier.*` tokens.
2. **1 hardcoded `Text('Term visits maxed out')`** — `checkin_page.dart:652`. Add to ARB. Breaks AR.
3. **19 `Colors.white`/`Colors.black`** usages in foreground/gradient contexts; several break legibility in light mode (Appendix E §6).

---

## 2 · Production blockers (deferred — addressed only when you decide to deploy somewhere)

These are real quality issues, but none of them block the local-staging cutover in §1. Reassess when you pick a production deployment target.

| # | Surface | Item | Source |
|---|---|---|---|
| 2.1 | Backend | `validate_production_safety()` must enforce non-empty CORS origins and require `ADMIN_DOMAIN` / `PARTNER_DOMAIN` in production. | Appendix A §2.3 |
| 2.2 | Backend | `admin_exchange_max_skew_seconds` hardcoded to 60s; make configurable. | Appendix A §3 |
| 2.3 | Backend | Real SMS + payment providers behind existing `providers/sms/` and `providers/payments/` interfaces. | Appendix A §3 |
| 2.4 | Admin | Boot-time `exchangeAdminToken()` smoke test in `instrumentation.ts` to catch `ADMIN_EXCHANGE_SECRET` mismatch. | Appendix B §3 |
| 2.5 | Admin | `revalidate` / `cache()` hints on dashboard metrics. | Appendix B §3 |
| 2.6 | Mobile | **Generate Android release keystore;** assign to `signingConfigs.release` in `build.gradle.kts:59`. Until done, do not distribute the APK to anyone. | Appendix D §2 |
| 2.7 | Mobile | **Add `res/xml/network_security_config.xml`;** scope cleartext to `10.0.2.2`/`localhost` only; staging + prod inherit the secure default. | Appendix D §2 |
| 2.8 | Mobile | `proguard-rules.pro` with explicit `-keep` rules for Dio, Riverpod, json libraries. | Appendix D §3 |
| 2.9 | Mobile | iOS — switch from `"iPhone Developer"` (ad-hoc) to a real distribution cert. | Appendix D §3 |
| 2.10 | Mobile | Migrate hand-rolled `fromJson` to `freezed` + `json_serializable` once `packages/api-client-dart` lands. | Appendix D §3 |
| 2.11 | Design | `GPSpace.*` constants exist but unused — 70+ inline spacing literals. | Appendix E §3.1 |
| 2.12 | Design | Replace `EdgeInsets.only(left:, right:)` with `EdgeInsetsDirectional` where it should mirror in RTL. | Appendix E §3.2 |
| 2.13 | Infra | Author `docker-compose.prod.yml` by copy-from-staging (§6.3 step 1); keep nginx vhosts identical; only env vars + provider adapters differ. | §6.3 |
| 2.14 | Infra | Pick the prod deploy target (VM, managed PaaS, k8s); write a one-page runbook. Out of architectural scope here. | §6.3 step 10 |

---

## 3 · Inter-service communication contract — unified plan

### 3.1 Single source of truth: backend Pydantic schemas → OpenAPI → codegen

The handoffs confirm with hard evidence:

- Admin has 40+ hand-typed DTOs in `src/lib/sdk.ts` (Appendix B §5).
- Partner has the same shape in `src/lib/sdk-types.ts`; one type has already drifted (Appendix C §5).
- Mobile parses JSON manually with `as String` casts, never using the `freezed` toolchain already in `pubspec.yaml` (Appendix D §3).

Generate `packages/api-client-ts` (orval) and `packages/api-client-dart` (openapi-generator dart-dio) from the backend OpenAPI schema. Commit the generated code; don't regenerate per local build.

What stays app-specific (Appendix B §5): admin's `action-result.ts` wrapper, action-Zod schemas, `AdminSDK` orchestrators composing multiple endpoints.

What moves to the shared client (Appendix C §5): HMAC envelope signing, `SESSION_EXPIRED_CODES` redirect logic, `exchangeInFlight` coalescing map, `ApiError` class, the `api()` wrapper.

### 3.2 Shared UI primitives — `packages/ui`

`PendingButton.tsx` is mirrored byte-for-byte with a comment that says so. Migration order:

1. `PendingButton.tsx` — already an explicit duplicate
2. `StatusPill.tsx`, `LocaleToggle.tsx`, `ThemeToggle.tsx`, `GymLoader.tsx`
3. `AmenitiesPicker.tsx` — pick the partner-side version as canonical
4. Tailwind preset (one file shared by both)

### 3.3 Decide on `CheckinStatus.gender_locked` drift

Real bug. Backend emits it. Partner displays it. Admin's enum doesn't include it.

**Resolution:** Add `gender_locked` to admin's `CheckinStatus` + `TONE` map now. Codegen (§3.1) makes this self-resolving later.

### 3.4 Realtime — keep it where it is

Partner uses `RealtimeBridge.tsx` with exponential backoff (Appendix C §1). Mobile has `realtimeClientProvider` (Appendix D §5). Backend publishes via `realtime/`. Don't refactor.

### 3.5 Design tokens — single JSON source

Today the same color / spacing / radii / typography values live in **four places**: `design/project/colors_and_type.css`, `admin/{globals.css,tailwind.config.ts}`, `gym-partner/{globals.css,tailwind.config.ts}`, `mobile/lib/core/theme/gp_tokens.dart`.

Extract `design/project/tokens.json`. A build script generates the Dart file on `flutter pub get`; same JSON feeds a Tailwind preset shared by admin + partner.

```json
{
  "colors": {
    "lime": "#EAB308", "ink": "#0A0B0A", "paper": "#F5F3EC",
    "tier": { "silver": { "dark": "...", "light": "..." }, "gold": {...}, ... }
  },
  "spacing": { "xs": 4, "sm": 8, "md": 12, "lg": 16, "xl": 20, "xl2": 24 },
  "radii":   { "sm": 8, "md": 12, "lg": 16, "xl": 20, "pill": 100 },
  "typography": { "fonts": ["Cairo", "Archivo", "Inter"], "scales": {...} }
}
```

### 3.6 Error envelope

Backend returns `{"error": {"code": "...", "message": "..."}}` (Appendix A §1). Admin, partner, mobile all consume it correctly. Don't change it. Canonical error codes (`AUTH_OTP_INVALID`, `CHECKIN_TIER_LOCKED`, `SESSION_EXPIRED`, …) are the contract — never rename.

### 3.7 Module dependency rules — what can import what

Architecture is dependency *direction*, not just folder layout. These rules apply after Phase B and are enforced by lint tooling in CI.

**TS workspace (admin + partner + website + packages):**

```
apps/admin     apps/partner     apps/website
     │              │                │
     └──────┬───────┴───────┬────────┘
            │               │
            ▼               ▼
      packages/ui    packages/auth-client
            │               │
            ▼               ▼
      packages/tokens   packages/api-client-ts
                            │
                            ▼
                       packages/tokens   (leaf)
```

Rules:

- `packages/tokens` is a leaf. Imports nothing internal.
- `packages/api-client-ts` depends only on `zod` + a fetch wrapper. **No React. No UI.**
- `packages/auth-client` depends on `api-client-ts`. **No UI.**
- `packages/ui` depends only on `tokens` + React + Tailwind. **May not import `api-client-ts`** — UI is presentational.
- `apps/*` may depend on any `packages/*`.
- `apps/admin`, `apps/partner`, `apps/website` **must not cross-import each other.** Anything they share moves to `packages/`.

Enforcement: `packages/eslint-config` ships an `eslint-plugin-import/no-restricted-paths` rule. CI fails on violations.

**Backend layers (`apps/backend/app/`):**

```
api/  ───►  services/  ───►  repositories/  ───►  db/models/
                                                       ▲
schemas/, providers/, realtime/, workers/, core/, utils/  ─ siblings
```

Strict direction:

- `api/` may import `services/`, `schemas/`, `core/`, `providers/` (interfaces only).
- `services/` may import `repositories/`, `schemas/`, `providers/`, `core/`, `utils/`. **May not import `api/`.**
- `repositories/` may import `db/models/`, `db/session`, `core/exceptions`, `utils/`. **No business logic.**
- `db/models/` may import `db/base`, `db/types`, `db/enums`, `utils/`. **No business logic.**
- `core/` is leaf — no internal app deps.
- `workers/` (Celery) may import like `api/` does.

Enforcement: `.importlinter` contract:

```ini
[importlinter:contract:layers]
type = layers
layers =
    app.api
    app.services
    app.repositories
    app.db.models
```

CI runs `lint-imports` on every PR.

**Mobile feature modules (`apps/mobile/lib/`):**

```
features/<x>/presentation/  ───►  features/<x>/data/
                                          │
                                          ▼
core/api/, core/realtime/, core/storage/, core/router/, core/theme/, shared/
```

Rules:

- `features/<x>/*` **must not import** `features/<y>/*`. Cross-feature flow goes through `core/orchestration/` or via the router.
- `features/<x>/presentation/` may import `features/<x>/data/`. Never reverse.
- `core/*` may not import `features/*`.
- `shared/` widgets may not import `features/*`.

Enforcement: `dart_code_metrics` with a custom `avoid-cross-feature-imports` rule + CODEOWNERS on `lib/core/`.

**Cross-app contract.** The *only* legitimate cross-app communication is **over the wire**:

- Backend → TS apps: HTTPS via `packages/api-client-ts`.
- Backend → Mobile: HTTPS via `packages/api-client-dart`.
- Backend ↔ all clients: WebSocket at `/api/v1/realtime/ws`.

No app imports another app's source. No app reads another app's DB tables.

---

## 4 · Per-surface staging-prep checklists (consolidated)

### 4.1 Backend (`apps/backend/`)

- [ ] Add `staging` to `Literal` in `config.py:19`.
- [ ] Add staging branch to `validate_production_safety()` (Appendix A §7).
- [ ] Verify real `JWT_SECRET`, `ADMIN_EXCHANGE_SECRET`, `POSTGRES_PASSWORD` in `.env.staging` (≥32 chars, no `changeme-*`).
- [ ] Spot-check CORS: only the configured admin/partner origins echoed back.
- [ ] Replace `print()` in `mock_sms.py:25` with `log.info(...)`.
- [ ] Smoke-test admin NextAuth → service-JWT exchange with the real secret.
- [ ] Trigger one mutation per role; verify `audit_log` rows.

### 4.2 Admin (`apps/admin/`)

- [ ] Replace inline `?? "https://api.gym-pass.net"` with `env.API_BASE_URL` in `partner-applications/[id]/page.tsx:17`.
- [ ] Wrap `(dashboard)/layout.tsx:25–31` tickets calls in `Promise.all()`.
- [ ] Decide on gyms-page server-side filter or document 100-row ceiling.
- [ ] Rotate `NEXTAUTH_SECRET` to a 32+ char random value.
- [ ] Confirm `NEXTAUTH_URL` is `https://` and matches the local-staging cert hostname.
- [ ] `npm run build` clean (Zod env validation fails fast on missing vars).

### 4.3 Gym partner (`apps/partner/`)

- [ ] Add `gender_locked` to admin's `CheckinStatus` (cross-surface fix; lives in the admin PR).
- [ ] Call `validateImageFile()` from `JoinForm.tsx` before each upload.
- [ ] Extract `normalizeJordanianPhone()` to `lib/phone.ts`; use in both join + login.
- [ ] Wrap gym-data-dependent sections of `Sidebar.tsx` in an error boundary.
- [ ] Remove the `console.error` in `(dashboard)/error.tsx` or gate to dev.
- [ ] `npm run build` clean.
- [ ] Render `/join` in AR (RTL) on staging; verify form labels/placeholders flip.

### 4.4 Flutter (`apps/mobile/`)

- [ ] Split `AppEnv.isDev` into `useMockAuth` + `isProduction` (§1.4).
- [ ] Build APK with `--dart-define=API_BASE_URL=https://10.0.2.2:8443 --dart-define=APP_ENV=staging` (emulator) or `--dart-define=API_BASE_URL=https://<lan-ip>:8443` (real device).
- [ ] Test the realtime WS over `wss://` to local staging.
- [ ] Token-refresh stress test on a throttled connection.
- [ ] Locale toggle test on `/settings` — no widget orphans.

### 4.5 Flutter design

- [ ] Replace the 6 hex literals (Appendix E §6) with `GP.*` / `GPTier.*` tokens.
- [ ] Move `'Term visits maxed out'` to ARB (`checkin_page.dart:652`).
- [ ] Convert the worst `Colors.white`/`Colors.black` usages (Appendix E §6, items 2–3, 5) to `context.gp.bg/bg2/bg3`.
- [ ] Verify light mode on the gym detail photo gradient + gym list sheet placeholder.

### 4.6 Coding conventions — codify what's already there

These conventions are mostly observed today; this section freezes them as policy so new code lands consistent.

**Error envelope.** All backend errors return `{"error": {"code": "SCREAMING_SNAKE", "message": "Human prose"}}`. Backend: throw `AppError("CODE", "message")` from `core/exceptions.py`. TS clients: `ApiError` class; `error.code` drives i18n key lookup, **never** `error.message`. Dart: `ApiException`; switch on `.code`. **Never rename a code.** Codes are the contract; additive only.

**Logging.**
- Backend: `structlog` only. Every event includes `event`, `request_id`, `user_id` (when authenticated), `service`, `version`. Never `print()`, never `logging.getLogger()` raw.
- Next apps: `console.error` only inside `error.tsx`. Elsewhere use Sentry (Phase C) or a no-op stub.
- Mobile: `dart:developer.log()` for dev. Production routes through Sentry breadcrumbs (Phase C). Never `print()` in release.

**Naming.**
- Backend: `*Service` = business logic; `*Repository` = data access; `*Provider` = external adapter; `*Schema` = Pydantic DTO; `*Model` = SQLAlchemy entity.
- TS: hooks `useXxx`; server actions `xxxAction`; components named after their role (`UserDetailPanel`, not `Panel`).
- Flutter: pages `XxxPage`; widgets after role (`TierCard`, not `Card`); Riverpod providers `xxxProvider`.

**File naming.** Python `snake_case.py`. TS `kebab-case.ts` for utilities, `PascalCase.tsx` for components. Dart `snake_case.dart` everywhere.

**Comments.** Default: none. Write a comment only for the non-obvious *why* — a hidden constraint, a subtle invariant, a workaround. Never explain *what* the code does. Never include "added for X" or "TODO when Y" — that's commit / PR territory.

**Function size.** Soft cap 100 lines, hard cap 200. `build()` methods and React component bodies above 100 lines must extract sub-widgets / sub-components in the same PR.

**Magic strings.** Tier names, role names, status codes — never inline. Import from a constants module or generated client.

Enforceable: ESLint + Pylint + dart_code_metrics ship in the workspace.

---

## 5 · Refactor backlog — folded into Phase B by surface

Earlier I listed these as "deferred." Wrong framing: most of them refactor *naturally* when the file moves into `packages/` or gets a typed DTO. They belong in Phase B, not parked indefinitely. The `Phase` column is the canonical assignment.

| # | Where | What's wrong | Principle | Phase | How it lands |
|---|---|---|---|---|---|
| 1 | `mobile/lib/features/settings/presentation/settings_page.dart` (1718L) | Inline `_section()` builders | SRP, OCP | **B** | Split each section into a `ConsumerWidget` while migrating to codegen DTOs |
| 2 | `mobile/lib/features/subscription/presentation/plans_page.dart` (1238L) + `my_subscription_page.dart` (967L) | Duplicate inline tier cards / pricing tables | DRY | **B** | Extract `_TierCard`, `_PricingToggle`, `_UpgradePath` to `subscription/presentation/widgets/` while typed DTOs land |
| 3 | `gym-partner/src/app/join/JoinForm.tsx` (415L) | File-validation + upload + form + error UI in one component | SRP | **B** | `usePhotoUpload()` hook extracted when `packages/ui` lands (upload helpers move to `packages/auth-client` or a shared utility) |
| 4 | `gym-partner/src/components/Sidebar.tsx` (442L) | No error boundary; opening-hours formatter inline | SRP + fault isolation | **A** | Error boundary added in §1.3.4; opening-hours formatter extracted in **B** when moving to `packages/ui` |
| 5 | `mobile/lib/features/gyms/presentation/explore_page.dart` ExplorePageState | Top-level state watches 6 providers | Rebuild discipline | **B** | Refactor when migrating typed DTOs; split chrome/list/map/filter into `ConsumerWidget`s |
| 6 | `admin/src/app/(dashboard)/gyms/page.tsx:47–80` | Server-paginated 100 then client-filter | Levels-of-abstraction | **A** | Already in §1.2.3 — push filters to SDK call |
| 7 | `backend/app/services/subscription_service.py:44–200` | `SubscriptionService` owns full purchase flow | SRP | **C** | Truly orthogonal — split when renewals/upgrades land |
| 8 | `backend/app/services/admin_user_service.py:46–118` | `update()` bundles 4 concerns | SRP | **C** | Split when a 4th admin-policy rule lands |
| 9 | `gym-partner/src/components/AmenitiesPicker.tsx` (218L) | Multiple concerns in one client component | SRP | **B** | Extract `useAmenitiesState()` when moving to `packages/ui` (canonical version chosen here) |
| 10 | `mobile/.../tier_name_label.dart:161–162` | Platinum gradient hex literals duplicated | Token discipline | **A** | Already in §1.5.1 — route through `GPTier.platinum.{color, colorOnLight}` |

**Cross-surface pattern flagged by every reviewer:** large `build()` / page-component methods that mix data orchestration, layout, and presentation. The fix is not a framework swap — it's discipline. §4.6 codifies the rule (`build()` < 100 lines; extract sub-trees into named components in the same PR).

---

## 6 · Execution order

### 6.0 Target architecture — what the tree looks like after Phase B

This is the end-state. §6.1 and §6.2 describe how to get there.

```
gym-pass-pro/                              # pnpm workspace + turborepo
│
├── apps/
│   ├── backend/                           # FastAPI · uv · Alembic · Celery
│   │   ├── app/
│   │   │   ├── api/v1/{member,admin,partner,public}/   # HTTP boundary, thin
│   │   │   ├── services/                  # business logic + orchestration
│   │   │   ├── repositories/              # data access only — no business rules
│   │   │   ├── db/{models,session,base,enums,types}/
│   │   │   ├── schemas/                   # Pydantic DTOs — the contract
│   │   │   ├── providers/{sms,payments,push,oauth}/   # adapters behind interfaces
│   │   │   ├── core/                      # exceptions, security, redis, middleware (leaf)
│   │   │   ├── realtime/                  # WebSocket fan-out
│   │   │   ├── workers/                   # Celery tasks
│   │   │   └── utils/                     # pure functions, no I/O
│   │   ├── alembic/
│   │   ├── tests/{unit,api,contract,integration}/
│   │   └── .importlinter                  # enforced layer rules (§3.7)
│   │
│   ├── admin/                             # Next.js App Router
│   ├── partner/                           # Next.js App Router · /join · realtime
│   ├── website/                           # Next.js · marketing
│   │
│   └── mobile/                            # Flutter · feature-first
│       └── lib/
│           ├── core/{api,realtime,router,theme,storage,orchestration}/
│           ├── features/<x>/{data,presentation}/        # 13 feature modules
│           ├── shared/                    # cross-cutting widgets
│           └── l10n/                      # AR + EN
│
├── packages/
│   ├── tokens/                            # design/tokens.json → tailwind preset + gp_tokens.dart
│   ├── api-client-ts/                     # CODEGEN: orval from /api/openapi.json
│   ├── api-client-dart/                   # CODEGEN: openapi-generator dart-dio
│   ├── auth-client/                       # NextAuth ↔ service-JWT, coalescing, session-expired redirect
│   ├── ui/                                # shadcn-style primitives for admin + partner
│   └── eslint-config/                     # shared lint + dependency rules from §3.7
│
├── infra/
│   ├── compose/
│   │   ├── docker-compose.yml             # dev profile
│   │   └── docker-compose.staging.yml     # local staging overlay — mkcert TLS, prod-like
│   ├── nginx/                             # vhosts for local staging hosts
│   ├── tls/                               # mkcert-generated local CA + certs (gitignored)
│   └── scripts/                           # mkcert.sh, smoke.sh, codegen.sh
│
├── design/                                # read-only design bundle
├── docs/                                  # engineering docs
│
└── .github/workflows/                     # ci · codegen · lint · test (no auto-deploy)
```

Annotations:

- **`packages/` is where duplication goes to die.** Five surfaces consume design tokens; one package owns them.
- **Codegen folders are not hand-edited.** Their source is `apps/backend/app/schemas/` + the OpenAPI emission. They commit to git so app builds don't depend on a network call to the backend, but they regenerate in CI when backend schemas change.
- **No app reads another app's source.** Cross-app contract is the wire (HTTPS + WS).
- **No app reads the database except backend.** Admin doesn't touch Postgres directly.
- **`infra/` is *local* tooling.** Compose files, nginx vhost templates for `*.gym-pass.local`, mkcert-generated certs. No remote-deploy assumptions baked in. When you later choose a production target, that target gets its own folder.

### 6.1 Phase A — Portable staging compose + nginx reverse proxy (1–2 evenings, NO architecture changes)

Goal: ship a `docker-compose.staging.yml` overlay that runs the same way on your laptop and on a VM, plus the per-surface fixes from §1 so `APP_ENV=staging` actually works end-to-end.

The current repo already has `docker-compose.prod.yml` doing roughly the right shape (target: `runner`, ports hidden, env-file driven, nginx mounting Cloudflare Origin Cert). It is mislabeled — today it's effectively a staging-grade overlay because SMS + payments are mocked. The cleanest path is to **rename it to `docker-compose.staging.yml`** and create a separate, slimmer `docker-compose.prod.yml` in Phase C that flips just the env vars and provider adapters.

Order matters; each step has clean acceptance.

**Step 1 — Backend `staging` env value + safety branch** (§1.1). Unlocks every downstream step. Without it, `APP_ENV=staging` is rejected at boot.

**Step 2 — Rename + retune the overlay.**

- `git mv docker-compose.prod.yml docker-compose.staging.yml`
- Change `env_file: .env.prod` → `env_file: .env.staging` on every service.
- In the staging overlay, set `APP_ENV=staging` explicitly.
- Replace hardcoded hostnames in nginx vhost templates with `${API_DOMAIN}` / `${ADMIN_DOMAIN}` / `${PARTNER_DOMAIN}` / `${WEBSITE_DOMAIN}` and resolve them at container start via `envsubst < /etc/nginx/templates/*.template > /etc/nginx/conf.d/*.conf` (nginx official image supports this natively via `NGINX_ENVSUBST_TEMPLATE_DIR`).
- Cert mount stays at `./nginx/certs/`. The file is gitignored; the operator drops in the right cert per environment (mkcert on laptop, Cloudflare Origin Cert / Let's Encrypt on VM).

**Step 3 — Two `.env.staging` profiles.** Same template, different values:

- *Laptop.* Hostnames `api.gym-pass.local` etc. (added to `/etc/hosts`); cert from `mkcert "*.gym-pass.local"`. mkcert installs its own CA into the system trust store, so browsers and the Android emulator (after installing the root CA) accept it.
- *VM staging server.* Hostnames `staging-api.gym-pass.net` etc.; cert is a real Cloudflare Origin Cert or Let's Encrypt cert at the same `./nginx/certs/` path. Zero compose-file changes.

Provide `.env.staging.example` in git as the canonical template. The actual `.env.staging` is gitignored.

**Step 4 — Surgical per-surface fixes** (parallelisable):

- Admin 3 fixes (§1.2).
- Partner 4 fixes (§1.3).
- Flutter `AppEnv.isDev` split (§1.4).
- Design 3 token fixes (§1.5).
- Backend cleanup: replace the `print()` in `mock_sms.py:25` (§1.1).

**Step 5 — Makefile shortcuts.** Replace the current `prod-up`/`prod-down` recipes:

```makefile
staging-up:
	docker compose -f docker-compose.yml -f docker-compose.staging.yml --env-file .env.staging up -d --build

staging-down:
	docker compose -f docker-compose.yml -f docker-compose.staging.yml --env-file .env.staging down

staging-logs:
	docker compose -f docker-compose.yml -f docker-compose.staging.yml --env-file .env.staging logs -f
```

**Step 6 — Smoke-test target.** Move the smoke loop from `scripts/deploy.sh` into a thin `scripts/smoke.sh` that takes the base URL as an argument. Same script runs against `https://api.gym-pass.local` and `https://staging-api.gym-pass.net`.

**Step 7 — Mobile dart-defines for staging.** Document two recipes in `mobile/README.md`:

```bash
# Against laptop staging stack (emulator)
flutter run --dart-define=API_BASE_URL=https://api.gym-pass.local --dart-define=APP_ENV=staging
# Against laptop staging stack (real device on same Wi-Fi)
flutter run --dart-define=API_BASE_URL=https://<laptop-lan-ip>:443 --dart-define=APP_ENV=staging
# Against VM staging server
flutter run --dart-define=API_BASE_URL=https://staging-api.gym-pass.net --dart-define=APP_ENV=staging
```

Only the URL changes; the app is identical.

**Acceptance criteria for Phase A:**

- `make staging-up` runs cleanly on the laptop with `mkcert`-issued certs in `nginx/certs/`.
- The same `docker-compose.yml + docker-compose.staging.yml` brings the stack up on a fresh VM with a real cert dropped into the same path — *no compose changes*.
- All five per-surface checklists in §4 are green.
- The mobile app, run with the staging dart-define, completes a real OTP cycle (mock-SMS logged through structlog) and a check-in.
- nginx serves `https://${ADMIN_DOMAIN}` to the admin container, `https://${PARTNER_DOMAIN}` to the partner container, `https://${API_DOMAIN}` to the backend container, `https://${WEBSITE_DOMAIN}` to the marketing container. WS upgrades pass through.

### 6.2 Phase B — Structure, contract, and refactor reorganization (1–2 weeks, interleave with feature work)

1. **Delete root cruft** — `dump.err`, `gympass-data.sql`, vestigial Vite host (root `package.json` + `vite.config.js` + `index.html`), legacy `Gym pass Mobile App/`.
2. **Bootstrap `.github/workflows/ci.yml`** — lint+test for all four code surfaces. **No deploy steps.** Just guardrails.
3. **Convert root to pnpm workspace + Turborepo.** Top-level `package.json` becomes the workspace root.
4. **Move folders to `apps/` + `packages/` + `infra/`** per §6.0. One PR, mechanical.
5. **Extract `design/project/tokens.json`** (§3.5). Generate Tailwind preset + `gp_tokens.dart`.
6. **Generate `packages/api-client-ts`** (orval) from `/api/openapi.json`. Migrate admin + partner SDKs. Folds in row #6 of §5.
7. **Extract `packages/ui`** starting with `PendingButton.tsx`. Migration order in §3.2. Folds in rows #3, #9 of §5 (extract `usePhotoUpload`, `useAmenitiesState`).
8. **Extract `packages/auth-client`** — HMAC envelope, exchange coalescing, `SESSION_EXPIRED` redirect.
9. **Add `gender_locked` to admin `CheckinStatus`** (or wait for codegen to resolve it — §3.3).
10. **Generate `packages/api-client-dart`** (openapi-generator dart-dio). Migrate mobile DTOs to `freezed`. Folds in rows #1, #2, #5 of §5 (the large mobile screens get refactored *during* the codegen migration — touching every screen anyway).
11. **Wire dependency-rule enforcement** (§3.7): `eslint-plugin-import/no-restricted-paths` in `packages/eslint-config`, `.importlinter` for backend, `dart_code_metrics` for mobile. CI fails on violations.
12. **Backend contract tests** in `apps/backend/tests/contract/` using schemathesis. Locks down the OpenAPI surface feeding the generated clients.

### 6.3 Phase C — Production compose + provider integration (when you pick a deploy target)

Phase A delivered a staging stack identical in shape to what production will look like. Phase C is the smaller delta: copy the overlay, flip the env, wire real providers, harden a few things.

1. **Create `docker-compose.prod.yml`** by copy-and-trim from `docker-compose.staging.yml`:
   - `env_file: .env.prod` (gitignored; `.env.prod.example` template committed).
   - `APP_ENV=production` baked in.
   - `restart: always` (vs `unless-stopped` on staging).
   - Backend command flips to the production gunicorn config (workers tuned, no `--reload`, no debug).
   - Stronger healthcheck thresholds (faster fail, faster rollback).
   - Identical nginx vhost templates — only the cert and `${SERVER_NAME}` env vars change.
2. **Production `validate_production_safety()` tightening** (§2.1, §2.2) — non-empty CORS, required `ADMIN_DOMAIN` / `PARTNER_DOMAIN`, configurable JWT skew.
3. **Real SMS provider** behind `providers/sms/`. Provider chosen at the launch decision (Twilio / Unifonic / local Jordan provider — CLAUDE.md §15).
4. **Real payment gateway** behind `providers/payments/`. Stripe ruled out; gateway chosen at the launch decision.
5. **Admin boot-time exchange smoke test + cache hints** (§2.4, §2.5).
6. **Mobile production-quality:** release keystore, `network_security_config.xml`, ProGuard rules, iOS distribution cert (§2.6–§2.9). If you serve the APK off the prod nginx vhost (`https://<website-domain>/downloads/gympass.apk`), do *not* publish a debug-signed APK there — see §2.6.
7. **Sentry** in backend + 2 Next apps + mobile. One DSN per env (development / staging / production).
8. **Push notifications** decision — FCM/APNs direct vs OneSignal.
9. **Backend §5 rows #7, #8** (subscription_service / admin_user_service splits) — only when feature pressure arrives.
10. **Pick the prod deploy target** (VM, managed PaaS, k8s — out of scope here) and write the runbook. Because Phase A made staging the daily-loop env, flipping to production discovers zero new code paths — only env values and provider adapters change.

**Acceptance criteria for Phase C:**

- `docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file .env.prod up -d` brings up an identical stack with real providers.
- A single environment switch (`make staging-up` vs `make prod-up`) is the only difference between the two environments at the operator level.
- The same nginx vhost templates serve both — only `${SERVER_NAME}` and the mounted cert differ.

---

## 7 · Pointers

- High-level topology: [architecture.md](architecture.md)
- Feature task tracker: [tasks.md](tasks.md)
- API contract conventions: [api-standards.md](api-standards.md)
- Git flow: [git-instructions.md](git-instructions.md)
- Known gotchas: [gotchas.md](gotchas.md)

> Note: [deploy.md](deploy.md) documents the previous single-overlay VM workflow. This plan replaces it with the three-compose model in the front-matter (`docker-compose.yml` / `docker-compose.staging.yml` / `docker-compose.prod.yml`). Rewrite or archive `deploy.md` during Phase A — when the staging overlay lands, the doc should describe `make staging-up` on laptop and on VM, with the env-file + cert mount the only delta between them.

---

# Appendix A — Backend Handoff (full text)

> Reviewer scope: `backend/`. Skill: `code-reviewer`. Verbatim handoff, edited only for heading depth.

### A.1 What's already solid (do not churn)
- **Comprehensive error envelope** (`core/exceptions.py`) — all domain errors use `AppError` with canonical error codes, no ORM objects leak to clients.
- **Authentication & authorization** — `current_user`, `current_admin`, `current_gym_owner`; JWT type checking prevents token type confusion.
- **Request validation** — Pydantic v2 `model_validate()`; uploads validate MIME via `sniff_image()`; size bounds enforced.
- **Pagination & list bounds** — admin/member endpoints enforce `pageSize` max 100.
- **Rate limiting** — `RateLimiter` applied to auth exchange (120/5min), OTP, partner application submit (3/hr), upload (30/hr), checkin (1/30min per gym), keyed by IP.
- **Audit logging** — every mutation writes to `audit_log` in the same transaction.
- **Performance** — `AdminMetricsService` parallelises aggregates via `asyncio.gather`; Redis cache 10s TTL on metrics.
- **DB indexes** — hot paths covered (`checkins` by user/gym, `payments` by subscription, `audit_log` by entity, `subscriptions` by status, `users` by role/email/phone/referral).
- **File upload** — orphan-file guard with `try/finally`; opaque UUID filenames.
- **SQL safety** — only one `text(...)` (advisory lock, parameterised); everything else ORM.
- **Architecture** — no circular imports, services consume repos only, OpenAPI is authoritative.
- **Async hygiene** — blocking argon2 offloaded to thread executor; no `time.sleep` / `requests` in async paths.

### A.2 Critical findings (staging blockers)
- **Missing `staging` env value** — `config.py:19` is `Literal["development", "production"]`. **Fix:** add `staging`, carve out branch in `validate_production_safety()`.
- **CORS in production includes `partner_domain`** — confirm `partner.gym-pass.net` (or `.local` in local staging) is the correct origin.
- **`validate_production_safety()` doesn't enforce non-empty CORS** — operator forgetting `ADMIN_DOMAIN` / `PARTNER_DOMAIN` gets silent hardcoded defaults.

### A.3 Important findings (production blockers)
- `admin_exchange_max_skew_seconds` hardcoded 60s in `config.py:91` — make configurable.
- Mock SMS / payments still in code: real providers go behind the existing interfaces.
- Spot-check `POST /admin/gyms/{id}/rotate-qr` writes an audit row.
- `/api/v1/partner-applications` unauthenticated; 30/hr per IP. Consider CAPTCHA if abuse appears.

### A.4 Cleanup findings
- **`print()` in `app/providers/sms/mock_sms.py:25`** — replace with `log.info("mock_sms", phone=..., code=...)`.
- Internal "staging-media" terminology overlap with the new staging env value — clarify in docs.
- Some repos import `text()` but never use it.
- Rate-limit error logs don't include the limiter key — add for ops debugging.

### A.5 Communication contract notes
- **Pydantic schemas are the contract.** Renames or removals = `/v2/` major bump.
- **NextAuth ↔ service-JWT exchange** depends on `ADMIN_EXCHANGE_SECRET` matching on both sides; mismatch → silent 401.
- **Gym-owner role** requires non-null `user.gym_id` (enforced in `current_gym_owner`).
- **Mobile member endpoints** live under `/api/v1/` (no `/member` prefix). Admin reads via dedicated `AdminCheckinReadService` etc.
- **WebSocket** at `/api/v1/realtime/ws` — nginx must pass upgrade headers. Failures are warnings, not fatal.

### A.6 Top 3 SOLID/Clean-Code offenders
1. `subscription_service.py:44–200` — `SubscriptionService` owns the entire purchase flow. Acceptable today; split when renewals / upgrades land.
2. `admin_user_service.py:46–118` — `update()` bundles role-change, self-demotion, field update, audit. Split when policy rules grow.
3. `config.py:176–197 cors_origins()` — couples domain literals with CORS shape. Low priority.

### A.7 Concrete staging-prep checklist
1. `app_env: Literal["development", "production", "staging"] = "development"`.
2. `is_dev` stays `app_env == "development"`.
3. Staging branch in `validate_production_safety()`:
   ```python
   if self.app_env == "staging":
       if self.jwt_secret in self._DEV_SENTINELS or len(self.jwt_secret) < 32:
           problems.append("JWT_SECRET must be a random string >= 32 chars")
       # ADMIN_EXCHANGE_SECRET, POSTGRES_PASSWORD same shape
       return
   ```
4. Set `APP_ENV=staging` in the local staging Compose env file.
5. Confirm secrets are non-dev.
6. End-to-end admin login: NextAuth → exchange → service JWT works.
7. Spot-check CORS from configured admin origin vs. random origin.
8. Trigger one mutation per role; verify `audit_log` rows.
9. Replace `print()` in `mock_sms.py:25`.
10. Document local staging in this plan's §6.1.

---

# Appendix B — Admin Dashboard Handoff (full text)

> Reviewer scope: `admin/`. Skill: `code-reviewer`.

### B.1 What's already solid
- **Env validation** — `src/lib/env.ts` Zod `.min()`; `src/instrumentation.ts` boot-time safety.
- **Auth flow** — NextAuth credentials provider; service token exchange via Web Crypto HMAC; JWT callback refreshes 60s before expiry.
- **Error boundaries** — root + dashboard `error.tsx`, digest refs, dev-only console.
- **Server/client discipline** — most pages server; client only where interactive.
- **i18n coverage** — `en.json` + `ar.json` both 850 lines, balanced.
- **Pagination** — `PAGE_SIZE` constants, URL-encoded pager state.
- **No leftover `debugger` or console spam.**

### B.2 Critical (staging)
- `(dashboard)/partner-applications/[id]/page.tsx:17` — inline `process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://api.gym-pass.net"`. Replace with `env.API_BASE_URL`.
- `(dashboard)/layout.tsx:25–31` — two sequential SDK calls; wrap in `Promise.all()`.
- `(dashboard)/gyms/page.tsx:47–80` — fetch 100 then filter client-side.

### B.3 Important (production)
- Boot-time `exchangeAdminToken()` smoke test in `instrumentation.ts`.
- `revalidate` / `cache()` hints on dashboard metrics.

### B.4 Cleanup
- Prop drilling in `users/[id]/page.tsx`.
- `lib/gyms.ts:93–101 / 147+` — `fetch()` directly for FormData; extract `apiFormData<T>()`.
- Magic string `"urgent"` in `(dashboard)/layout.tsx:27`.

### B.5 Communication contract notes
- **`PendingButton.tsx` is byte-for-byte identical to partner's.** Move to `packages/ui` first.
- **40+ hand-typed DTOs in `src/lib/sdk.ts`.** Codegen target.
- **Behaviours to share via `packages/api-client-ts`:** `api()`, `ApiError`, `hmacSha256Hex()`.

### B.6 Top 3 offenders
1. `(dashboard)/gyms/page.tsx:47–80` — mixes server pagination with client filtering.
2. `components/GymPhotosPanel.tsx:81–97` — two sequential `updateAction()` for photo reorder.
3. `(dashboard)/users/[id]/page.tsx` — destructures 12 fields, passes individually.

### B.7 Concrete staging-prep checklist
- [ ] Env validation boot-time smoke test for `ADMIN_EXCHANGE_SECRET`.
- [ ] Replace hardcoded URL fallback with `env.API_BASE_URL`.
- [ ] `Promise.all()` in dashboard layout.
- [ ] Backend filter push for gyms page or document 100 ceiling.
- [ ] Rotate `NEXTAUTH_SECRET` to a 32+ char random value.
- [ ] Confirm `NEXTAUTH_URL` is `https://` and matches cert.
- [ ] Confirm `API_BASE_URL` reachable from the Next container.
- [ ] `grep -n "console\." src/` clean outside error boundaries.
- [ ] `npm run build` clean.

---

# Appendix C — Gym Partner Portal Handoff (full text)

> Reviewer scope: `gym-partner/`. Skill: `code-reviewer`.

### C.1 What's already solid
- **Realtime architecture** — `RealtimeBridge.tsx:256` exponential backoff, visibility-gating, 250ms event coalescing.
- **Token exchange coalescing** — `auth.ts:33–48` module-level `exchangeInFlight` map keyed by phone.
- **Session-expired redirect** — `api.ts` auto-redirect on `SESSION_EXPIRED_CODES`, `bypassAuthRedirect` escape.
- **HMAC envelope via Web Crypto** — avoids `node:crypto` webpack issues.
- **Env split** — `env.ts` (client) vs `env.server.ts` (secrets).
- **i18n parity** — 376 keys in `en.json` and `ar.json`, no drift.
- **Security headers** — CSP, HSTS preload, X-Frame-Options DENY, Permissions-Policy.
- **File-upload gating** — `lib/upload.ts` matches backend (10MB, MIME allow-list).

### C.2 Critical (staging)
- **Type drift `CheckinStatus.gender_locked`** — `sdk-types.ts:29` has it; admin's `sdk.ts:18` doesn't.
- **`/join` skips `validateImageFile()`** — `JoinForm.tsx:39–48, 51–65, 67–85`.
- **`/join` rate-limit confirmation** — backend has 3/hr for submit and 30/hr for upload. Document.

### C.3 Important (production)
- `JoinForm.tsx` 415L; extract `usePhotoUpload()` hook.
- `Sidebar.tsx` 442L; no error boundary.
- Phone normalization duplicated; extract `lib/phone.ts`.

### C.4 Cleanup
- `console.error` in `(dashboard)/error.tsx`.
- `+962 7X XXX XXXX` hardcoded in three places.
- `GymProfileForm.tsx:171` unsafe cast.

### C.5 Communication contract notes
- **Identical to admin:** `Tier`, `Category`, `AudienceGender`, `LogoAlignment`, `GymRead`, `GymUpdateBody`, `GymPhoto`, `PartnerPayout`, `PartnerDashboardMetrics`, `Page<T>`, `PayoutStatus`, `PartnerCheckin`, `PartnerMe`.
- **Drifted:** `CheckinStatus` (`gender_locked` partner-only).
- **Move to `packages/api-client-ts`:** `exchangeInFlight`, `SESSION_EXPIRED_CODES` redirect, HMAC signing.
- **Move to `packages/ui`:** `PendingButton.tsx`. Candidates: `StatusPill`, `Toolbar`, `LocaleToggle`, `ThemeToggle`.

### C.6 Top 3 offenders
1. `JoinForm.tsx` 415L — SRP.
2. `AmenitiesPicker.tsx` 218L.
3. `Sidebar.tsx` 442L — no error boundary.

### C.7 Concrete staging-prep checklist
- [ ] Resolve `CheckinStatus.gender_locked` drift with admin.
- [ ] Integrate `validateImageFile()` in `JoinForm.tsx`.
- [ ] Extract `normalizeJordanianPhone()`.
- [ ] Wrap `Sidebar.tsx` gym-data in `<ErrorBoundary>`.
- [ ] Remove or dev-gate `console.error` in `error.tsx`.
- [ ] Move `+962 7X XXX XXXX` to `messages/*.json`.
- [ ] `npm run build` with missing `ADMIN_EXCHANGE_SECRET` fails fast.
- [ ] Render `/join` in AR; verify RTL flipping.

---

# Appendix D — Flutter Code Handoff (full text)

> Reviewer scope: `mobile/`. Skill: `code-reviewer`.

### D.1 What's already solid
- **Token-refresh coalescing** — `core/api/api_client.dart:26–32, 121–128`.
- **Error unwrapping** — `:93–115` maps backend error envelope to `ApiException`.
- **Timeout policy** — 15s connect / 30s receive.
- **WebSocket lifecycle** — `core/realtime/realtime_client.dart` 1s→30s backoff, idle pings 25s, token-first auth frame.
- **Token storage** — `FlutterSecureStorage` for tokens.
- **Feature module integrity** — 13 features under `lib/features/<x>/{data,presentation}`, zero cross-module presentation imports.
- **Router** — four-branch stateful bottom-nav, per-branch navigator keys.
- **Biometric** — `local_auth`, SHA-256 vault, OS PIN fallback.
- **Image caching** — `CachedNetworkImage` 30-day LRU.

### D.2 Critical (production, not staging since staging is local)
- **Android release signed with debug key** — `android/app/build.gradle.kts:59`.
- **No `network_security_config.xml`** — `android:usesCleartextTraffic="true"` global.

### D.3 Important (production)
- **Hand-rolled `fromJson` everywhere.** `freezed` + `json_serializable` in `dev_dependencies` unused.
- **No ProGuard/R8 rules.**
- **iOS signing** — `CODE_SIGN_IDENTITY = "iPhone Developer"` (ad-hoc).

### D.4 Cleanup
- Unused `MeResponse` in `auth_repository.dart:11–42`.
- `AppEnv.isDev` semantics — split into `useMockAuth` + `isProduction`.
- Feature `home/` has no `data/` (aggregator shell).

### D.5 Communication contract notes
- **DTO parsing today:** hand-rolled with unsafe casts. Gap vs codegen: moderate.
- **WebSocket lifecycle** — singleton `realtimeClientProvider`. Don't refactor.
- **Env fitness for `staging`:** `--dart-define=APP_ENV=staging` recognised but behaves like dev. Fix: split `isDev` into `useMockAuth` + `isProduction`.

### D.6 Top 3 offenders
1. `ExplorePageState` watches 6 providers at top level (`explore_page.dart:757–762`).
2. `SettingsPage` 1718L.
3. `PlansPage` 1238L / `MySubscriptionPage` 967L — duplicate inline tier cards.

### D.7 Concrete staging-prep checklist (local-staging adjusted)
- [ ] Split `AppEnv.isDev` into `useMockAuth` + `isProduction`.
- [ ] `--dart-define=API_BASE_URL=https://10.0.2.2:8443 --dart-define=APP_ENV=staging` builds and runs (emulator with local mkcert cert installed).
- [ ] Or real device with mkcert root CA installed on the device + LAN IP.
- [ ] Cold-start latency measurement.
- [ ] WS auth handshake on `wss://api.gym-pass.local:8443/realtime/ws` (or LAN IP).
- [ ] Biometric fallback on a device without fingerprint.
- [ ] Token-refresh stress test on throttled 3G.
- [ ] Locale toggle on `/settings`.

---

# Appendix E — Flutter Design Handoff (full text)

> Reviewer scope: `mobile/lib/core/theme/`, `mobile/lib/l10n/`, `mobile/lib/features/*/presentation/`, `pubspec.yaml`, `design/project/`. Skill: `code-reviewer`.

### E.1 What's already solid
- **`ThemeExtension<GpColors>`** correctly wired; `context.gp` is canonical.
- **Light/dark fully plumbed.**
- **Tier color mapping centralised** — `GPTier` with `readableOn()`.
- **Typography foundation** — `GPText` mapped into `TextTheme`.
- **Radii** — `GPRadius.{sm,md,lg,xl,xl2,pill}` used 208 times.
- **l10n parity perfect** — both ARB files 727 keys, zero drift.
- **Default locale AR**; both delegates wired.
- **RTL in critical paths** — duration carousel in `plans_page.dart:850–894`.

### E.2 Critical (staging)
- **6 hex literals** in `tier_name_label.dart:116, 161–162`, `gym_detail_page.dart:744–745`, `explore_page.dart:1199`.
- **1 hardcoded `Text('Term visits maxed out')`** in `checkin_page.dart:652`.
- **19 `Colors.white` / `Colors.black`** in foreground/gradient/placeholder contexts.

### E.3 Important (production)
- **`GPSpace.*` never used** — 70+ inline padding literals.
- **`EdgeInsets.only(left:, right:)`** instead of `EdgeInsetsDirectional`.
- **Inline `TextStyle(fontSize: ...)`** literals.
- One-off brightness logic in `plans_page.dart:740–745`.

### E.4 Cleanup
- `InstrumentSerif` declared but unused.
- `app_colors.dart` thin alias layer.
- Font fallback repeated three times.

### E.5 Communication contract notes
- **Extract tokens to `design/project/tokens.json`** (shape in §3.5).
- **Reliability scorecard:** solid (lime, ink, paper, danger, success, warn, radii); moderate (tier colors); drift-prone (spacing — defined but unused); ad-hoc (gender colors, marker blue).

### E.6 Worst 5 token-discipline offenders
1. `tier_name_label.dart:161–162` — platinum gradient hex duplicated.
2. `gym_detail_page.dart:419` — `LinearGradient([Colors.black, Colors.black, Colors.transparent])`.
3. `gym_list_sheet.dart:510` — `Container(color: Colors.white)` placeholder.
4. `checkin_page.dart:652` — hardcoded `Text('...')`.
5. `explore_page.dart:1199` — `Color(0xFF1A73E8)` off-palette marker.

### E.7 l10n / ARB parity
- Hardcoded `Text("...")` literals in screen widgets: **5** total (1 critical, 4 safe variable interpolations).
- EN-only keys: **0**. AR-only keys: **0**. Perfect parity at 727 keys.

---

## Footer — process notes

Produced by a five-agent code-review pipeline:

| Agent | Scope | Skill |
|---|---|---|
| Backend reviewer | `backend/` | `code-reviewer` |
| Admin reviewer | `admin/` | `code-reviewer` |
| Gym-partner reviewer | `gym-partner/` | `code-reviewer` |
| Flutter code reviewer | `mobile/` engineering | `code-reviewer` |
| Flutter design reviewer | `mobile/` theme + l10n + design fidelity | `code-reviewer` |

The master synthesis (§0–§6) is the canonical action list. Appendices A–E are the raw handoffs preserved verbatim. Future re-reviews should rerun the same pipeline and diff against this document.

**Change log:**

- 2026-05-16 v1 — Initial generic plan (VM-based pre-prod assumed).
- 2026-05-16 v2 — Rewritten against actual code inspection.
- 2026-05-16 v3 — Synthesized from five `code-reviewer` sub-agents.
- 2026-05-16 v4 — Added §3.7 (module dependency rules), §4.6 (coding conventions), §6.0 (target architecture). Folded SOLID offenders into Phase B (§5 Phase column). Mobile signing + `network_security_config` moved to §2 production prep. Phase B drops GHCR, Cloudflare tunnel, rsync-APK.
- 2026-05-16 v5 (this version) — **Three-compose deployment model finalised** as the durable end-state: `docker-compose.yml` (dev base) + `docker-compose.staging.yml` (portable: laptop **and** VM) + `docker-compose.prod.yml` (Phase C copy-from-staging). §6.1 Phase A rewritten around delivering the staging overlay with env-driven nginx vhosts (`${API_DOMAIN}`, `${ADMIN_DOMAIN}`, `${PARTNER_DOMAIN}`, `${WEBSITE_DOMAIN}`) — same file runs on laptop with mkcert certs and on a VM with Cloudflare/Let's Encrypt certs, both mounted at `./nginx/certs/`. §6.3 Phase C made concrete around a `docker-compose.prod.yml` copy-from-staging plus real SMS/payment providers. The architecture work (§3, §3.7, §4.6, §6.0, §6.2) is unchanged — durable for the future.
