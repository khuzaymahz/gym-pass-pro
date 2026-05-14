"""Member-facing API routers.

Routes exposed under `/api/v1` that are consumed by the Flutter
mobile app. Each module owns one resource/concept and depends on
`current_user` (the member-JWT dep) — no admin or partner role
gating belongs here.

Cross-audience entry points (`auth.py`, `realtime.py`) deliberately
stay at the v1 root since they're shared by the mobile, the admin
dashboard, and the partner portal.
"""
