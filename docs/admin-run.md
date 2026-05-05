# GymPass Admin — Run Instructions

Dev-mode quick start for the admin dashboard + FastAPI backend.

## Prerequisites

- Docker Desktop (with Compose v2)
- A populated `.env` at repo root (see `.env.example`)

## 1. Start the stack

```bash
docker compose up -d db redis
docker compose run --rm backend uv run alembic upgrade head
docker compose run --rm backend uv run python -m scripts.seed
docker compose up -d backend celery-worker celery-beat admin
```

- `db` / `redis` — Postgres 16 + Redis 7
- `backend` — FastAPI at `http://localhost:8000` (OpenAPI at `/docs`)
- `admin` — Next.js 15 at `http://localhost:3001`
- `celery-worker` + `celery-beat` — jobs (payouts, broadcasts)

Logs:

```bash
docker compose logs -f backend
docker compose logs -f admin
```

## 2. Sign in

Open <http://localhost:3001/login>.

| Field    | Value                   |
|----------|-------------------------|
| Email    | `admin@gym-pass.net`    |
| Password | `admin123`              |

These come from `ADMIN_BOOTSTRAP_EMAIL` / `ADMIN_BOOTSTRAP_PASSWORD` in `.env` and are seeded by `scripts/seed.py` on first boot. Rotate them for production — see [§7](#7-production-notes).

## 3. What you can manage

| Section               | Path              | Capabilities                                                                 |
|-----------------------|-------------------|------------------------------------------------------------------------------|
| Dashboard             | `/`               | Active members, revenue (JOD), checkins today/7d/30d, top gyms               |
| Gyms                  | `/gyms`           | Create / edit / soft-delete, rotate QR, bilingual fields, amenities, hours   |
| Users                 | `/users`          | Search, filter by role, soft-delete toggle, edit name/role/locale            |
| Admins                | `/admins`         | Create admin, reset password (min 8 chars)                                   |
| Plans                 | `/plans`          | Price, monthly visits, included gym count, discount, features EN/AR, active  |
| Subscriptions         | `/subscriptions`  | Filter by status/tier/query, cancel active subscriptions                     |
| Check-ins             | `/checkins`       | Filter by gym/user/status/date window                                        |
| Payouts               | `/payouts`        | Generate for period, filter, mark-paid with notes                            |
| Notifications         | `/notifications`  | Broadcast EN/AR title + body, optional tier targeting                        |
| Audit log             | `/audit`          | Filter by entity / action / actor, full diff JSON                            |

Every mutation is written to `audit_log` in the same DB transaction.

## 4. Common tasks

**Add a gym** → `/gyms/new` → QR UUID auto-generated; download print asset from the edit page.

**Rotate a gym QR** → `/gyms/{id}` → "Rotate QR" invalidates the prior QR UUID.

**Generate monthly payouts** → `/payouts` → period start / end defaults to this month → aggregates `payout_ledger` entries per gym.

**Broadcast to Gold tier** → `/notifications` → select target tier → sent via Celery to push + in-app feed.

## 5. Dev shortcuts

- SMS OTP is mocked — the member app accepts `1234` in development.
- Payments are mocked — card / CliQ / Apple Pay all return success after 1.5s.
- `task_always_eager=True` — Celery runs in-process in dev; the worker container runs for parity only.

## 6. Troubleshooting

| Symptom                                        | Fix                                                                                  |
|------------------------------------------------|--------------------------------------------------------------------------------------|
| `401` on every admin call                      | Session expired — log back in; service JWT is minted per-request                     |
| Empty dashboard after seed                     | Seed runs only if tables are empty; drop volumes via `docker compose down -v`        |
| `ECONNREFUSED backend:8000` from admin         | Backend still starting — `docker compose logs backend` and retry                     |
| Admin build on Windows warns about `copyfile`  | Cosmetic trace-copy warning; all 15 routes still compile and run                     |

## 7. Production notes

Before going live:

1. Rotate `ADMIN_BOOTSTRAP_PASSWORD`, `JWT_SECRET`, `NEXTAUTH_SECRET`, `POSTGRES_PASSWORD` to strong values.
2. Set `APP_ENV=production` in `.env`.
3. Pick an SMS provider (see CLAUDE.md §15) and wire `SMS_PROVIDER` + `SMS_API_KEY`.
4. Decide on a payment gateway — current adapter is `payment_provider=mock`.
5. Run the production stack: `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d`.
6. Nginx + certbot handle TLS; admin is served at `https://admin.gym-pass.net`.
