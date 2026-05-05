from __future__ import annotations

import os
import time
from uuid import UUID


def uuid7() -> UUID:
    """RFC 9562 UUID v7 — time-ordered, compatible with UUID type.

    Layout (128 bits): 48-bit unix_ms | 4-bit version=7 | 12-bit rand_a |
    2-bit variant=10 | 62-bit rand_b.
    """
    unix_ms = int(time.time() * 1000) & 0xFFFFFFFFFFFF
    rand_a = int.from_bytes(os.urandom(2), "big") & 0x0FFF
    rand_b = int.from_bytes(os.urandom(8), "big") & 0x3FFFFFFFFFFFFFFF

    high = (unix_ms << 16) | (0x7 << 12) | rand_a
    low = (0b10 << 62) | rand_b
    value = (high << 64) | low
    return UUID(int=value)
