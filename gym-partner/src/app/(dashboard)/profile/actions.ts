"use server";

import { getServerSession } from "next-auth";

import { ApiError } from "@/lib/api";
import { authOptions } from "@/lib/auth";
import { env } from "@/lib/env";
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
export async function uploadLogoAction(
  data: FormData,
): Promise<{ ok: boolean; error?: string }> {
  const session = await getServerSession(authOptions);
  if (!session?.serviceToken) {
    return { ok: false, error: "Not signed in." };
  }
  const response = await fetch(
    `${env.API_BASE_URL}/api/v1/partner/gym/logo`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${session.serviceToken}`,
      },
      body: data,
      cache: "no-store",
    },
  );
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    return {
      ok: false,
      error: body?.error?.message ?? response.statusText,
    };
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
