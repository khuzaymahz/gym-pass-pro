"""Identify images by magic bytes, not by the client-provided Content-Type.

Content-Type headers are trivial to forge — any untrusted upload path must
confirm the payload actually *is* what it claims to be. We only accept the
three formats the admin UI produces (JPEG, PNG, WebP), so a tiny hand-rolled
sniff is enough without pulling in libmagic or Pillow.
"""

from __future__ import annotations

# (mime, extension) keyed by detection. Order matters: WebP contains "RIFF"
# which overlaps nothing else here but we keep WebP specifically ahead of
# any future RIFF-family additions.
_PNG_SIG = b"\x89PNG\r\n\x1a\n"
_JPEG_SIG = b"\xff\xd8\xff"


def sniff_image(payload: bytes) -> tuple[str, str] | None:
    """Return (mime, ext) if the payload starts with a supported image
    signature, else None. Only the first ~16 bytes are inspected.
    """
    if len(payload) < 12:
        return None
    head = payload[:16]
    if head.startswith(_PNG_SIG):
        return "image/png", "png"
    if head.startswith(_JPEG_SIG):
        return "image/jpeg", "jpg"
    # WebP: "RIFF....WEBP"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "image/webp", "webp"
    return None
