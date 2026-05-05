from __future__ import annotations

import pytest


async def _sign_up_and_get_token(client, phone: str, referral_code: str | None = None) -> tuple[str, dict]:
    r1 = await client.post("/api/v1/auth/phone/start", json={"phone": phone})
    assert r1.status_code == 204, r1.text
    payload: dict = {"phone": phone, "code": "1234"}
    if referral_code is not None:
        payload["referralCode"] = referral_code
    r2 = await client.post("/api/v1/auth/phone/verify", json=payload)
    assert r2.status_code == 200, r2.text
    body = r2.json()
    return body["accessToken"], body


@pytest.mark.asyncio
async def test_new_member_gets_referral_code_on_signup(client):
    token, _ = await _sign_up_and_get_token(client, "+962791110001")
    r = await client.get(
        "/api/v1/me/referral",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["code"].startswith("GP-")
    assert len(body["code"]) == 9  # GP- + 6 chars
    assert body["counts"] == {"pending": 0, "converted": 0, "expired": 0}
    assert body["invited"] == []
    assert body["shareUrl"].endswith(body["code"])


@pytest.mark.asyncio
async def test_referral_code_is_unique_per_user(client):
    token_a, _ = await _sign_up_and_get_token(client, "+962791110002")
    token_b, _ = await _sign_up_and_get_token(client, "+962791110003")
    a = (
        await client.get(
            "/api/v1/me/referral", headers={"Authorization": f"Bearer {token_a}"}
        )
    ).json()
    b = (
        await client.get(
            "/api/v1/me/referral", headers={"Authorization": f"Bearer {token_b}"}
        )
    ).json()
    assert a["code"] != b["code"]


@pytest.mark.asyncio
async def test_invited_user_claim_attaches_and_counts(client):
    # Referrer signs up first.
    token_ref, _ = await _sign_up_and_get_token(client, "+962791110010")
    referrer = (
        await client.get(
            "/api/v1/me/referral", headers={"Authorization": f"Bearer {token_ref}"}
        )
    ).json()
    code = referrer["code"]

    # Invited user signs up with that code.
    token_invited, _ = await _sign_up_and_get_token(
        client, "+962791110011", referral_code=code
    )
    assert token_invited

    # Referrer should now see one pending invite.
    after = (
        await client.get(
            "/api/v1/me/referral", headers={"Authorization": f"Bearer {token_ref}"}
        )
    ).json()
    assert after["counts"]["pending"] == 1
    assert after["counts"]["converted"] == 0
    assert len(after["invited"]) == 1
    assert after["invited"][0]["status"] == "pending"


@pytest.mark.asyncio
async def test_unknown_referral_code_rejected(client):
    r1 = await client.post(
        "/api/v1/auth/phone/start", json={"phone": "+962791110020"}
    )
    assert r1.status_code == 204
    r2 = await client.post(
        "/api/v1/auth/phone/verify",
        json={
            "phone": "+962791110020",
            "code": "1234",
            "referralCode": "GP-NOPE99",
        },
    )
    assert r2.status_code == 422
    assert r2.json()["error"]["code"] == "VALIDATION_ERROR"


@pytest.mark.asyncio
async def test_referral_code_ignored_on_returning_user(client):
    # Existing user — first sign-up generates a code.
    token, _ = await _sign_up_and_get_token(client, "+962791110030")

    # Second user who WOULD refer.
    token_ref, _ = await _sign_up_and_get_token(client, "+962791110031")
    ref_code = (
        await client.get(
            "/api/v1/me/referral", headers={"Authorization": f"Bearer {token_ref}"}
        )
    ).json()["code"]

    # First user logs in again, passing referralCode — should be ignored.
    r1 = await client.post(
        "/api/v1/auth/phone/start", json={"phone": "+962791110030"}
    )
    assert r1.status_code == 204
    r2 = await client.post(
        "/api/v1/auth/phone/verify",
        json={
            "phone": "+962791110030",
            "code": "1234",
            "referralCode": ref_code,
        },
    )
    assert r2.status_code == 200  # existing user: success, no claim attempt

    # Referrer sees zero invites.
    summary = (
        await client.get(
            "/api/v1/me/referral",
            headers={"Authorization": f"Bearer {token_ref}"},
        )
    ).json()
    assert summary["counts"]["pending"] == 0
