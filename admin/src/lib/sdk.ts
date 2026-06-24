import "server-only";

import { getServerSession } from "next-auth";
import { cache } from "react";

import { api } from "@/lib/api";
import { authOptions } from "@/lib/auth";

export type Page<T> = {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
};

export type Tier = "silver" | "gold" | "platinum" | "diamond";
export type SubscriptionStatus = "pending" | "active" | "expired" | "cancelled";
// CheckinStatus must match the backend's emitted values byte-for-byte.
// `gender_locked` was added when the partner portal landed audience-
// aware gyms (female-only / male-only); the admin enum drifted and
// admin pages would crash on the first checkin with that status.
// Codegen (see archi-optimization-plan §3.1) will eventually make
// this self-resolving — until then both admin and partner types must
// be kept in sync by hand.
export type CheckinStatus =
  | "success"
  | "tier_locked"
  | "gender_locked"
  | "no_visits"
  | "expired"
  | "invalid_qr"
  | "rate_limited";
export type PayoutStatus = "pending" | "paid";
export type Role = "admin" | "member";

export type Gender = "male" | "female";
export type ReferralStatus = "pending" | "converted" | "expired";
export type PaymentMethod = "card" | "cliq" | "apple_pay" | "mock";
export type PaymentStatus =
  | "pending"
  | "succeeded"
  | "failed"
  | "refunded";

export type AdminUser = {
  id: string;
  email: string | null;
  phone: string | null;
  name: string | null;
  firstName: string | null;
  lastName: string | null;
  gender: Gender | null;
  birthdate: string | null;
  role: Role;
  locale: "ar" | "en";
  avatarUrl: string | null;
  referralCode: string | null;
  invitedByUserId: string | null;
  lastActiveAt: string | null;
  createdAt: string;
  deletedAt: string | null;
};

export type AdminUserUpdate = Partial<{
  name: string;
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  gender: Gender;
  birthdate: string;
  role: Role;
  locale: "ar" | "en";
  isActive: boolean;
}>;

export type AdminSession = {
  id: string;
  deviceInfo: string | null;
  createdAt: string;
  lastUsedAt: string | null;
  expiresAt: string;
  revokedAt: string | null;
};

export type AdminReferralPersonRef = {
  id: string;
  name: string | null;
  email: string | null;
  phone: string | null;
};

export type AdminUserDetailSubscription = {
  id: string;
  tier: Tier;
  status: SubscriptionStatus;
  planId: string | null;
  planTier: Tier | null;
  planDurationMonths: number | null;
  planPriceJod: string | null;
  planMonthlyVisits: number | null;
  startsAt: string;
  expiresAt: string;
  visitsUsed: number;
  autoRenew: boolean;
  cancelledAt: string | null;
  createdAt: string;
};

export type AdminUserDetailPayment = {
  id: string;
  subscriptionId: string | null;
  subscriptionTier: Tier | null;
  amountJod: string;
  method: PaymentMethod;
  status: PaymentStatus;
  gatewayTxnId: string | null;
  processedAt: string | null;
  createdAt: string;
  meta: Record<string, unknown>;
};

export type AdminUserDetailTicket = {
  id: string;
  category: TicketCategory;
  priority: TicketPriority;
  status: TicketStatus;
  subject: string;
  createdAt: string;
  updatedAt: string;
  resolvedAt: string | null;
};

export type AdminUserDetailCheckin = {
  id: string;
  gymId: string;
  gymNameEn: string;
  gymNameAr: string;
  status: CheckinStatus;
  scannedAt: string;
  failureReason: string | null;
};

export type AdminUserDetailReferral = {
  id: string;
  invited: AdminReferralPersonRef;
  status: ReferralStatus;
  createdAt: string;
  convertedAt: string | null;
};

export type AdminUserDetailPaymentMethod = {
  method: PaymentMethod;
  count: number;
  last: Record<string, unknown> | null;
};

