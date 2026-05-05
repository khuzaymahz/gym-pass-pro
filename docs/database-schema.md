# Database Schema — GymPass

> PostgreSQL 16. SQLAlchemy 2.0 async. Alembic for migrations.
> This file is the contract. Any column, index, or constraint change starts with a PR to this file **in the same commit** as the Alembic migration.

---

## Conventions

- **IDs:** UUID v7 (time-ordered) stored as `uuid`. Generated server-side via `uuid.uuid7()` (not DB default — keeps generation portable).
- **Timestamps:** `created_at` and `updated_at` on every table, `timestamptz` with `DEFAULT now()`. `updated_at` maintained by an ON UPDATE trigger.
- **Soft delete:** `deleted_at timestamptz NULL` on any table where deletion is reversible (users, gyms). Hard delete for ephemeral (`otp_codes`).
- **Money:** `numeric(10,2)` for JOD amounts. Never `float`. Currency is always JOD in v1 — when multi-currency comes, we add a `currency char(3)` column.
- **Enums:** Postgres native `ENUM` types for fixed domains (`tier_enum`, `category_enum`, `sub_status_enum`, …). Adding a value requires a migration.
- **Text:** `text` (not `varchar(n)`) — no arbitrary length caps.
- **Booleans:** `boolean NOT NULL DEFAULT …`.
- **FKs:** named (`fk_<table>_<col>_<ref_table>`); `ON DELETE RESTRICT` by default; `ON DELETE SET NULL` only where explicitly called out below.
- **Indexes:** named (`ix_<table>_<col>` or `ix_<table>_<col1>_<col2>` for composites).
- **Naming convention file** (`sqlalchemy.MetaData(naming_convention=…)`) keeps Alembic diffs deterministic.

---

## Enums

```sql
CREATE TYPE tier_enum AS ENUM ('silver', 'gold', 'platinum', 'diamond');
CREATE TYPE category_enum AS ENUM ('gym', 'crossfit', 'martial', 'yoga');
CREATE TYPE role_enum AS ENUM ('member', 'admin');
CREATE TYPE sub_status_enum AS ENUM ('pending', 'active', 'expired', 'cancelled');
CREATE TYPE payment_method_enum AS ENUM ('card', 'cliq', 'apple_pay', 'mock');
CREATE TYPE payment_status_enum AS ENUM ('pending', 'succeeded', 'failed');
CREATE TYPE checkin_status_enum AS ENUM ('success', 'tier_locked', 'no_visits', 'expired', 'invalid_qr', 'rate_limited');
CREATE TYPE payout_status_enum AS ENUM ('pending', 'paid');
CREATE TYPE notification_type_enum AS ENUM ('expire', 'checkin', 'promo', 'guest', 'system');
CREATE TYPE locale_enum AS ENUM ('ar', 'en');
CREATE TYPE gender_enum AS ENUM ('male', 'female');
```

`gender_enum` is a closed set in v1. It is captured at registration because some partner gyms are single-gender (male-only or female-only) and we need to enforce access policy server-side at check-in. Expanding the set later requires a migration + policy review.

Tier `rank()`: `silver=0`, `gold=1`, `platinum=2`, `diamond=3`. Implemented as a `CASE` in SQLAlchemy; never stored, always derived.

---

## Tables

### `users`

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | — | PK |
| `phone` | text | yes | — | `+962…` E.164. Unique when not null. |
| `email` | text | yes | — | Unique when not null. |
| `first_name` | text | yes | — | Given name. Nullable only during an in-flight Google-OAuth signup before the profile-completion step writes it. |
| `last_name` | text | yes | — | Family name. Same nullability rationale as `first_name`. |
| `password_hash` | text | yes | — | argon2id hash of the member's password. NULL for users who only sign in via phone OTP or Google OAuth. Plaintext passwords are never logged or stored. |
| `gender` | `gender_enum` | yes | — | Captured at registration. NULL only during an in-flight signup; required before check-in so single-gender gyms can enforce access. |
| `google_sub` | text | yes | — | Google OAuth subject. Unique when not null. |
| `role` | `role_enum` | no | `'member'` | `admin` set manually. |
| `locale` | `locale_enum` | no | `'ar'` | Preferred UI locale. |
| `avatar_url` | text | yes | — | CDN URL. |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | Trigger-maintained. |
| `deleted_at` | timestamptz | yes | — | Soft-delete flag. |

