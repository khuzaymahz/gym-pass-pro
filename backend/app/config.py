from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field, PostgresDsn, RedisDsn
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # App
    # Three values, one policy per. `development` is frictionless local
    # work (mock-OTP `1234`, mock payments, demo seed allowed). `staging`
    # is production-like but with SMS + payments still mocked — the
    # only legitimate non-development mocks per CLAUDE.md §15.
    # `production` flips both providers to real adapters.
    app_env: Literal["development", "staging", "production"] = "development"
    app_name: str = "gympass-backend"
    log_level: str = "INFO"

    # DB
    postgres_user: str = "gympass"
    postgres_password: str = "changeme"
    postgres_db: str = "gympass"
    postgres_host: str = "db"
    postgres_port: int = 5432
    # Pool sized for the parallel-read dashboard services: a single
    # admin overview request can briefly take ~21 connections in
    # gather; two concurrent admins would otherwise exhaust the
    # pool. 20 + 40 = 60 concurrent connections supports several
    # dashboard tabs + member traffic comfortably.
    db_pool_size: int = 20
    db_max_overflow: int = 40

    # Redis
    redis_url: RedisDsn = Field(default="redis://redis:6379/0")  # type: ignore[arg-type]
    celery_broker_url: RedisDsn = Field(default="redis://redis:6379/1")  # type: ignore[arg-type]
    celery_result_backend: RedisDsn = Field(default="redis://redis:6379/2")  # type: ignore[arg-type]

    # JWT
    jwt_secret: str = "changeme-long-random-string"
    jwt_access_ttl_seconds: int = 900
    jwt_refresh_ttl_seconds: int = 2_592_000
    jwt_service_ttl_seconds: int = 300  # 5 min — admin → backend hop
    jwt_algorithm: str = "HS256"

    # OAuth
    google_oauth_client_id: str | None = None
    google_oauth_client_secret: str | None = None

    # SMS
    sms_provider: Literal["mock", "twilio", "unifonic"] = "mock"
    sms_api_key: str | None = None
    sms_sender_id: str = "GymPass"

    # Payments
    payment_provider: Literal["mock"] = "mock"
    payment_mock_delay_ms: int = 1500

    # CORS
    admin_domain: str = "admin.gym-pass.net"
    api_domain: str = "api.gym-pass.net"
    partner_domain: str = "partner.gym-pass.net"

    # Admin bootstrap
    admin_bootstrap_email: str | None = "admin@gym-pass.net"
    admin_bootstrap_password: str | None = "changeme-dev"

    # Dev partner bootstrap (only used by scripts/seed.py in dev).
    # Leave any field as None to skip seeding the demo partner.
    partner_bootstrap_phone: str | None = None
    partner_bootstrap_password: str | None = None
    partner_bootstrap_gym_slug: str | None = None
    partner_bootstrap_name: str | None = None

    # Shared HMAC secret for the NextAuth ↔ FastAPI admin exchange.
    # NextAuth signs `${email}|${nonce}|${epoch_seconds}` with this
    # secret; the backend recomputes the HMAC and rejects requests
    # whose signature doesn't match, whose timestamp is outside a
    # 60s window, or whose nonce was already used inside the window.
    # Without this, anyone who can reach `/auth/admin/exchange` could
    # post any admin email and walk away with a service token — the
    # nginx Origin restriction was trivially spoofable.
    admin_exchange_secret: str = "changeme-admin-exchange-secret"
    # How far apart the admin's clock and the backend's may drift
    # before the request is rejected as stale. 60 s is generous
    # enough to absorb VM clock skew while small enough that a
    # leaked signed payload can't be replayed beyond a minute.
    admin_exchange_max_skew_seconds: int = 60

    # Media / uploads
    # Files live on the backend container disk at media_root and are served
    # over HTTP at media_url_prefix. Filenames are opaque UUIDs, so the public
    # prefix and the on-disk path don't need to match outside of convention.
    media_root: str = "/app/media"
    media_url_prefix: str = "/media"
    max_upload_mb: int = 10

    # Public-facing base URL the mobile app embeds in shareable links
    # (e.g. referral invites). Defaults to the production landing page;
    # override via `SHARE_BASE_URL` for staging or a custom domain.
    # Trailing slash is stripped at use-site so callers can append
    # segments without double-slashes.
    share_base_url: str = "https://gym-pass.net"

    # Intent-named policy properties. Read these from feature code, not
    # `is_dev` or `app_env` directly — that way adding a fourth env
    # value later is a single policy decision per property, not a code
    # search across the repo. Naming convention: `should_*` for
    # behaviour gates, `is_*` for env identity.
    #
    # `is_dev` stays for backwards compatibility with existing
    # callers and as a shorthand for "development specifically". New
    # code should prefer the intent-named flags.
    @property
    def is_dev(self) -> bool:
        return self.app_env == "development"

    @property
    def is_staging(self) -> bool:
        return self.app_env == "staging"

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    @property
    def should_use_fixed_otp(self) -> bool:
        """Use the sentinel OTP (1234) instead of a random code.
        True in development (frictionless local work) and staging
        (testers don't have access to real SMS logs)."""
        return self.app_env in ("development", "staging")

    @property
    def should_mock_sms(self) -> bool:
        """True when the SMS provider should be the no-op mock that
        logs the OTP code instead of sending it. Driven off
        `sms_provider`, not `app_env`, so a future "real-SMS staging
        dry-run" needs only an env-var flip, not a code change."""
        return self.sms_provider == "mock"

    @property
    def should_mock_payments(self) -> bool:
        return self.payment_provider == "mock"

    @property
    def should_seed_demo_data(self) -> bool:
        """Demo seed (admin bootstrap user + demo member + sample
        gyms) runs only in development. Staging and production seed
        nothing automatically — they get real data from migrations +
        operator action."""
        return self.app_env == "development"

    @property
    def should_relax_cors(self) -> bool:
        """Development echoes any `localhost:*` origin. Staging and
        production lock to the configured admin/partner hostnames."""
        return self.app_env == "development"

    @property
    def should_enforce_secret_strength(self) -> bool:
        """Both staging and production require real (non-sentinel,
        ≥32-char) JWT / admin-exchange / postgres secrets. Development
        accepts the `changeme-*` defaults so a fresh clone boots."""
        return self.app_env in ("staging", "production")

    @property
    def should_enable_debug(self) -> bool:
        """FastAPI `debug=True` only in development."""
        return self.app_env == "development"

    # Values that are obvious "fill this in before prod" placeholders. Any
    # of these sitting in a production config means the operator hasn't
    # actually configured the app — we'd rather refuse to boot than silently
    # ship with them.
    _DEV_SENTINELS: "frozenset[str]" = frozenset(
        {
            "changeme",
            "changeme-dev",
            "changeme-long-random-string",
            "dev-nextauth-secret-change-me",
            "admin123",
            "changeme-admin-exchange-secret",
        }
    )

    def validate_production_safety(self) -> None:
        """Fail fast in staging or production if critical secrets still
        have dev defaults.

        Called from `create_app()`. Raised here rather than in a Pydantic
        validator so dev runs (and unit tests that construct Settings
        directly) aren't blocked. Both staging and production enforce
        secret-strength via `should_enforce_secret_strength`; the only
        difference is that production *also* requires a strong admin
        bootstrap password (operators may keep the dev bootstrap user
        across the staging reset cycle).
        """
        if not self.should_enforce_secret_strength:
            return
        problems: list[str] = []
        if self.jwt_secret in self._DEV_SENTINELS or len(self.jwt_secret) < 32:
            problems.append("JWT_SECRET must be a random string >= 32 chars")
        if (
            self.admin_exchange_secret in self._DEV_SENTINELS
            or len(self.admin_exchange_secret) < 32
        ):
            problems.append(
                "ADMIN_EXCHANGE_SECRET must be a random string >= 32 chars "
                "(shared with the admin app's NextAuth signing layer)"
            )
        if self.postgres_password in self._DEV_SENTINELS:
            problems.append("POSTGRES_PASSWORD must not be a dev default")
        # Admin bootstrap password is only strictly required in
        # production — staging may keep a short operator-known
        # password without blocking startup.
        if self.is_production and (
            self.admin_bootstrap_password is None
            or self.admin_bootstrap_password in self._DEV_SENTINELS
            or len(self.admin_bootstrap_password) < 12
        ):
            problems.append(
                "ADMIN_BOOTSTRAP_PASSWORD must be set and >= 12 chars in production"
            )
        if problems:
            env_label = self.app_env
            raise RuntimeError(
                f"Refusing to start in {env_label} with insecure defaults:\n  - "
                + "\n  - ".join(problems)
            )

    def sqlalchemy_url(self, *, sync: bool = False) -> str:
        driver = "postgresql+asyncpg" if not sync else "postgresql+psycopg"
        return str(
            PostgresDsn.build(
                scheme=driver,
                username=self.postgres_user,
                password=self.postgres_password,
                host=self.postgres_host,
                port=self.postgres_port,
                path=self.postgres_db,
            )
        )

    def cors_origins(self) -> list[str]:
        if self.should_relax_cors:
            # Dev was previously a wildcard `*`, which is convenient
            # but means any browser tab on any domain can hit the
            # local backend. Limit to the actual surfaces we run
            # locally — admin (3001/3000), partner (3003), website
            # preview (3004), mobile web preview (5173), plus the
            # backend itself (8000) for `/docs`. Add more ports here
            # if a new local surface lands.
            return [
                "http://localhost:3000",
                "http://127.0.0.1:3000",
                "http://localhost:3001",
                "http://127.0.0.1:3001",
                "http://localhost:3003",
                "http://127.0.0.1:3003",
                "http://localhost:3004",
                "http://127.0.0.1:3004",
                "http://localhost:5173",
                "http://127.0.0.1:5173",
                "http://localhost:8000",
                "http://127.0.0.1:8000",
            ]
        # Staging + production both lock CORS to the configured
        # hostnames. The env vars resolve to `stg-admin.gym-pass.net`
        # / `stg-partner.gym-pass.net` in staging and `admin.` /
        # `partner.` in production — same code path, different
        # env-var values.
        return [
            f"https://{self.admin_domain}",
            f"https://{self.partner_domain}",
        ]


@lru_cache
def get_settings() -> Settings:
    return Settings()
