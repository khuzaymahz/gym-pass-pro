from __future__ import annotations

import structlog
from fastapi import Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.exceptions import AppError, ErrorCode

log = structlog.get_logger(__name__)


async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    request_id = getattr(request.state, "request_id", None)
    status = exc.status_code or 500
    payload = exc.to_payload(request_id=request_id)
    if status >= 500:
        log.error(
            "app_error",
            code=exc.code.value,
            message=exc.message,
            status=status,
        )
    else:
        log.info(
            "app_error",
            code=exc.code.value,
            message=exc.message,
            status=status,
        )
    return JSONResponse(status_code=status, content=payload)


async def validation_error_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    request_id = getattr(request.state, "request_id", None)
    # Pydantic's `errors()` can embed `ctx` payloads holding raw exception
    # instances (e.g. ValueError from a `@field_validator`). `jsonable_encoder`
    # is FastAPI's canonical way to coerce those into JSON-safe primitives.
    err = AppError(
        ErrorCode.VALIDATION_ERROR,
        "Validation failed.",
        details={"errors": jsonable_encoder(exc.errors())},
        status_code=422,
    )
    return JSONResponse(status_code=422, content=err.to_payload(request_id=request_id))


async def http_exception_handler(
    request: Request, exc: StarletteHTTPException
) -> JSONResponse:
    request_id = getattr(request.state, "request_id", None)
    code = (
        ErrorCode.NOT_FOUND if exc.status_code == 404
        else ErrorCode.AUTH_FORBIDDEN if exc.status_code == 403
        else ErrorCode.INTERNAL_ERROR
    )
    err = AppError(
        code,
        str(exc.detail) if exc.detail else "HTTP error",
        status_code=exc.status_code,
    )
    return JSONResponse(
        status_code=exc.status_code, content=err.to_payload(request_id=request_id)
    )


async def unhandled_error_handler(
    request: Request, exc: Exception
) -> JSONResponse:
    request_id = getattr(request.state, "request_id", None)
    log.exception("unhandled", path=request.url.path)
    err = AppError(ErrorCode.INTERNAL_ERROR, "Internal server error.")
    return JSONResponse(status_code=500, content=err.to_payload(request_id=request_id))