**Constraints / indexes:**

- PK `pk_users (id)`
- `uq_users_phone` partial: `UNIQUE (phone) WHERE phone IS NOT NULL AND deleted_at IS NULL`
- `uq_users_email` partial: `UNIQUE (email) WHERE email IS NOT NULL AND deleted_at IS NULL`
- `uq_users_google_sub` partial: `UNIQUE (google_sub) WHERE google_sub IS NOT NULL`
- `ck_users_identity`: `phone IS NOT NULL OR email IS NOT NULL OR google_sub IS NOT NULL`
- `ck_users_auth_method`: `password_hash IS NOT NULL OR google_sub IS NOT NULL OR phone IS NOT NULL` — every user must have at least one way to authenticate.
- `ix_users_role` on `(role)`

**Password storage:** hashes only, argon2id with per-hash random salt (tuned via `argon2-cffi`). The mobile and admin apps never see the hash — password verification happens in the backend during login. The Flutter mock directory hashes locally (SHA-256) so the dev stand-in does not keep plaintext either, but that is a dev-only fallback and is not the production algorithm.

---

### `otp_codes`

Ephemeral — a row is inserted on `request`, deleted on `verify` or TTL cleanup.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | — | PK |
| `phone` | text | no | — | E.164. |
| `code_hash` | text | no | — | argon2 hash of the 4-digit code. |
| `attempts` | int | no | `0` | Increment on wrong verify; lock after 5. |
| `expires_at` | timestamptz | no | — | `now() + 5 min`. |
| `consumed_at` | timestamptz | yes | — | Set on successful verify. |
| `created_at` | timestamptz | no | `now()` | |

**Constraints / indexes:**

- PK `pk_otp_codes (id)`
- `ix_otp_codes_phone_expires` on `(phone, expires_at DESC)`
- Celery/SQL job: delete expired rows nightly.

> Redis keeps the latest `otp:{phone}` code hash for fast lookup; Postgres keeps history for audit & rate-limit forensics.

---

### `gyms`

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | — | PK, also encoded in QR. Rotate regenerates. |
| `slug` | text | no | — | URL-safe; `iron-forge`. Unique. |
| `name_en` | text | no | — | |
| `name_ar` | text | no | — | |
| `address_en` | text | no | — | |
| `address_ar` | text | no | — | |
| `area` | text | no | — | Abdoun / Sweifieh / … |
| `lat` | numeric(9,6) | no | — | |
| `lng` | numeric(9,6) | no | — | |
| `phone` | text | yes | — | |
| `category` | `category_enum` | no | — | |
| `required_tier` | `tier_enum` | no | `'silver'` | Min tier to check in. |
| `per_visit_rate_jod` | numeric(10,2) | no | `2.00` | What we pay the gym per visit. |
| `rating` | numeric(2,1) | yes | — | 0.0–5.0. |
| `review_count` | int | no | `0` | |
| `cover_image_url` | text | yes | — | CDN. |
| `amenities` | jsonb | no | `'[]'` | Array of amenity keys: `["wifi","parking","showers"]`. |
| `opening_hours` | jsonb | no | — | `{"mon":["06:00","23:00"], …}` or `"24/7"`. |
| `is_active` | boolean | no | `true` | |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |
| `deleted_at` | timestamptz | yes | — | |

**Constraints / indexes:**

- PK `pk_gyms (id)`
- `uq_gyms_slug` unique on `(slug)`
- `ix_gyms_category_required_tier` on `(category, required_tier)` — for filter queries
- `ix_gyms_is_active` on `(is_active)` partial `WHERE is_active = true AND deleted_at IS NULL`
- `ix_gyms_area` on `(area)`

---

### `plans`

