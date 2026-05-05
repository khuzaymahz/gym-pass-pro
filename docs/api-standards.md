# API Standards — GymPass

> Rules for the FastAPI backend. OpenAPI is auto-generated at `/api/openapi.json` and `/docs` in dev. Everything the admin and mobile apps consume is contractually bound by this document.
> Breaking changes go through versioning (§4) — never in place.

---

## 1 · Base URL & versioning

- All endpoints live under `/api/v1/`.
- Version bumps (`/api/v2/`) are created when a breaking change is required. `/v1/` continues serving for at least one full release cycle after `/v2/` lands.
- **Non-breaking changes** (adding a field, adding an endpoint, widening an enum) stay in `/v1/`.
- **Breaking changes** (renaming a field, tightening validation, changing an error-code shape, removing a field) require a new version.

---

## 2 · URL design

### Shape

```
/api/v1/{resource}                  # collection
/api/v1/{resource}/{id}             # single
/api/v1/{resource}/{id}/{sub}       # sub-resource (rare)
/api/v1/admin/{resource}            # admin-only
```

- Resource names are **plural**, **kebab-case** (single-word usually): `gyms`, `plans`, `check-ins`, `payout-ledger`.
- IDs are UUIDs in the path.
- No verbs in URLs — verbs are HTTP methods. Exception: actions that don't map to CRUD (`/subscriptions/{id}/cancel`, `/gyms/{id}/rotate-qr`, `/auth/otp/request`).
- Query strings for filtering/sorting/paging — never path.

### Examples

| Good | Bad |
|---|---|
| `GET /api/v1/gyms?category=gym&tier=gold` | `GET /api/v1/getGyms?cat=gym` |
| `POST /api/v1/check-ins` | `POST /api/v1/doCheckin` |
| `POST /api/v1/subscriptions/{id}/cancel` | `POST /api/v1/cancelSubscription/{id}` |

---

## 3 · HTTP methods

| Method | Use | Idempotent? | Safe? |
|---|---|---|---|
| `GET` | Read | Yes | Yes |
| `POST` | Create, non-idempotent actions | No | No |
| `PUT` | Full replace | Yes | No |
| `PATCH` | Partial update | No (unless we make it so) | No |
| `DELETE` | Remove (soft where possible) | Yes | No |

We default to `PATCH` for edits (sparse payload), reserving `PUT` for the rare full-replace case.

---

## 4 · Request & response format

- **Content-Type:** `application/json` for request and response bodies.
- **Naming:** `camelCase` on the wire. Backend is Pydantic v2 with `alias_generator=to_camel` and `populate_by_name=True`.
- **Dates/times:** ISO 8601 with timezone. Always UTC on the wire (`2026-04-20T21:15:00Z`). Clients localize on display.
- **Currency:** numbers as strings `"45.00"` → avoids JS float drift. Always JOD.
- **IDs:** UUIDs as strings.
- **Null vs absent:** a field absent from the payload means "don't change" on PATCH; `null` means "set to null." Never send empty strings to mean null.

### Response envelope

Successful responses return the resource or collection directly — **no `{data: …}` wrapper**.

```json
{ "id": "01HK…", "name": "Iron Forge", "category": "gym", "requiredTier": "silver" }
```

Collection responses are paginated (see §7):

```json
{
  "items": [ {…}, {…} ],
  "pageInfo": { "cursor": "eyJpZCI…", "hasMore": true, "total": 128 }
}
```

### Error envelope

Errors return the **same shape across the whole API**:

```json
{
  "error": {
    "code": "CHECKIN_TIER_LOCKED",
    "message": "Your tier does not include this gym.",
    "details": {
      "requiredTier": "platinum",
      "currentTier": "gold"
    },
    "requestId": "01HKB4N…"
  }
}
```

