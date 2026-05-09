"use server";

import { redirect } from "next/navigation";
import { getServerSession } from "next-auth";

import { ApiError } from "@/lib/api";
import { authOptions } from "@/lib/auth";
import { env } from "@/lib/env";
import { PartnerSDK } from "@/lib/sdk";

/// On 401 / 403 we redirect to /login like the JSON `api()` helper
/// does for session-expired codes. Same pattern as `profile/actions.ts`
/// — `redirect()` throws a `NEXT_REDIRECT` digest that Next.js catches
/// at the action boundary, so the client doesn't need to thread the
/// auth-failure case through manually.
export async function uploadPhotoAction(
  data: FormData,
): Promise<{ ok: boolean; error?: string }> {
  const session = await getServerSession(authOptions);
  if (!session?.serviceToken) {
    redirect("/login?reason=session_expired");
  }
  // Multipart upload — bypasses our JSON `api()` helper.
  const response = await fetch(
    `${env.API_BASE_URL}/api/v1/partner/gym/photos`,
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
      : response.statusText || "Photo upload failed.";
    return { ok: false, error: message };
  }
  return { ok: true };
}

export async function deletePhotoAction(
  id: string,
): Promise<{ ok: boolean; error?: string }> {
  try {
    await PartnerSDK.deletePhoto(id);
    return { ok: true };
  } catch (err) {
    if (err instanceof ApiError) {
      return { ok: false, error: err.message };
    }
    return { ok: false, error: "Unknown error" };
  }
}
