import { z } from "zod";

import type { ActionResult } from "@/lib/action-result";

/// Zod schemas for every server-action payload that's currently
/// reaching the SDK. Server actions DO NOT inherit form validation —
/// any field a hostile client wants to omit/coerce, will be omitted/
/// coerced. Each action wraps its body in `parseAction()` and bails
/// early with a `VALIDATION_ERROR` envelope on schema failure.
///
/// Field limits mirror backend Pydantic models so admin and FastAPI
/// stay in sync; drift here means UX hints lie and the backend 422s.

const TIER = z.enum(["silver", "gold", "platinum", "diamond"]);
const ROLE = z.enum(["admin", "member"]);
const GENDER = z.enum(["male", "female"]);
const LOCALE = z.enum(["ar", "en"]);
const CATEGORY = z.enum(["gym", "crossfit", "martial", "yoga"]);

// AdminCreateForm
export const AdminCreateBodySchema = z.object({
  email: z.string().email().max(254),
  name: z.string().min(1).max(128),
  // 12+ chars to match backend `_validate_admin_password` (the form
  // already enforces 12 client-side, but the server action is the
  // last line of defense if a client opens devtools and mutates).
  password: z.string().min(12).max(128),
});

// BroadcastForm
export const BroadcastBodySchema = z.object({
  titleEn: z.string().min(1).max(128),
  titleAr: z.string().min(1).max(128),
  bodyEn: z.string().min(1).max(2000),
  bodyAr: z.string().min(1).max(2000),
  targetTier: TIER.nullable(),
});

// PlanEditor
export const PlanUpdateBodySchema = z
  .object({
    // Decimal stays string for backend Decimal precision; just check
    // it parses as a finite number.
    priceJod: z
      .string()
      .refine((v) => Number.isFinite(Number.parseFloat(v)), {
        message: "priceJod must be numeric",
      }),
    monthlyVisits: z.number().int().min(0).max(1000),
    includedGymCount: z.number().int().min(0).max(10000),
    discountPercent: z
      .string()
      .refine((v) => Number.isFinite(Number.parseFloat(v)), {
        message: "discountPercent must be numeric",
      }),
    featuresEn: z.array(z.string().max(256)).max(64),
    featuresAr: z.array(z.string().max(256)).max(64),
    isActive: z.boolean(),
  })
  .partial();

// UserEditForm — backend `AdminUserUpdate` is fully Partial; mirror.
export const UserUpdateBodySchema = z
  .object({
    name: z.string().max(128),
    firstName: z.string().max(128),
    lastName: z.string().max(128),
    gender: GENDER,
    // ISO date 'YYYY-MM-DD'. Empty string is filtered upstream.
    birthdate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    role: ROLE,
    locale: LOCALE,
    isActive: z.boolean(),
  })
  .partial();

// GymForm — backend `GymBase` field shapes.
export const GymUpsertBodySchema = z
  .object({
    slug: z.string().regex(/^[a-z0-9-]{2,64}$/),
    nameEn: z.string().min(1).max(128),
    nameAr: z.string().min(1).max(128),
    addressEn: z.string().min(1).max(512),
    addressAr: z.string().min(1).max(512),
    area: z.string().min(1).max(64),
    phone: z.string().max(32).nullable(),
    category: CATEGORY,
    requiredTier: TIER,
    perVisitRateJod: z
      .string()
      .refine((v) => Number.isFinite(Number.parseFloat(v)), {
        message: "perVisitRateJod must be numeric",
      }),
    lat: z.string().refine((v) => Number.isFinite(Number.parseFloat(v))),
    lng: z.string().refine((v) => Number.isFinite(Number.parseFloat(v))),
    isActive: z.boolean(),
    amenities: z.array(z.string().max(48)).max(64),
    openingHours: z.record(z.unknown()),
    coverImageUrl: z.string().nullable(),
    logoUrl: z.string().nullable(),
    rating: z.string().nullable(),
    reviewCount: z.number().int().min(0),
    photoCount: z.number().int().min(0),
    id: z.string(),
  })
  .partial();

/// Run a Zod schema; on failure, return the same `runAction`
/// envelope shape with `code = "VALIDATION_ERROR"` and a flat
/// human-readable message so the client form can display it inline.
export function parseAction<T>(
  schema: z.ZodType<T>,
  raw: unknown,
):
  | { ok: true; data: T }
  | (ActionResult<never> & { ok: false; code: "VALIDATION_ERROR" }) {
  const parsed = schema.safeParse(raw);
  if (parsed.success) return { ok: true, data: parsed.data };
  const message = parsed.error.errors
    .map((e) => `${e.path.join(".") || "(root)"}: ${e.message}`)
    .join("; ");
  return {
    ok: false,
    code: "VALIDATION_ERROR",
    message: message || "Invalid input.",
  };
}
