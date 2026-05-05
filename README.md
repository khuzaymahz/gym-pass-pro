# GymPass

One subscription. Every gym.
Jordan-based multi-gym access app — members subscribe to a tier (Silver / Gold / Platinum / Diamond) and check in at partner gyms by scanning a static QR.

---

## Quick start (prototype preview)

```bash
npm install
npm run dev            # http://localhost:5173 — landing page with every prototype + doc
```

The landing page links to:

- The clickable 16-screen **member prototype** ([`Gym pass Mobile App/`](./Gym%20pass%20Mobile%20App/)).
- The imported **Claude Design bundle** ([`design/`](./design/)) — tokens, preview cards, mobile UI kit.
- Engineering docs ([`docs/`](./docs/)).

No backend runs yet — see [`docs/tasks.md`](./docs/tasks.md) for the implementation plan.

## Repo map

| Path | What |
|---|---|
| [`CLAUDE.md`](./CLAUDE.md) | Working rules for Claude Code. Read first before any code change. |
| [`design/`](./design/) | Authoritative design system (Claude Design bundle). Read before any UI work. |
| [`Gym pass Mobile App/`](./Gym%20pass%20Mobile%20App/) | Legacy 16-screen clickable prototype. |
| [`docs/architecture.md`](./docs/architecture.md) | Full system architecture + SOLID mapping. |
| [`docs/tasks.md`](./docs/tasks.md) | Phased implementation plan (ground truth for work). |
| [`docs/database-schema.md`](./docs/database-schema.md) | PostgreSQL schema. |
| [`docs/api-standards.md`](./docs/api-standards.md) | API conventions + canonical error codes. |
| [`docs/git-instructions.md`](./docs/git-instructions.md) | Branching, commits, PR, release rules. |
| `backend/` · `admin/` · `mobile/` · `nginx/` | Planned — not yet implemented. |

## Stack (target)

- **Mobile:** Flutter 3.24+ (iOS + Android), Arabic-first.
- **Backend:** FastAPI 0.135+ (Python 3.12) + PostgreSQL 16 + Redis 7.
- **Admin:** Next.js 14 (App Router, TS, Tailwind) + `next-intl` + NextAuth.
- **Infra:** docker compose + nginx + Let's Encrypt.

Full stack rationale in [`docs/architecture.md`](./docs/architecture.md).

## Principles (non-negotiable)

1. **Design is the source of visual truth** ([`design/project/README.md`](./design/project/README.md)). Tokens, not hex. ARB/messages, not strings.
2. **SOLID services.** Providers (SMS, payment, push) behind Protocols; services single-responsibility; routes thin.
3. **Audit every mutation.** Same transaction, every time.
4. **Tests ship with features.** No merge otherwise.
5. **Dev mode stays frictionless.** OTP = 1234; payments mocked; seed data available.

See [`CLAUDE.md`](./CLAUDE.md) for the full rulebook.

## License

Proprietary. All rights reserved.
