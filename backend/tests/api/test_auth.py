from __future__ import annotations

import pytest


@pytest.mark.asyncio
async def test_phone_otp_happy_path(client):
    r1 = await client.post("/api/v1/auth/phone/start", json={"phone": "+962791234567"})
    assert r1.status_code == 204

    r2 = await client.post(
        "/api/v1/auth/phone/verify",
        json={"phone": "+962791234567", "code": "1234"},
    )
    assert r2.status_code == 200, r2.text
    body = r2.json()
    assert "accessToken" in body
    assert "refreshToken" in body


@pytest.mark.asyncio
async def test_phone_start_rejects_bad_phone(client):
    r = await client.post("/api/v1/auth/phone/start", json={"phone": "12345"})
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_phone_verify_bad_code(client):
    await client.post("/api/v1/auth/phone/start", json={"phone": "+962791234568"})
    r = await client.post(
        "/api/v1/auth/phone/verify",
        json={"phone": "+962791234568", "code": "0000"},
    )
    assert r.status_code == 400
    assert r.json()["error"]["code"] == "AUTH_OTP_INVALID"
