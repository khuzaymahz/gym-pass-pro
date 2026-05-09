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
    app_env: Literal["development", "production"] = "development"
    app_name: str = "gympass-backend"
    log_level: str = "INFO"

    # DB
    postgres_user: str = "gympass"
    postgres_password: str = "changeme"
    postgres_db: str = "gympass"
    postgres_host: str = "db"
    postgres_port: int = 5432
    db_pool_size: int = 10
    db_max_overflow: int = 20

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

    @property
    def is_dev(self) -> bool:
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
        """Fail fast in production if critical secrets still have dev defaults.

        Called from `create_app()`. Raised here rather than in a Pydantic
        validator so dev runs (and unit tests that construct Settings
        directly) aren't blocked.
        """
        if self.is_dev:
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
        if (
            self.admin_bootstrap_password is None
            or self.admin_bootstrap_password in self._DEV_SENTINELS
            or len(self.admin_bootstrap_password) < 12
        ):
            problems.append(
                "ADMIN_BOOTSTRAP_PASSWORD must be set and >= 12 chars in production"
            )
        if problems:
            raise RuntimeError(
                "Refusing to start in production with insecure defaults:\n  - "
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
        if self.is_dev:
            # Dev was previously a wildcard `*`, which is convenient
            # but means any browser tab on any domain can hit the
            # local backend. Limit to the actual surfaces we run
            # locally — admin (3001), mobile web preview (5173),
            # plus the backend itself (8000) for `/docs`. Add more
            # ports here if a new local surface lands.
            return [
                "http://localhost:3001",
                "http://127.0.0.1:3001",
                "http://localhost:3003",
                "http://127.0.0.1:3003",
                "http://localhost:5173",
                "http://127.0.0.1:5173",
                "http://localhost:8000",
                "http://127.0.0.1:8000",
            ]
        return [
            f"https://{self.admin_domain}",
            f"https://{self.partner_domain}",
        ]


@lru_cache
def get_settings() -> Settings:
    return Settings()