export type AdminUserDetailTotals = {
  totalPaidJod: string;
  subscriptionCount: number;
  hasActiveSubscription: boolean;
  activeTier: Tier | null;
  ticketCount: number;
  openTicketCount: number;
  referralCount: number;
  convertedReferralCount: number;
};

export type AdminUserDetail = {
  user: AdminUser;
  invitedBy: AdminReferralPersonRef | null;
  referralCode: string;
  referralCounts: Record<ReferralStatus, number>;
  referrals: AdminUserDetailReferral[];
  subscriptions: AdminUserDetailSubscription[];
  payments: AdminUserDetailPayment[];
  tickets: AdminUserDetailTicket[];
  recentCheckins: AdminUserDetailCheckin[];
  paymentMethods: AdminUserDetailPaymentMethod[];
  totals: AdminUserDetailTotals;
};

export type AdminCreateBody = {
  email: string;
  name: string;
  password: string;
};

export type PlanRead = {
  id: string;
  tier: Tier;
  durationMonths: number;
  priceJod: string;
  monthlyVisits: number;
  includedGymCount: number;
  featuresEn: string[];
  featuresAr: string[];
  discountPercent: string;
  isActive: boolean;
};

export type PlanUpdate = Partial<{
  priceJod: string;
  monthlyVisits: number;
  includedGymCount: number;
  featuresEn: string[];
  featuresAr: string[];
  discountPercent: string;
  isActive: boolean;
}>;

export type AdminSubscription = {
  id: string;
  userId: string;
  userEmail: string | null;
  userPhone: string | null;
  userName: string | null;
  planId: string;
  tier: Tier;
  status: SubscriptionStatus;
  startsAt: string;
  expiresAt: string;
  visitsUsed: number;
  autoRenew: boolean;
  cancelledAt: string | null;
};

/** Single subscription returned by the management mutations. Mirrors
 *  the backend AdminSubscriptionRead (no joined user fields — the UI
 *  refreshes the row from its existing context). */
export type AdminSubscriptionRead = {
  id: string;
  userId: string;
  planId: string;
  tier: Tier;
  status: SubscriptionStatus;
  startsAt: string;
  expiresAt: string;
  visitsUsed: number;
  autoRenew: boolean;
  cancelledAt: string | null;
};

export type DayPassStatus =
  | "pending"
  | "active"
  | "used"
  | "expired"
  | "refunded";

export type AudienceGender = "mixed" | "female_only" | "male_only";

export type AdminDayPassOffering = {
  id: string;
  gymId: string;
  gymNameEn: string;
  gymNameAr: string;
  gymSlug: string;
  isEnabled: boolean;
  priceJod: string;
  platformFeePct: string;
  validityHours: number;
  dailyCap: number | null;
  audienceGenderOverride: AudienceGender | null;
};

export type AdminDayPassOfferingConfigure = {
  isEnabled: boolean;
  priceJod: string;
  platformFeePct: string;
  validityHours: number;
  dailyCap: number | null;
  audienceGenderOverride: AudienceGender | null;
};

export type AdminDayPass = {
  id: string;
  userId: string;
  userName: string | null;
  userPhone: string | null;
  gymId: string;
  gymNameEn: string;
  status: DayPassStatus;
  priceJod: string;
  platformFeeJod: string;
  netAmountJod: string;
  purchasedAt: string;
  expiresAt: string;
  usedAt: string | null;
  refundedAt: string | null;
};