One plan per tier per duration.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | — | PK |
| `tier` | `tier_enum` | no | — | |
| `duration_months` | int | no | — | 1 or 12. |
| `price_jod` | numeric(10,2) | no | — | |
| `monthly_visits` | int | no | — | `NULL` would mean unlimited; we store a sentinel `9999` for Diamond and check in code. Alternative: make column nullable — decision below. |
| `included_gym_count` | int | no | — | Cached; display-only. |
| `features_en` | jsonb | no | `'[]'` | Array of strings. |
| `features_ar` | jsonb | no | `'[]'` | Array of strings. |
| `discount_percent` | numeric(5,2) | no | `0` | Annual discount vs monthly. |
| `is_active` | boolean | no | `true` | |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |

**Constraints / indexes:**

- PK `pk_plans (id)`
- `uq_plans_tier_duration` unique on `(tier, duration_months)` — one plan per tier+duration.
- `ck_plans_monthly_visits_positive`: `monthly_visits > 0`

> **Decision:** `monthly_visits` stays `NOT NULL`. Diamond's "unlimited" is enforced in `services/checkin_service.py` via `if plan.tier == 'diamond': skip visit budget check`, not a magic number. The stored value (e.g. 90) is still shown in UI.

---

### `subscriptions`

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | — | PK |
| `user_id` | uuid | no | — | FK → `users.id` ON DELETE RESTRICT |
| `plan_id` | uuid | no | — | FK → `plans.id` ON DELETE RESTRICT |
| `tier` | `tier_enum` | no | — | Denormalized snapshot — plans can change; subscription keeps the tier it was bought at. |
| `status` | `sub_status_enum` | no | `'pending'` | |
| `starts_at` | timestamptz | no | — | |
| `expires_at` | timestamptz | no | — | |
| `visits_used` | int | no | `0` | Incremented atomically on check-in. |
| `auto_renew` | boolean | no | `false` | Reserved for Phase 5+. |
| `cancelled_at` | timestamptz | yes | — | |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |

**Constraints / indexes:**

- PK `pk_subscriptions (id)`
- FK `fk_subscriptions_user_id_users (user_id)` → `users(id)`
- FK `fk_subscriptions_plan_id_plans (plan_id)` → `plans(id)`
- `uq_subscriptions_active_per_user` — partial unique: `UNIQUE (user_id) WHERE status = 'active'` — at most one active subscription per user.
- `ix_subscriptions_user_status` on `(user_id, status)`
- `ix_subscriptions_expires_at` on `(expires_at)` — sweep job for auto-expire.

---

### `payments`

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | — | PK |
| `subscription_id` | uuid | no | — | FK → `subscriptions.id` ON DELETE RESTRICT |
| `amount_jod` | numeric(10,2) | no | — | |
| `method` | `payment_method_enum` | no | — | |
| `gateway_txn_id` | text | yes | — | Provider-issued. `mock-<uuid>` for mock. |
| `status` | `payment_status_enum` | no | `'pending'` | |
| `raw_response` | jsonb | no | `'{}'` | For mock: `{"mock": true}`. |
| `processed_at` | timestamptz | yes | — | Set on status leaving `pending`. |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |

**Constraints / indexes:**

- PK `pk_payments (id)`
- FK `fk_payments_subscription_id_subscriptions (subscription_id)` → `subscriptions(id)`
- `ix_payments_subscription_id` on `(subscription_id)`
- `ix_payments_gateway_txn_id` unique partial on `(gateway_txn_id) WHERE gateway_txn_id IS NOT NULL`

---

### `checkins`

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | — | PK |
| `user_id` | uuid | no | — | FK → `users.id` |
| `gym_id` | uuid | no | — | FK → `gyms.id` |
| `subscription_id` | uuid | yes | — | FK → `subscriptions.id` — NULL for failed attempts. |
| `scanned_at` | timestamptz | no | `now()` | |
| `ip_address` | inet | yes | — | |
| `user_agent` | text | yes | — | |
| `status` | `checkin_status_enum` | no | — | |
| `failure_reason` | text | yes | — | Extra context for non-success statuses. |
| `created_at` | timestamptz | no | `now()` | |