- `code` — canonical `UPPER_SNAKE_CASE`. Never renamed (see §5).
- `message` — human-readable English. The mobile/admin map `code` → localized string in their own i18n layer. **Do not translate `message` on the server.**
- `details` — optional structured context. Field names also `camelCase`.
- `requestId` — correlation ID; set by middleware, echoed here so support can find the log entry.

---

## 5 · Error codes (canonical)

Codes are a flat namespace, scoped by domain prefix. Adding a code requires a PR updating this table + the `core/exceptions.py` registry.

| Code | HTTP | When |
|---|---|---|
| `AUTH_OTP_INVALID` | 400 | OTP code doesn't match or is consumed. |
| `AUTH_OTP_EXPIRED` | 400 | OTP TTL elapsed. |
| `AUTH_OTP_LOCKED` | 429 | Too many failed attempts for that phone. |
| `AUTH_INVALID_CREDENTIALS` | 401 | Admin login failed. |
| `AUTH_TOKEN_INVALID` | 401 | JWT malformed or signature fails. |
| `AUTH_TOKEN_EXPIRED` | 401 | JWT `exp` in past. |
| `AUTH_GOOGLE_TOKEN_INVALID` | 401 | Google ID token verification failed. |
| `AUTH_FORBIDDEN` | 403 | Authenticated but not authorized (e.g. member hitting admin route). |
| `SUB_NOT_FOUND` | 404 | No matching subscription. |
| `SUB_EXPIRED` | 409 | Subscription past expiry. |
| `SUB_CANCELLED` | 409 | Subscription cancelled. |
| `SUB_DUPLICATE_ACTIVE` | 409 | User already has an active subscription. |
| `PLAN_NOT_FOUND` | 404 | |
| `PLAN_INACTIVE` | 409 | Plan disabled — cannot purchase. |
| `GYM_NOT_FOUND` | 404 | |
| `GYM_INACTIVE` | 409 | Gym archived. |
| `CHECKIN_QR_INVALID` | 400 | QR token doesn't resolve to an active gym. |
| `CHECKIN_TIER_LOCKED` | 403 | Member's tier rank below gym's `required_tier`. |
| `CHECKIN_NO_VISITS` | 409 | Monthly visits budget consumed. |
| `CHECKIN_ALREADY_SCANNED` | 409 | Member scanned this gym within 30 min. |
| `RATE_LIMITED` | 429 | Generic rate-limit trip. |
| `PAYMENT_DECLINED` | 402 | Gateway declined; `details.gatewayCode` has provider reason. |
| `PAYMENT_GATEWAY_ERROR` | 502 | Gateway unreachable / invalid response. |
| `VALIDATION_ERROR` | 422 | Pydantic raised; `details.fields` enumerates issues. |
| `NOT_FOUND` | 404 | Generic. Prefer domain-specific above. |
| `INTERNAL_ERROR` | 500 | Unhandled. `details` omitted in prod. |

### Payload example — validation error

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "One or more fields are invalid.",
    "details": {
      "fields": [
        { "path": "phone", "reason": "Must be an E.164 phone starting with +962." },
        { "path": "name",  "reason": "Must not be empty." }
      ]
    },
    "requestId": "01HKB4N…"
  }
}
```

---

## 6 · Authentication

### Member

- Header: `Authorization: Bearer <access_token>`
- Access TTL 15 min; refresh at `POST /api/v1/auth/refresh` with `{refreshToken}`.
- Refresh tokens are **rotated** on every refresh — the old one is revoked.
- Refresh TTL 30 days.

### Admin

- Browser first signs into NextAuth (session cookie).
- NextAuth exchanges its cookie for a **service JWT** via `POST /api/v1/admin/session-token`. TTL 5 min.
- All subsequent admin calls: `Authorization: Bearer <service_token>`.

### CORS

- Dev: `*` (anywhere localhost).
- Prod: `Access-Control-Allow-Origin: https://admin.gym-pass.net` — single value, no wildcards.

### Rate limiting

