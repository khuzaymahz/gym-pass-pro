"""PII masking helpers — one source of truth for "what does Y see
about X" rules across the API.

Audience policy (most → least privilege):

  - **Admin** (`/api/v1/admin/...`): full PII. Operator role with
    audit-log accountability. NEVER call these helpers on admin
    responses — admins need the raw data to do their job.

  - **Member** (`/api/v1/...` consumed by the mobile app):
    members see their **own** PII unmasked, and `display_name` of
    other members in cases the member opted into (referrals,
    invite-by-name). Phone/email of other members are NEVER
    exposed — even masked.

  - **Partner** (`/api/v1/partner/...`): partners see members
    walking through their gate. They have no contact relationship
    with the member, so:
      - **Name** → first name + last initial. "Ahmad Khalil" → "Ahmad K."
      - **Phone** → last 4 digits masked over. "+962791234567" → "•• ••• 4567"
      - **Email** → NEVER returned. Drop the field at the schema boundary.
      - **User UUID** → returned (operators need it for support tickets),
        but rendered as the truncated short-id everywhere it shows.

If a new audience needs a different policy, add a new function
here rather than inlining the masking at the endpoint. The whole
codebase greps one way: `mask_phone_for_partner` is the contract.
"""

from __future__ import annotations


def mask_phone_for_partner(phone: str | None) -> str | None:
    """Return a partner-safe representation of a phone number.

    Keeps the trailing 4 digits as identification anchor (members
    occasionally tell the front desk their last 4 to claim a lost-
    something-at-the-gym ticket), drops everything else.

    Examples:
      "+962791234567" → "•• ••• 4567"
      "+962791111"    → "•• ••• 1111"
      None / ""       → None
    """
    if not phone:
        return None
    digits = "".join(c for c in phone if c.isdigit())
    if len(digits) < 4:
        return "•• ••• ••••"
    return f"•• ••• {digits[-4:]}"


def mask_name_for_partner(
    name: str | None,
    *,
    first_name: str | None = None,
    last_name: str | None = None,
) -> str | None:
    """First name + last initial. Falls back through the structured
    name fields if `name` (the legacy combined string) is empty.

    Examples:
      ("Ahmad Khalil", None, None)    → "Ahmad K."
      (None, "Lina", "Nasser")        → "Lina N."
      ("Ahmad", None, None)           → "Ahmad"  (no last name to mask)
      (None, None, None)              → None
    """
    if first_name:
        first = first_name.strip()
        last = (last_name or "").strip()
        return f"{first} {last[0]}." if last else first
    if not name:
        return None
    parts = name.strip().split()
    if len(parts) == 0:
        return None
    if len(parts) == 1:
        return parts[0]
    return f"{parts[0]} {parts[-1][0]}."


__all__ = ["mask_phone_for_partner", "mask_name_for_partner"]
