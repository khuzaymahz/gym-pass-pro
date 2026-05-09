"use server";

import { redirect } from "next/navigation";
import { getServerSession } from "next-auth";

import { ApiError } from "@/lib/api";
import { authOptions } from "@/lib/auth";
import { serverEnv } from "@/lib/env.server";
import { PartnerSDK, type GymUpdateBody } from "@/lib/sdk";

export async function saveGymAction(
  body: GymUpdateBody,
): Promise<{ ok: boolean; error?: string }> {
  try {
    await PartnerSDK.updateGym(body);
    return { ok: true };
  } catch (err) {
    if (err instanceof ApiError) {
      return { ok: false, error: err.message };
    }
    return { ok: false, error: "Unknown error" };
  }
}

/// Multipart upload bypasses the JSON `api()` helper for the same
/// reason the photo upload action does — `fetch` auto-sets the
/// multipart boundary on FormData and we'd corrupt that by stamping
/// a content-type ourselves. Mirrors `(dashboard)/photos/actions.ts`
/// so both upload paths share the same error shape.
///
/// On 401 / 403 we redirect to /login the same way the JSON `api()`
/// helper does for session-expired codes. Without this branch a
/// stale-token upload returned a generic "Logo upload failed." with
/// no recovery path; now the partner gets bounced to /login with the
/// `session_expired` reason flag so the login page shows the right
/// banner. `redirect()` throws a `NEXT_REDIRECT` digest that Next.js
/// catches at the action boundary, so we don't have to thread it
/// through the client manually.
export async function uploadLogoAction(
  data: FormData,
): Promise<{ ok: boolean; error?: string }> {
  const session = await getServerSession(authOptions);
  if (!session?.serviceToken) {
    redirect("/login?reason=session_expired");
  }
  const response = await fetch(
    `${serverEnv.API_BASE_URL}/api/v1/partner/gym/logo`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${session.serviceToken}`,
      },
      body: data,
      cache: "no-store",
    },
  );
  if (response.status === 401 || response.status === 403) {
    redirect("/login?reason=session_expired");
  }
  if (!response.ok) {
    const body = (await response.json().catch(() => null)) as
      | { error?: { message?: unknown } }
      | null;
    const raw = body?.error?.message;
    const message = typeof raw === "string" && raw.length > 0
      ? raw
      : response.statusText || "Logo upload failed.";
    return { ok: false, error: message };
  }
  return { ok: true };
}

export async function deleteLogoAction(): Promise<{
  ok: boolean;
  error?: string;
}> {
  try {
    await PartnerSDK.deleteLogo();
    return { ok: true };
  } catch (err) {
    if (err instanceof ApiError) {
      return { ok: false, error: err.message };
    }
    return { ok: false, error: "Unknown error" };
  }
}