- Redis-backed sliding window.
- Defaults: `100 req/min per user` for authenticated traffic, `20 req/min per IP` for anonymous.
- Stricter on auth endpoints:
  - `POST /auth/otp/request` — 5 req/min per phone + 10 req/min per IP.
  - `POST /auth/otp/verify` — 10 req/5min per phone.
  - `POST /auth/google` — 30 req/min per IP.
- On breach: `429` with `RATE_LIMITED` + `Retry-After` seconds header.

---

## 7 · Pagination, filtering, sorting

### Pagination — cursor by default

```
GET /api/v1/gyms?limit=20&cursor=eyJpZCI6IjAxSEsuLiIsInRzIjoxNzI2Li59
```

- `limit` — int, default 20, max 100.
- `cursor` — opaque base64-encoded JSON. Clients never parse it; they just pass it back.
- Response `pageInfo.cursor` is the next page's cursor (or absent if end).
- Always sorted server-side — typically `created_at DESC, id DESC` for stability.

> Offset pagination (`?page=2`) is allowed **only** on admin list pages where total counts matter and the dataset is small. Use `pageInfo.total` there.

### Filtering

Query-string parameters, scalar-valued:

```
GET /api/v1/gyms?category=gym&requiredTier=gold&area=Abdoun&isActive=true
GET /api/v1/check-ins?userId=01HK…&fromDate=2026-04-01&toDate=2026-04-30
```

- Use `camelCase`.
- Dates: `YYYY-MM-DD` for ranges (inclusive).
- Enums: lower-case, matching DB values.
- Multi-value filters: repeat the key (`?tier=gold&tier=platinum`) — not CSV.

### Sorting

```
GET /api/v1/check-ins?sort=-scannedAt
```

- `sort` — single field; prefix `-` for DESC.
- Allow-list sortable fields per endpoint; reject unknown fields with `VALIDATION_ERROR`.

---

## 8 · Idempotency

- `POST` endpoints that create resources accept an `Idempotency-Key` header (UUID). The backend caches the response for that key for 24h. Repeating the same key returns the original response.
- Required for: payment creation (`POST /api/v1/payments`) and subscription purchase (`POST /api/v1/subscriptions`). Optional elsewhere.

---

## 9 · Caching

- `GET` responses set `Cache-Control: private, max-age=<ttl>` where appropriate.
- Gym metadata (`GET /api/v1/gyms/{id}`) — `max-age=60`.
- Plans (`GET /api/v1/plans`) — `max-age=300`.
- User-specific data — `private, no-store`.
- `ETag` on list and detail responses; clients send `If-None-Match` — 304 when unchanged.

---

## 10 · Localization

- Requests may include `Accept-Language: ar, en;q=0.7`. The backend picks `ar` or `en` and echoes `Content-Language` on the response.
- **Only `error.message` is affected by Accept-Language** — and only if we later decide to translate. Today: server responds in English. Clients map `code` to localized copy via their i18n layer.
- Resource fields that are bilingual are returned as objects — never collapsed based on Accept-Language:

```json
{
  "id": "01HK…",
  "nameEn": "Iron Forge",
  "nameAr": "آيرون فورج"
}
```

This keeps responses cacheable and lets clients switch locale without re-fetching.

---

## 11 · Webhooks & async

Not in v1. When payment gateways or SMS providers are added with webhook callbacks:

- All webhooks arrive at `/api/v1/webhooks/{provider}`.
- Signed with an HMAC header (`X-Signature`); validated before any processing.
- Return `200` as soon as the payload is persisted; heavy work happens in a Celery task.

---

## 12 · HTTP status-code policy

