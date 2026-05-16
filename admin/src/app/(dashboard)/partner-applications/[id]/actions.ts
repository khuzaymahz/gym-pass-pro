"use server";

import { revalidatePath } from "next/cache";

import { AdminSDK } from "@/lib/sdk";

export async function approveApplicationAction(
  id: string,
  notes: string | null,
): Promise<{ ok: true } | { ok: false; error: string }> {
  try {
    await AdminSDK.approvePartnerApplication(id, notes?.trim() || null);
    revalidatePath(`/partner-applications/${id}`);
    revalidatePath("/partner-applications");
    return { ok: true };
  } catch (e) {
    return {
      ok: false,
      error: e instanceof Error ? e.message : "Approval failed.",
    };
  }
}

export async function rejectApplicationAction(
  id: string,
  notes: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  const trimmed = notes.trim();
  if (!trimmed) {
    return { ok: false, error: "Notes are required when rejecting." };
  }
  try {
    await AdminSDK.rejectPartnerApplication(id, trimmed);
    revalidatePath(`/partner-applications/${id}`);
    revalidatePath("/partner-applications");
    return { ok: true };
  } catch (e) {
    return {
      ok: false,
      error: e instanceof Error ? e.message : "Rejection failed.",
    };
  }
}
