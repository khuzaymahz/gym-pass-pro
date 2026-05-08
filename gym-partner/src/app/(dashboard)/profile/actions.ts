"use server";

import { ApiError } from "@/lib/api";
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