| Status | Use |
|---|---|
| `200` | Successful read or update returning the resource. |
| `201` | Successful create — `Location` header points at the new resource. |
| `202` | Accepted, async work started (rarely used in v1). |
| `204` | Successful delete — no body. |
| `301/302` | Not used by the API. |
| `400` | Bad request — malformed JSON, wrong types at the parser level. |
| `401` | Missing or invalid credentials. |
| `402` | Payment required (reserved for `PAYMENT_DECLINED`). |
| `403` | Authenticated but not allowed (tier lock, role lock). |
| `404` | Resource not found. |
| `409` | State conflict (subscription already active, gym already in that state). |
| `410` | Resource deleted/archived — don't retry. |
| `422` | Validation error (post-parse, semantic). |
| `429` | Rate limited. |
| `500` | Server bug. |
| `502/503` | Upstream (gateway) down. |

Pair status with the right error code from §5 — a `403 AUTH_FORBIDDEN` is not interchangeable with `403 CHECKIN_TIER_LOCKED`.

---

## 13 · Security headers

nginx adds in prod:

```
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: interest-cohort=()
Content-Security-Policy: default-src 'none'; connect-src 'self'; frame-ancestors 'none'
```

FastAPI avoids setting these itself (let nginx own them in prod; in dev they're absent — fine).

---

## 14 · Logging & tracing

- Every request has an auto-assigned `request_id` (ULID). It:
  - Appears in every log line for that request.
  - Is echoed in `X-Request-Id` response header.
  - Appears in error payloads as `requestId`.
- Request/response bodies are **not** logged by default. Opt-in per endpoint for non-PII debug traces.

---

## 15 · OpenAPI discipline

- Every endpoint has:
  - A `summary` (≤ 60 chars).
  - A `description` (Markdown ok).
  - Typed responses for **every** status code it can emit (including errors).
  - `responses: {400: {...}, 404: {...}, 422: {...}}` declared via a shared `ErrorResponse` model.
- Endpoint tags match resource names for clean doc grouping.
- CI diffs `openapi.json` — if a PR changes it, the diff must be explicit and reviewed.

---

## 16 · Examples — side-by-side

### POST `/api/v1/check-ins` — success

Request:
```http
POST /api/v1/check-ins HTTP/1.1
Authorization: Bearer <member_access>
Content-Type: application/json
Idempotency-Key: 01HKBP5…

{ "qrToken": "5c1e8bda-...-9f", "at": "2026-04-20T21:15:00Z" }
```

Response:
```http
HTTP/1.1 201 Created
Content-Type: application/json
X-Request-Id: 01HKB4N…

{
  "checkinId": "01HKB5A…",
  "gym": { "id": "…", "nameEn": "Iron Forge", "nameAr": "آيرون فورج" },
  "visitsLeft": 23,
  "scannedAt": "2026-04-20T21:15:00Z"
}
```

### POST `/api/v1/check-ins` — tier-locked

```http
HTTP/1.1 403 Forbidden

{
  "error": {
    "code": "CHECKIN_TIER_LOCKED",
    "message": "Your tier does not include this gym.",
    "details": { "requiredTier": "platinum", "currentTier": "gold" },
    "requestId": "01HKB4N…"
  }
}
```

### GET `/api/v1/gyms` — filter + paginate

```http
GET /api/v1/gyms?category=yoga&requiredTier=silver&limit=2 HTTP/1.1
Authorization: Bearer <member_access>

HTTP/1.1 200 OK

{
  "items": [
    { "id": "…", "slug": "bedford-yoga", "nameEn": "Bedford Yoga", "nameAr": "…", "category": "yoga", "requiredTier": "gold", "rating": 4.9, "reviewCount": 208, "area": "Sweifieh" },
    { "id": "…", "slug": "halo-studio",  "nameEn": "Halo Studio",  "nameAr": "…", "category": "yoga", "requiredTier": "silver", "rating": 4.6, "reviewCount": 142, "area": "Abdali" }
  ],
  "pageInfo": { "cursor": "eyJpZCI6IjAxSEsuLiIsInRzIjoxNzI2Li59", "hasMore": true, "total": 11 }
}
```
