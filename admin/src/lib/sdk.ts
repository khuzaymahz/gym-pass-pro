import "server-only";

import { getServerSession } from "next-auth";

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
export type CheckinStatus =
  | "success"
  | "tier_locked"
  | "no_visits"
  | "expired"
  | "invalid_qr"
  | "rate_limited";
export type PayoutStatus = "pending" | "paid";
export type Role = "admin" | "member";

export type Gender = "male" | "female";
export type ReferralStatus = "pending" | "converted" | "expired";
export type PaymentMethod = "card" | "cliq" | "apple_pay" | "mock";
export type PaymentStatus = "pending" | "succeeded" | "failed";

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
  gender: Gender;
  birthdate: string;
  role: Role;
  locale: "ar" | "en";
  isActive: boolean;
}>;

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

export type AdminAuditEntry = {
  id: string;
  actorUserId: string | null;
  actorRole: Role | null;
  action: string;
  entityType: string;
  entityId: string | null;
  diff: Record<string, unknown>;
  ipAddress: string | null;
  createdAt: string;
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

async function serviceToken(): Promise<string> {
  const session = await getServerSession(authOptions);
  const token = session?.serviceToken;
  if (!token) throw new Error("Missing admin service token.");
  return token;
}

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

  // Audit
  async listAudit(params: {
    entityType?: string;
    actorUserId?: string;
    action?: string;
    page?: number;
    pageSize?: number;
  }): Promise<Page<AdminAuditEntry>> {
    return api(`/api/v1/admin/audit${qs(params)}`, {
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
};