**Constraints / indexes:**

- PK `pk_checkins (id)`
- FK `fk_checkins_user_id_users (user_id)`
- FK `fk_checkins_gym_id_gyms (gym_id)`
- FK `fk_checkins_subscription_id_subscriptions (subscription_id)`
- `ix_checkins_user_scanned_at` on `(user_id, scanned_at DESC)` — user history queries
- `ix_checkins_gym_scanned_at` on `(gym_id, scanned_at DESC)` — per-gym activity
- `ix_checkins_status` on `(status)` partial `WHERE status != 'success'` — error triage
- **Rate limit:** enforced in Redis (30-min sliding window), not in DB. DB still records failed `rate_limited` attempts for audit.

---

### `payout_ledger`

One row per successful check-in. Immutable.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | — | PK |
| `gym_id` | uuid | no | — | FK → `gyms.id` |
| `checkin_id` | uuid | no | — | FK → `checkins.id` ON DELETE RESTRICT |
| `amount_jod` | numeric(10,2) | no | — | = `gym.per_visit_rate_jod` at time of check-in. |
| `rate_applied` | numeric(10,2) | no | — | Denormalized — keeps history of rate changes. |
| `payout_id` | uuid | yes | — | FK → `payouts.id` — NULL until aggregated. |
| `created_at` | timestamptz | no | `now()` | |

**Constraints / indexes:**

- PK `pk_payout_ledger (id)`
- FK `fk_payout_ledger_gym_id_gyms (gym_id)`
- FK `fk_payout_ledger_checkin_id_checkins (checkin_id)`
- FK `fk_payout_ledger_payout_id_payouts (payout_id)`
- `uq_payout_ledger_checkin_id` unique on `(checkin_id)` — one ledger entry per check-in.
- `ix_payout_ledger_gym_payout` on `(gym_id, payout_id)` — aggregation.

---

### `payouts`

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | — | PK |
| `gym_id` | uuid | no | — | FK → `gyms.id` |
| `period_start` | date | no | — | Month start. |
| `period_end` | date | no | — | Month end (inclusive). |
| `total_amount_jod` | numeric(12,2) | no | — | Sum of ledger entries in period. |
| `entry_count` | int | no | — | Count of ledger entries. |
| `status` | `payout_status_enum` | no | `'pending'` | |
| `paid_at` | timestamptz | yes | — | |
| `notes` | text | yes | — | Manual notes by admin. |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |

**Constraints / indexes:**

- PK `pk_payouts (id)`
- FK `fk_payouts_gym_id_gyms (gym_id)`
- `uq_payouts_gym_period` unique on `(gym_id, period_start, period_end)` — one payout per gym per period.
- `ix_payouts_status` on `(status)` partial `WHERE status = 'pending'` — due-payouts view.

---

### `notifications`

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | — | PK |
| `user_id` | uuid | no | — | FK → `users.id` |
| `type` | `notification_type_enum` | no | — | |
| `title_en` | text | no | — | |
| `title_ar` | text | no | — | |
| `body_en` | text | no | — | |
| `body_ar` | text | no | — | |
| `deep_link` | text | yes | — | In-app route, e.g. `/gyms/iron-forge`. |
| `read_at` | timestamptz | yes | — | |
| `created_at` | timestamptz | no | `now()` | |

**Constraints / indexes:**

- PK `pk_notifications (id)`
- FK `fk_notifications_user_id_users (user_id)` → `users(id)` `ON DELETE CASCADE`
- `ix_notifications_user_unread` on `(user_id, created_at DESC)` partial `WHERE read_at IS NULL`

---

### `audit_log`

