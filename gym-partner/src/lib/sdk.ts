import "server-only";

import { getServerSession } from "next-auth";
import { redirect } from "next/navigation";

import { api } from "@/lib/api";
import { authOptions } from "@/lib/auth";

// Re-export every type + constant from `sdk-types.ts` so existing
// `import { ... } from "@/lib/sdk"` call sites in **server**
// components keep working unchanged. Client components must import
// from `@/lib/sdk-types` directly — `import "server-only"` above
// makes any client-bundle import here fail the build with a clear
// message rather than crashing in the browser.
export type {
  Page,
  Tier,
  Category,
  CheckinStatus,
  PayoutStatus,
  LogoFit,
  LogoPosition,
  LogoAlignment,
  GymRead,
  GymUpdateBody,
  GymPhoto,
  PartnerCheckin,
  PartnerPayout,
  PartnerDashboardMetrics,
  PartnerMe,
} from "@/lib/sdk-types";
export { DEFAULT_LOGO_ALIGNMENT } from "@/lib/sdk-types";

import type {
  Page,
  CheckinStatus,
  PayoutStatus,
  GymRead,
  GymUpdateBody,
  GymPhoto,
  PartnerCheckin,
  PartnerPayout,
  PartnerDashboardMetrics,
  PartnerMe,
} from "@/lib/sdk-types";

async function serviceToken(): Promise<string> {
  const session = await getServerSession(authOptions);
  const token = session?.serviceToken;
  if (!token) {
    // No live session token — almost always means the NextAuth
    // cookie expired (8 h `maxAge`) or the JWT callback failed to
    // refresh the embedded service token. Either way, the right
    // recovery is "send the partner back to /login with a clear
    // reason banner", not a 500. `redirect()` throws the
    // NEXT_REDIRECT signal that Next.js catches at the server-
    // component boundary; the (dashboard)/layout.tsx catch knows
    // not to swallow this signal.
    redirect("/login?reason=session_expired");
  }
  return token;
}

function qs(
  params: Record<string, string | number | boolean | null | undefined>,
): string {
  const parts = Object.entries(params)
    .filter(([, v]) => v !== null && v !== undefined && v !== "")
    .map(
      ([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`,
    );
  return parts.length ? `?${parts.join("&")}` : "";
}

export const PartnerSDK = {
  async me(): Promise<PartnerMe> {
    return api("/api/v1/partner/me", { token: await serviceToken() });
  },

  async metrics(): Promise<PartnerDashboardMetrics> {
    return api("/api/v1/partner/gym/metrics/overview", {
      token: await serviceToken(),
    });
  },

  async getGym(): Promise<GymRead> {
    return api("/api/v1/partner/gym", { token: await serviceToken() });
  },

  async updateGym(body: GymUpdateBody): Promise<GymRead> {
    return api("/api/v1/partner/gym", {
      method: "PATCH",
      body: JSON.stringify(body),
      token: await serviceToken(),
    });
  },

  async listPhotos(): Promise<GymPhoto[]> {
    return api("/api/v1/partner/gym/photos", { token: await serviceToken() });
  },

  async deletePhoto(id: string): Promise<void> {
    return api(`/api/v1/partner/gym/photos/${id}`, {
      method: "DELETE",
      token: await serviceToken(),
    });
  },

  /// Logo deletion. Upload uses a multipart server action that
  /// bypasses this JSON helper (see `profile/actions.ts`).
  async deleteLogo(): Promise<GymRead> {
    return api(`/api/v1/partner/gym/logo`, {
      method: "DELETE",
      token: await serviceToken(),
    });
  },

  async listCheckins(params: {
    status?: CheckinStatus;
    since?: string;
    until?: string;
    page?: number;
    pageSize?: number;
  }): Promise<Page<PartnerCheckin>> {
    return api(`/api/v1/partner/gym/checkins${qs(params)}`, {
      token: await serviceToken(),
    });
  },

  async listPayouts(params: {
    status?: PayoutStatus;
    page?: number;
    pageSize?: number;
  }): Promise<Page<PartnerPayout>> {
    return api(`/api/v1/partner/gym/payouts${qs(params)}`, {
      token: await serviceToken(),
    });
  },
};