export type AdminCheckin = {
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

export type AdminPayout = {
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

export type AdminPayoutEntry = {
  ledgerId: string;
  checkinId: string;
  userId: string;
  userName: string | null;
  userPhone: string | null;
  scannedAt: string;
  amountJod: string;
  rateApplied: string;
};

export type AdminPayoutDetail = {
  payout: AdminPayout;
  entries: AdminPayoutEntry[];
  totalEntries: number;
  page: number;
  pageSize: number;
};

export type SystemSettings = {
  appEnv: "development" | "production";
  isDev: boolean;
  apiDomain: string;
  adminDomain: string;
  mediaUrlPrefix: string;
  maxUploadMb: number;
  providers: { kind: string; name: string }[];
  jwtAccessTtlSeconds: number;
  jwtRefreshTtlSeconds: number;
  jwtServiceTtlSeconds: number;
  adminExchangeMaxSkewSeconds: number;
  health: {
    name: string;
    ok: boolean;
    latencyMs: number | null;
    detail: string | null;
  }[];
};

export type DashboardMetrics = {
  memberCount: number;
  adminCount: number;
  gymCount: number;
  activeSubscriptions: number;
  checkinsToday: number;
  checkinsThisMonth: number;
  revenueMtdJod: string;
  revenuePreviousMonthJod: string;
  pendingPayoutTotalJod: string;
  subscriptionsByTier: Record<string, number>;
  checkinsLast7Days: { day: string; count: number }[];
  checkinsLast30Days: { day: string; count: number }[];
  revenueLast30Days: { day: string; total: string }[];
  signupsLast30Days: { day: string; count: number }[];
  openTicketCount: number;
  urgentTicketCount: number;
  expiringSubscriptionsCount: number;
  topGymsByCheckins: {
    gymId: string;
    nameEn: string;
    nameAr: string;
    count: number;
  }[];
  recentSignups: {
    id: string;
    name: string | null;
    email: string | null;
    phone: string | null;
    createdAt: string;
  }[];
  recentCheckins: {
    id: string;
    userId: string;
    userName: string | null;
    gymNameEn: string;
    gymNameAr: string;
    status: CheckinStatus;
    scannedAt: string;
  }[];
  systemHealth: { db: string; redis: string; api: string };
};

export type TicketStatus =
  | "open"
  | "in_progress"
  | "waiting_user"
  | "resolved"
  | "closed";
export type TicketPriority = "low" | "normal" | "high" | "urgent";
export type TicketCategory =
  | "bug"
  | "payment"
  | "account"
  | "gym_issue"
  | "feature"
  | "complaint"
  | "other";

export type SupportTicketListItem = {
  id: string;
  userId: string;
  userName: string | null;
  userEmail: string | null;
  userPhone: string | null;
  category: TicketCategory;
  priority: TicketPriority;
  status: TicketStatus;
  subject: string;
  assignedAdminId: string | null;
  createdAt: string;
  updatedAt: string;
  resolvedAt: string | null;
};

export type SupportTicketMessage = {
  id: string;
  ticketId: string;
  authorUserId: string;
  authorName: string | null;
  authorRole: string | null;
  body: string;
  isInternalNote: boolean;
  createdAt: string;
};

export type SupportTicketDetail = SupportTicketListItem & {
  body: string;
  meta: Record<string, unknown>;
  messages: SupportTicketMessage[];
};

export type SupportTicketStats = {
  total: number;
  open: number;
  inProgress: number;
  waitingUser: number;
  resolved: number;
  closed: number;
};

export type TicketUpdateBody = Partial<{
  status: TicketStatus;
  priority: TicketPriority;
  category: TicketCategory;
  assignedAdminId: string | null;
  clearAssignee: boolean;
}>;

export type TicketReplyBody = {
  body: string;
  isInternalNote: boolean;
};

export type BroadcastBody = {
  titleEn: string;
  titleAr: string;
  bodyEn: string;
  bodyAr: string;
  targetTier: Tier | null;
};

/** Resolve the bearer token to use for backend admin calls. Exported
 *  so service-specific SDKs (`lib/gyms.ts`, `lib/referrals.ts`,
 *  etc.) reuse a single implementation rather than redeclaring
 *  their own — drift in the token source would otherwise be three
 *  bugs to find.
 *
 *  Wrapped in React `cache()` so the session is decoded ONCE per
 *  server request, no matter how many SDK calls a render fans out.
 *  Previously every `AdminSDK.*` call (the layout's 3 sidebar badges
 *  + each page's fetches) re-ran `getServerSession` — cookie parse +
 *  JWT decrypt + callbacks — adding avoidable latency to every
 *  navigation. `cache` dedupes it within a request without leaking
 *  across requests/users. */
export const serviceToken = cache(async (): Promise<string> => {
  const session = await getServerSession(authOptions);
  const token = session?.serviceToken;
  if (!token) throw new Error("Missing admin service token.");
  return token;
});

function qs(params: Record<string, string | number | boolean | null | undefined>) {
  const parts = Object.entries(params)
    .filter(([, v]) => v !== null && v !== undefined && v !== "")
    .map(
      ([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`,
    );
  return parts.length ? `?${parts.join("&")}` : "";
}

export const AdminSDK = {
  // Metrics
  async dashboard(): Promise<DashboardMetrics> {
    return api("/api/v1/admin/metrics/overview", { token: await serviceToken() });
  },

  // System
  async settings(): Promise<SystemSettings> {
    return api("/api/v1/admin/settings", { token: await serviceToken() });
  },

  // Users
  async listUsers(params: {
    role?: Role;
    q?: string;
    includeDeleted?: boolean;
    page?: number;
    pageSize?: number;
  }): Promise<Page<AdminUser>> {
    return api(`/api/v1/admin/users${qs(params)}`, {
      token: await serviceToken(),
    });
  },
  async getUser(id: string): Promise<AdminUser> {
    return api(`/api/v1/admin/users/${id}`, { token: await serviceToken() });
  },
  async getUserDetail(id: string): Promise<AdminUserDetail> {
    return api(`/api/v1/admin/users/${id}/detail`, {
      token: await serviceToken(),
    });
  },
  async updateUser(id: string, body: AdminUserUpdate): Promise<AdminUser> {
    return api(`/api/v1/admin/users/${id}`, {
      method: "PATCH",
      body: JSON.stringify(body),
      token: await serviceToken(),
    });
  },
  async createAdmin(body: AdminCreateBody): Promise<AdminUser> {
    return api(`/api/v1/admin/users/admins`, {
      method: "POST",
      body: JSON.stringify(body),
      token: await serviceToken(),
    });
  },
  async resetAdminPassword(id: string, password: string): Promise<void> {
    return api(`/api/v1/admin/users/${id}/reset-password`, {
      method: "POST",
      body: JSON.stringify({ password }),
      token: await serviceToken(),
    });
  },
  async listUserSessions(id: string): Promise<AdminSession[]> {
    return api(`/api/v1/admin/users/${id}/sessions`, {
      token: await serviceToken(),
    });
  },
  async revokeUserSessions(id: string): Promise<void> {
    return api(`/api/v1/admin/users/${id}/revoke-sessions`, {
      method: "POST",
      token: await serviceToken(),
    });
  },

  // Plans
  async listPlans(): Promise<PlanRead[]> {
    return api(`/api/v1/admin/plans`, { token: await serviceToken() });
  },
  async updatePlan(id: string, body: PlanUpdate): Promise<PlanRead> {
    return api(`/api/v1/admin/plans/${id}`, {
      method: "PATCH",
      body: JSON.stringify(body),
      token: await serviceToken(),
    });
  },

  // Subscriptions
  async listSubscriptions(params: {
    status?: SubscriptionStatus;
    tier?: Tier;
    q?: string;
    page?: number;
    pageSize?: number;
  }): Promise<Page<AdminSubscription>> {
    return api(`/api/v1/admin/subscriptions${qs(params)}`, {
      token: await serviceToken(),
    });
  },
  async cancelSubscription(id: string): Promise<void> {
    return api(`/api/v1/admin/subscriptions/${id}/cancel`, {
      method: "POST",
      token: await serviceToken(),
    });
  },
  async extendSubscription(
    id: string,
    days: number,
  ): Promise<AdminSubscriptionRead> {
    return api(`/api/v1/admin/subscriptions/${id}/extend`, {
      method: "POST",
      body: JSON.stringify({ days }),
      token: await serviceToken(),
    });
  },
  async setSubscriptionVisits(
    id: string,
    visitsUsed: number,
  ): Promise<AdminSubscriptionRead> {
    return api(`/api/v1/admin/subscriptions/${id}/visits`, {
      method: "POST",
      body: JSON.stringify({ visitsUsed }),
      token: await serviceToken(),
    });
  },
  async changeSubscriptionTier(
    id: string,
    tier: Tier,
  ): Promise<AdminSubscriptionRead> {
    return api(`/api/v1/admin/subscriptions/${id}/tier`, {
      method: "POST",
      body: JSON.stringify({ tier }),
      token: await serviceToken(),
    });
  },
  async restoreSubscription(id: string): Promise<AdminSubscriptionRead> {
    return api(`/api/v1/admin/subscriptions/${id}/restore`, {
      method: "POST",
      token: await serviceToken(),
    });
  },
  async resumeSubscriptionPause(id: string): Promise<void> {
    return api(`/api/v1/admin/subscriptions/${id}/resume-pause`, {
      method: "POST",
      token: await serviceToken(),
    });
  },
  async compSubscription(
    userId: string,
    planId: string,
  ): Promise<AdminSubscriptionRead> {
    return api(`/api/v1/admin/subscriptions/comp`, {
      method: "POST",
      body: JSON.stringify({ userId, planId }),
      token: await serviceToken(),
    });
  },

  // Day passes
  async listDayPassOfferings(params: {
    enabled?: boolean;
    page?: number;
    pageSize?: number;
  }): Promise<Page<AdminDayPassOffering>> {
    return api(`/api/v1/admin/day-pass/offerings${qs(params)}`, {
      token: await serviceToken(),
    });
  },
  async configureDayPassOffering(
    gymId: string,
    body: AdminDayPassOfferingConfigure,
  ): Promise<AdminDayPassOffering> {
    return api(`/api/v1/admin/day-pass/offerings/${gymId}`, {
      method: "PUT",
      body: JSON.stringify(body),
      token: await serviceToken(),
    });
  },
  async listDayPasses(params: {
    status?: DayPassStatus;
    gymId?: string;
    userId?: string;
    page?: number;
    pageSize?: number;
  }): Promise<Page<AdminDayPass>> {
    return api(`/api/v1/admin/day-pass/passes${qs(params)}`, {
      token: await serviceToken(),
    });
  },
  async refundDayPass(passId: string): Promise<AdminDayPass> {
    return api(`/api/v1/admin/day-pass/passes/${passId}/refund`, {
      method: "POST",
      token: await serviceToken(),
    });
  },

  // Payments
  async refundPayment(paymentId: string): Promise<{ id: string; status: PaymentStatus }> {
    return api(`/api/v1/admin/payments/${paymentId}/refund`, {
      method: "POST",
      token: await serviceToken(),
    });
  },

  // Checkins
  async listCheckins(params: {
    gymId?: string;
    userId?: string;
    status?: CheckinStatus;
    since?: string;
    until?: string;
    page?: number;
    pageSize?: number;
  }): Promise<Page<AdminCheckin>> {
    return api(`/api/v1/admin/checkins${qs(params)}`, {
      token: await serviceToken(),
    });
  },

  // Payouts
  async listPayouts(params: {
    status?: PayoutStatus;
    gymId?: string;
    page?: number;
    pageSize?: number;
  }): Promise<Page<AdminPayout>> {
    return api(`/api/v1/admin/payouts${qs(params)}`, {
      token: await serviceToken(),
    });
  },
  async generatePayouts(periodStart: string, periodEnd: string): Promise<AdminPayout[]> {
    return api(`/api/v1/admin/payouts/generate`, {
      method: "POST",
      body: JSON.stringify({ periodStart, periodEnd }),
      token: await serviceToken(),
    });
  },
  async getPayout(id: string): Promise<AdminPayoutDetail> {
    return api(`/api/v1/admin/payouts/${id}`, {
      token: await serviceToken(),
    });
  },
  async markPayoutPaid(id: string, notes?: string): Promise<AdminPayout> {
    return api(`/api/v1/admin/payouts/${id}/mark-paid`, {
      method: "POST",
      body: JSON.stringify({ notes: notes ?? null }),
      token: await serviceToken(),
    });
  },


  // Notifications
  async broadcast(body: BroadcastBody): Promise<{ recipients: number }> {
    return api(`/api/v1/admin/notifications/broadcast`, {
      method: "POST",
      body: JSON.stringify(body),
      token: await serviceToken(),
    });
  },

  // Support
  async ticketStats(): Promise<SupportTicketStats> {
    return api(`/api/v1/admin/support/stats`, {
      token: await serviceToken(),
    });
  },
  async listTickets(params: {
    status?: TicketStatus;
    priority?: TicketPriority;
    category?: TicketCategory;
    assignedAdminId?: string;
    q?: string;
    page?: number;
    pageSize?: number;
  }): Promise<Page<SupportTicketListItem>> {
    return api(`/api/v1/admin/support/tickets${qs(params)}`, {
      token: await serviceToken(),
    });
  },
  async getTicket(id: string): Promise<SupportTicketDetail> {
    return api(`/api/v1/admin/support/tickets/${id}`, {
      token: await serviceToken(),
    });
  },
  async updateTicket(
    id: string,
    body: TicketUpdateBody,
  ): Promise<SupportTicketListItem> {
    return api(`/api/v1/admin/support/tickets/${id}`, {
      method: "PATCH",
      body: JSON.stringify(body),
      token: await serviceToken(),
    });
  },
  async replyTicket(
    id: string,
    body: TicketReplyBody,
  ): Promise<SupportTicketMessage> {
    return api(`/api/v1/admin/support/tickets/${id}/messages`, {
      method: "POST",
      body: JSON.stringify(body),
      token: await serviceToken(),
    });
  },

  // Partner-application review queue.
  async listPartnerApplications(params: {
    status?: ApplicationStatus;
    page?: number;
    pageSize?: number;
  }): Promise<Page<PartnerApplicationRead>> {
    return api(
      `/api/v1/admin/partner-applications${qs(params)}`,
      { token: await serviceToken() },
    );
  },
  async getPartnerApplication(id: string): Promise<PartnerApplicationRead> {
    return api(`/api/v1/admin/partner-applications/${id}`, {
      token: await serviceToken(),
    });
  },
  async pendingApplicationCount(): Promise<number> {
    const r = (await api(
      `/api/v1/admin/partner-applications/pending-count`,
      { token: await serviceToken() },
    )) as { pending: number };
    return r.pending;
  },
  async approvePartnerApplication(
    id: string,
    notes: string | null,
  ): Promise<PartnerApplicationRead> {
    return api(`/api/v1/admin/partner-applications/${id}/approve`, {
      method: "POST",
      body: JSON.stringify({ notes }),
      token: await serviceToken(),
    });
  },
  async rejectPartnerApplication(
    id: string,
    notes: string,
  ): Promise<PartnerApplicationRead> {
    return api(`/api/v1/admin/partner-applications/${id}/reject`, {
      method: "POST",
      body: JSON.stringify({ notes }),
      token: await serviceToken(),
    });
  },
};

export type ApplicationStatus = "pending" | "approved" | "rejected";

export type PartnerApplicationRead = {
  id: string;
  status: ApplicationStatus;
  ownerName: string;
  ownerPhone: string;
  ownerEmail: string | null;
  gymNameEn: string;
  gymNameAr: string;
  gymArea: string;
  gymAddressEn: string;
  gymAddressAr: string;
  gymLat: string;
  gymLng: string;
  gymCategory: string;
  gymAudienceGender: "mixed" | "female_only" | "male_only";
  gymPhone: string | null;
  amenities: string[];
  openingHours: Record<string, unknown>;
  logoUrl: string | null;
  photoUrls: string[];
  adminNotes: string | null;
  reviewedAt: string | null;
  approvedGymId: string | null;
  approvedOwnerUserId: string | null;
  createdAt: string;
  updatedAt: string;
};
