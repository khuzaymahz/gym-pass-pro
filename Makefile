SHELL := /bin/bash

.PHONY: up down logs backend-shell db-shell migrate seed backend-test admin-install partner-install mobile-get mobile-test \
        dev-up dev-down dev-logs staging-up staging-down staging-logs smoke-dev smoke-staging \
        ci ci-backend ci-admin ci-partner ci-website ci-mobile pre-commit-install db-backup

# ---- Local development (container ports exposed directly) ----
# No TLS, no nginx. Hit:
#   http://localhost:8000   backend
#   http://localhost:3000   admin
#   http://localhost:3003   gym-partner
#   http://localhost:3004   website

up: dev-up         ## alias

down: dev-down     ## alias

logs: dev-logs     ## alias

dev-up:
	docker compose up -d --build

dev-down:
	docker compose down

dev-logs:
	docker compose logs -f backend admin

backend-shell:
	docker compose exec backend bash

db-shell:
	docker compose exec db psql -U gympass -d gympass

migrate:
	docker compose exec backend uv run alembic upgrade head

seed:
	docker compose exec backend uv run python -m scripts.seed

backend-test:
	docker compose exec backend uv run pytest

admin-install:
	cd admin && npm install

partner-install:
	cd gym-partner && npm install

mobile-get:
	cd mobile && flutter pub get

mobile-test:
	cd mobile && flutter test

# ---- Staging (single VM under stg.gym-pass.net) ----
# Same compose shape as dev; APP_ENV=staging baked in via overlay;
# nginx terminates TLS for the four stg-* hostnames using the
# Cloudflare Origin Cert mounted at ./nginx/certs/.

staging-up:
	docker compose -f docker-compose.yml -f docker-compose.staging.yml --env-file .env.staging up -d --build

staging-down:
	docker compose -f docker-compose.yml -f docker-compose.staging.yml --env-file .env.staging down

staging-logs:
	docker compose -f docker-compose.yml -f docker-compose.staging.yml --env-file .env.staging logs -f

# ---- Smoke checks ----
smoke-dev:
	scripts/smoke.sh http://localhost:8000

smoke-staging:
	scripts/smoke.sh https://stg-api.gym-pass.net

# ---- Local CI parity ----
# `make ci` runs the same lint/test pipeline GitHub Actions runs on
# every PR, locally. Use before pushing to catch a broken build in
# 2 min instead of waiting 8 min for the cloud runner to tell you.
# Sub-targets let you scope to one surface (`make ci-mobile`) when
# you're iterating.

ci: ci-backend ci-admin ci-partner ci-website ci-mobile

ci-backend:
	cd backend && uv sync --frozen --all-extras
	cd backend && uv run alembic upgrade head
	cd backend && uv run pytest -q --maxfail=1

ci-admin:
	cd admin && npm ci
	cd admin && npx tsc --noEmit
	cd admin && npm run build

ci-partner:
	cd gym-partner && npm ci
	cd gym-partner && npx tsc --noEmit
	cd gym-partner && npm run build

ci-website:
	cd website && npm ci
	cd website && npx tsc --noEmit
	cd website && npm run build

ci-mobile:
	cd mobile && flutter pub get
	cd mobile && flutter analyze --no-fatal-warnings --no-fatal-infos
	cd mobile && flutter test --reporter=expanded

# ---- Operator commands ----
# Install the pre-commit hook into the local repo's `.git/hooks/`.
# Run once after a fresh clone. The hook itself lives at
# scripts/pre-commit so it's reviewable in PRs; the install step
# just symlinks it into `.git/hooks/pre-commit`.
pre-commit-install:
	ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit
	@echo "[ok] pre-commit hook installed -> .git/hooks/pre-commit"

# Nightly Postgres dump. Drops a gzipped pg_dump in /backups/.
# Cron entry to add to the VM operator's crontab:
#   0 2 * * * cd /opt/gympass && bash scripts/db-backup.sh
db-backup:
	bash scripts/db-backup.sh
