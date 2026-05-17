SHELL := /bin/bash

.PHONY: up down logs backend-shell db-shell migrate seed backend-test admin-install partner-install mobile-get mobile-test \
        dev-up dev-down dev-logs staging-up staging-down staging-logs smoke-dev smoke-staging

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
