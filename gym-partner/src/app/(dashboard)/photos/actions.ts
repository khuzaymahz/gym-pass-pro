"use server";

import { getServerSession } from "next-auth";

import { ApiError } from "@/lib/api";
import { authOptions } from "@/lib/auth";
import { env } from "@/lib/env";
import { PartnerSDK } from "@/lib/sdk";

export async function uploadPhotoAction(
  data: FormData,
): Promise<{ ok: boolean; error?: string }> {
  const session = await getServerSession(authOptions);
  if (!session?.serviceToken) {
    return { ok: false, error: "Not signed in." };
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
