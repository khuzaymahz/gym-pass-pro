/// Jordanian-mobile helpers for the admin partner-login forms. Mirrors
/// gym-partner/src/lib/phone.ts, but `isValidJordanianPhone` matches the
/// BACKEND's stricter rule (`AdminPartnerService.PHONE_RE`,
/// `^\+962(7[789])\d{7}$` — prefixes 77/78/79 only), so a number that
/// passes here never 422s server-side after a gym has been created.

/// Canonicalise any common local shape (`0791234567` / `791234567` /
/// `+962791234567` / `962 79 ...`) into E.164 `+9627XXXXXXXX`. Returns
/// the input roughly unchanged when it matches no known pattern.
export function normalizeJordanianPhone(input: string): string {
  const trimmed = input.trim();
  if (!trimmed) return trimmed;
  const digits = trimmed.replace(/\D/g, "");
  if (digits.startsWith("962")) return `+${digits}`;
  if (digits.startsWith("0")) return `+962${digits.slice(1)}`;
  if (digits.length === 9 && digits.startsWith("7")) return `+962${digits}`;
  return trimmed.startsWith("+") ? trimmed : `+${digits}`;
}

/// True when the input normalises to a Jordanian mobile the backend will
/// accept: `+962` + `77|78|79` + 7 digits. Empty input returns false so
/// callers render a separate "required" message.
export function isValidJordanianPhone(input: string): boolean {
  return /^\+9627[789]\d{7}$/.test(normalizeJordanianPhone(input));
}
