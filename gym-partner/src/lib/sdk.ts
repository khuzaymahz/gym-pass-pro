import { getServerSession } from "next-auth";
import { redirect } from "next/navigation";

import { api } from "@/lib/api";
import { authOptions } from "@/lib/auth";

export type Page<T> = {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
};

export type Tier = "silver" | "gold" | "platinum" | "diamond";
export type Category = "gym" | "crossfit" | "martial" | "yoga";
export type CheckinStatus =
  | "success"
  | "tier_locked"
  | "no_visits"
  | "expired"
  | "invalid_qr"
  | "rate_limited";
export type PayoutStatus = "pending" | "paid";

export type GymRead = {
  id: string;
  slug: string;
  nameEn: string;
  nameAr: string;
  addressEn: string;
  addressAr: string;
  area: string;
  lat: string | number;
  lng: string | number;
  phone: string | null;
  category: Category;
  requiredTier: Tier;
  perVisitRateJod: string;
  amenities: string[];
  openingHours: Record<string, unknown>;
  coverImageUrl: string | null;
  logoUrl: string | null;
  rating: string | null;
  reviewCount: number;
  photoCount: number;
  isActive: boolean;
};

export type GymUpdateBody = Partial<{
  nameEn: string;
  nameAr: string;
  addressEn: string;
  addressAr: string;
  area: string;
  lat: number;
  lng: number;
  phone: string | null;
  category: Category;
  amenities: string[];
  openingHours: Record<string, unknown>;
  coverImageUrl: string | null;
}>;

export type GymPhoto = {
  id: string;
  gymId: string;
  url: string;
  sortOrder: number;
  altTextEn: string | null;
  altTextAr: string | null;
};

export type PartnerCheckin = {
  id: string;
  userId: string;
  userName: string | null;
  userPhone: string | null;
  gymId: string;
  gymNameEn: string;
  gymNameAr: string;
  status: CheckinStatus;
  scannedAt: string;
  failureReason: string | null;
};

export type PartnerPayout = {
  id: string;
  gymId: string;
  gymNameEn: string;
  periodStart: string;
  periodEnd: string;
  totalAmountJod: string;
  entryCount: number;
  status: PayoutStatus;
  paidAt: string | null;
  notes: string | null;
};

export type PartnerDashboardMetrics = {
  checkinsToday: number;
  checkinsThisMonth: number;
  checkinsLast30Days: number;
  uniqueMembersLast30Days: number;
  revenueMtdJod: string;
  pendingPayoutTotalJod: string;
  paidPayoutMtdJod: string;
  checkinsPerDay: { day: string; count: number }[];
  revenuePerDay: { day: string; total: string }[];
  tierBreakdown: Record<string, number>;
  hourBreakdown: { hour: number; count: number }[];
  recentCheckins: {
    id: string;
    userId: string;
    userName: string | null;
    scannedAt: string;
  }[];
};

export type PartnerMe = {
  id: string;
  phone: string;
  name: string | null;
  role: "gym_owner";
  gymId: string;
};

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
