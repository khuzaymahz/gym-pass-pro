SHELL := /bin/bash

.PHONY: up down logs backend-shell db-shell migrate seed backend-test admin-install partner-install mobile-get mobile-test prod-up prod-down

up:
	docker compose up -d --build

down:
	docker compose down

logs:
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

prod-up:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build

prod-down:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml down
