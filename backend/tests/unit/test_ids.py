from __future__ import annotations

import time

from app.utils.ids import uuid7


def test_uuid7_is_version_7():
    u = uuid7()
    assert u.version == 7


def test_uuid7_is_sortable_by_time():
    """Two uuid7 values minted across a millisecond boundary must sort
    in mint order. The leading 48 bits of `int` are the unix-ms field
    (RFC 9562 v7 layout) — once the timestamps differ, the rest of the
    bits don't matter to ordering. Sleeping 2 ms guarantees a tick on
    every common platform clock without slowing the suite meaningfully.
    """
    a = uuid7()
    time.sleep(0.002)
    b = uuid7()
    a_ms = a.int >> 80
    b_ms = b.int >> 80
    assert a_ms < b_ms, f"timestamps did not advance: {a_ms} vs {b_ms}"
    assert a.int < b.int
