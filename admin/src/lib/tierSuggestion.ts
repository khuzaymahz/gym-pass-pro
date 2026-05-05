export type Tier = "silver" | "gold" | "platinum" | "diamond";

const TIER_ORDER: Tier[] = ["silver", "gold", "platinum", "diamond"];

/// Amenities that signal a premium facility. Spelled in lower-snake to match
/// seeded values; matching is case-insensitive and tolerant of separators.
const PREMIUM_AMENITIES = new Set<string>([
  "spa",
  "sauna",
  "steam",
  "steam_room",
  "pool",
  "swimming_pool",
  "olympic_pool",
  "recovery",
  "cryotherapy",
  "personal_trainer",
  "trainer",
  "altitude",
  "massage",
  "physio",
  "hot_tub",
  "jacuzzi",
]);

function normalizeAmenity(raw: string): string {
  return raw.trim().toLowerCase().replace(/[\s-]+/g, "_");
}

export type TierSuggestionInput = {
  perVisitRateJod?: string | number | null;
  amenities?: readonly string[] | null;
};

export type TierSuggestion = {
  tier: Tier;
  reason: string;
};

/// Classify a gym into a required-member-tier band using its per-visit rate
/// and amenity list.
///
/// Base band comes from the rate (rate ceilings chosen to bracket real
/// Amman pricing). Each premium amenity bumps the band up by half a step;
/// three premium amenities is enough to promote a gym one full tier.
export function suggestTier(input: TierSuggestionInput): TierSuggestion {
  const rate = Number(input.perVisitRateJod ?? 0) || 0;
  const amenities = (input.amenities ?? []).map(normalizeAmenity);
  const premium = amenities.filter((a) => PREMIUM_AMENITIES.has(a));

  let baseIndex: number;
  if (rate <= 2) baseIndex = 0;
  else if (rate <= 4) baseIndex = 1;
  else if (rate <= 6) baseIndex = 2;
  else baseIndex = 3;

  const bump = Math.floor(premium.length / 3);
  const finalIndex = Math.min(TIER_ORDER.length - 1, baseIndex + bump);
  const tier = TIER_ORDER[finalIndex];

  const parts: string[] = [];
  parts.push(`rate ${rate.toFixed(2)} JOD → ${TIER_ORDER[baseIndex]}`);
  if (premium.length > 0) {
    parts.push(`${premium.length} premium amenity${premium.length === 1 ? "" : "ies"}`);
  }
  if (bump > 0) {
    parts.push(`+${bump} tier bump → ${tier}`);
  }
  return { tier, reason: parts.join(" · ") };
}
