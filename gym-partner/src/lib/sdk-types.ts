// Pure types + plain constants used by both Server Components (via
// `lib/sdk.ts`'s `PartnerSDK`) and Client Components (forms,
// croppers, the sidebar). Splitting them out from `lib/sdk.ts`
// matters because `lib/sdk.ts` itself is server-only — it imports
// `getServerSession`, `lib/api.ts`, and `lib/auth.ts`, which
// transitively pull in the secret-validating `env.server.ts`. If a
// client component imports a value from `lib/sdk.ts` (even just a
// constant like `DEFAULT_LOGO_ALIGNMENT`), webpack pulls the whole
// chain into the browser bundle, where the env Zod parse crashes
// at module-init because secrets aren't on `process.env`.
//
// Rule: anything a Client Component needs from "the SDK" lives in
// THIS file. Anything that talks to the backend lives in
// `lib/sdk.ts` (server-only).

export type Page<T> = {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
};

export type Tier = "silver" | "gold" | "platinum" | "diamond";
export type Category = "gym" | "crossfit" | "martial" | "yoga";
export type AudienceGender = "mixed" | "female_only" | "male_only";
export type CheckinStatus =
  | "success"
  | "tier_locked"
  | "gender_locked"
  | "no_visits"
  | "expired"
  | "invalid_qr"
  | "rate_limited";
export type PayoutStatus = "pending" | "paid";

export type LogoFit = "cover" | "contain";
export type LogoPosition = "top" | "center" | "bottom";
export type LogoAlignment = { fit: LogoFit; position: LogoPosition };

export const DEFAULT_LOGO_ALIGNMENT: LogoAlignment = {
  fit: "cover",
  position: "center",
};

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
  audienceGender: AudienceGender;
  perVisitRateJod: string;
  amenities: string[];
  openingHours: Record<string, unknown>;
  coverImageUrl: string | null;
  logoUrl: string | null;
  logoAlignment: LogoAlignment | null;
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
  audienceGender: AudienceGender;
  amenities: string[];
  openingHours: Record<string, unknown>;
  coverImageUrl: string | null;
  logoAlignment: LogoAlignment | null;
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
