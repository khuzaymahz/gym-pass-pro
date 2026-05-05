"""Google ID token verification.

Wraps `google.auth` (already pinned in pyproject) so the auth route gets a
narrow, testable function: verify a Google ID token against Google's JWKS,
return the claims, raise `ValueError` on any failure (bad signature, wrong
audience, untrusted issuer, unverified email). Network calls hit Google's
public certs endpoint — `google.auth.transport.requests.Request` handles
the fetch and caches it in-process.

Kept as a free function rather than a class because there's no state worth
sharing — every call is one verify against fresh Google certs. Adding a
provider Protocol later (e.g. for offline test doubles) only requires
wrapping this function in an interface; consumers stay unchanged.
"""

from __future__ import annotations

from typing import Any

from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

# Google rotates issuer between these two strings. Either is valid; any
# other value is a forgery attempt.
_VALID_ISSUERS = frozenset({"accounts.google.com", "https://accounts.google.com"})


def verify_google_id_token(
    raw_token: str, *, audience: str
) -> dict[str, Any]:
    """Verify a Google-issued ID token. Raises ValueError on any rejection.

    Returns the claims dict (`sub`, `email`, `email_verified`, `name`,
    `picture`, `iss`, `aud`, `exp`, ...). Caller is responsible for
    deciding what to do with the verified identity — this function
    does not touch the user store.

    Reasons a token is rejected:
      - signature does not validate against Google's current JWKS
      - `aud` does not match `audience` (the configured client id)
      - `iss` is not one of Google's documented issuer strings
      - `exp` is in the past (handled inside `id_token.verify_oauth2_token`)
      - `email_verified` is missing or false (we refuse unverified
        emails because the user-by-email lookup would otherwise allow
        an attacker to claim any address by registering it on Google
        without owning the inbox)
    """
    if not raw_token:
        raise ValueError("Empty Google ID token.")
    request = google_requests.Request()
    try:
        # `verify_oauth2_token` checks signature + audience + expiry in one
        # call and raises on any failure. We pass the configured audience
        # explicitly rather than letting the library guess from the token.
        claims: dict[str, Any] = id_token.verify_oauth2_token(
            raw_token, request, audience=audience
        )
    except ValueError:
        # Re-raise without leaking google's internal phrasing into our
        # error code — the route maps any ValueError to AUTH_GOOGLE_TOKEN_INVALID.
        raise ValueError("Google ID token failed verification.") from None

    issuer = str(claims.get("iss", ""))
    if issuer not in _VALID_ISSUERS:
        raise ValueError(f"Untrusted issuer: {issuer!r}.")

    if not claims.get("email"):
        raise ValueError("Google ID token has no email claim.")

    if not claims.get("email_verified", False):
        raise ValueError("Google account email is not verified.")

    if not claims.get("sub"):
        raise ValueError("Google ID token has no subject claim.")

    return claims


__all__ = ["verify_google_id_token"]
