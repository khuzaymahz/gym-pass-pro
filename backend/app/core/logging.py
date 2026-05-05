from __future__ import annotations

import logging
import sys
from typing import Any

import structlog

from app.config import get_settings

_REDACT_KEYS = {"password", "secret", "token", "authorization", "code"}


def _redact(_: Any, __: Any, event_dict: dict[str, Any]) -> dict[str, Any]:
    for key in list(event_dict):
        lowered = key.lower()
        if any(r in lowered for r in _REDACT_KEYS):
            event_dict[key] = "***"
    return event_dict


def configure_logging() -> None:
    settings = get_settings()

    logging.basicConfig(
        stream=sys.stdout,
        level=settings.log_level.upper(),
        format="%(message)s",
    )

    processors: list[structlog.types.Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso", utc=True),
        _redact,
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
    ]

    if settings.is_dev:
        processors.append(structlog.dev.ConsoleRenderer(colors=True))
    else:
        processors.append(structlog.processors.JSONRenderer())

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(
            logging.getLevelName(settings.log_level.upper())
        ),
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    return structlog.get_logger(name)
