/// Catalog of commitment lengths offered for every tier. Mirrors the
/// `DURATION_DISCOUNT` map in `backend/scripts/seed.py` — keep both in sync so
/// the mobile summary never quotes a price the backend won't honour.
const availableDurations = [1, 3, 6, 12];

/// Discount percentage the user earns by locking in a longer commitment.
/// Returns 0 for the monthly plan and the catalog value (5/10/15) for the
/// 3/6/12-month plans. Returns 0 for unknown durations so callers can fall
/// back safely if storage is ever restored from an older schema.
int discountPercentForDuration(int months) {
  switch (months) {
    case 3:
      return 5;
    case 6:
      return 10;
    case 12:
      return 15;
    default:
      return 0;
  }
}

/// Total price for a commitment in whole JOD.
/// Applies the discount percentage to `monthlyPrice * months` and rounds to
/// the nearest dinar — the checkout UI never renders fractional amounts.
int totalPriceForDuration(int monthlyPrice, int months) {
  final discount = discountPercentForDuration(months);
  final gross = monthlyPrice * months;
  return ((gross * (100 - discount)) / 100).round();
}

/// Pause days a (tier, duration) combination unlocks. Mirrors the matrix in
/// [SubscriptionState.pauseAllowanceDays] — kept as a pure function here so
/// the plans page can surface the perk per-duration *before* the member buys.
/// Returns 0 when the duration is shorter than 6 months (pause is a
/// long-commitment perk, not a monthly one).
int pauseAllowanceDaysFor(String tierKey, int months) {
  if (months == 6) {
    switch (tierKey) {
      case 'silver':
        return 10;
      case 'gold':
        return 12;
      case 'platinum':
        return 14;
      case 'diamond':
        return 16;
    }
  }
  if (months == 12) {
    switch (tierKey) {
      case 'silver':
        return 24;
      case 'gold':
        return 26;
      case 'platinum':
        return 28;
      case 'diamond':
        return 30;
    }
  }
  return 0;
}

/// Total pauses allowed on a commitment. 12-month plans split the allowance
/// across two separate pauses; 6-month plans get a single block.
int maxPausesFor(int months) {
  if (months == 12) return 2;
  if (months == 6) return 1;
  return 0;
}