Append-only. Every domain mutation writes a row in the same transaction.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | — | PK |
| `actor_user_id` | uuid | yes | — | FK → `users.id` ON DELETE SET NULL. NULL for system actions. |
| `actor_role` | `role_enum` | yes | — | Snapshot of actor's role. |
| `action` | text | no | — | Dot-separated verb: `gym.create`, `checkin.attempt`, `payout.mark_paid`. |
| `entity_type` | text | no | — | `gym`, `user`, `subscription`, … |
| `entity_id` | uuid | yes | — | |
| `diff_json` | jsonb | no | `'{}'` | `{"before": {...}, "after": {...}}` or `{"note": "…"}`. |
| `ip_address` | inet | yes | — | |
| `user_agent` | text | yes | — | |
| `created_at` | timestamptz | no | `now()` | |

**Constraints / indexes:**

- PK `pk_audit_log (id)`
- FK `fk_audit_log_actor_user_id_users (actor_user_id)` ON DELETE SET NULL
- `ix_audit_log_entity` on `(entity_type, entity_id, created_at DESC)`
- `ix_audit_log_actor_created` on `(actor_user_id, created_at DESC)`
- Partition by month once table exceeds ~10M rows (Phase 5+).

---

### `refresh_tokens`

Tracks outstanding refresh tokens so we can revoke individual sessions.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | — | PK — also the token's `jti`. |
| `user_id` | uuid | no | — | FK → `users.id` ON DELETE CASCADE |
| `device_info` | text | yes | — | Free-form: "iPhone 15 · iOS 17 · Amman". |
| `expires_at` | timestamptz | no | — | |
| `revoked_at` | timestamptz | yes | — | |
| `last_used_at` | timestamptz | yes | — | |
| `created_at` | timestamptz | no | `now()` | |

**Constraints / indexes:**

- PK `pk_refresh_tokens (id)`
- FK `fk_refresh_tokens_user_id_users (user_id)`
- `ix_refresh_tokens_user_revoked` on `(user_id)` partial `WHERE revoked_at IS NULL`

---

## Relationship diagram

```
users 1 ────► * subscriptions * ────► 1 plans
      │                │
      │                │ 1
      │                ▼
      │            * payments
      │
      ├──► * checkins * ────► 1 gyms
      │         │ 1
      │         ▼
      │     1 payout_ledger * ────► ?1 payouts * ────► 1 gyms
      │
      ├──► * notifications
      ├──► * refresh_tokens
      └──► * audit_log (actor)
```

---

## Seed data (dev only — `scripts/seed.py`)

- **Plans:** one per tier × (monthly, yearly) = 8 rows.
  - Silver: 25 JOD/mo, 12 visits.
  - Gold: 45 JOD/mo, 30 visits.
  - platinum: 75 JOD/mo, 60 visits.
  - Diamond: 110 JOD/mo, 90 visits.
  - Yearly = monthly × 12 × 0.85 (15% discount), same visits/month.
- **Gyms:** 6 from the prototype — Iron Forge, Bedford Yoga, Fortis Boxing, Apex CrossFit, Halo Studio, Core Athletic.
- **Users:**
  - `+962791234567` — member, no subscription.
  - `admin@gym-pass.net` / password `changeme-dev` — admin.
- **Notifications:** 4 mock entries scoped to the first member.

---

## Index strategy rationale

| Query pattern | Index used |
|---|---|
| "Show gyms a Gold member can enter in Abdoun" | `ix_gyms_category_required_tier` + `ix_gyms_area` |
| "My check-in history, most recent first" | `ix_checkins_user_scanned_at` |
| "This gym's activity this month" | `ix_checkins_gym_scanned_at` |
| "Payouts still owed" | `ix_payouts_status` (partial) |
| "Unread notifications badge" | `ix_notifications_user_unread` (partial) |
| "Audit trail for a single gym" | `ix_audit_log_entity` |

---

## Migration discipline

- **Never edit a merged migration.** Fix-forward with a new migration that corrects the issue.
- **Autogenerate + review + hand-edit.** Alembic's autogen isn't perfect — always eyeball the diff and add `server_default` / enum handling / data migrations as needed.
- **Data migrations** go in a separate migration from schema migrations; keep them idempotent.
- **Down migrations** are provided but only run in tests — production rolls forward.
- **Lock timeout** on migrations: `SET LOCAL lock_timeout = '10s'` to avoid indefinite blocking on a busy table.
