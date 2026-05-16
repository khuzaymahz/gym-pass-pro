/// Canonicalise a Jordanian mobile number entered in any of the
/// usual local shapes (`0791234567` / `791234567` / `+962791234567`
/// / `962791234567`) into strict E.164 `+9627XXXXXXXX`.
///
/// Previously this logic was duplicated between `app/login/page.tsx`
/// and `app/join/JoinForm.tsx` with subtly different rules: the
/// login form stripped non-digits and tried multiple prefixes; the
/// join form did a single `.replace(/^0/, "")` only. A partner
/// pasting `+962 79 ...` (with spaces) hit different normalisations
/// in the two surfaces — extracted here so both call sites agree.
///
/// Returns the input unchanged when the shape doesn't match any
/// known pattern; the backend's stricter regex will surface a
/// useful error to the user instead of silently mis-formatting.
export function normalizeJordanianPhone(input: string): string {
  const trimmed = input.trim();
  if (!trimmed) return trimmed;
  const digits = trimmed.replace(/\D/g, "");
  if (digits.startsWith("962")) return `+${digits}`;
  if (digits.startsWith("0")) return `+962${digits.slice(1)}`;
  if (digits.length === 9 && digits.startsWith("7")) return `+962${digits}`;
  // Fallback: caller passed something exotic. If it already had a
  // leading `+`, preserve their intent; otherwise prefix the bare
  // digits.
  return trimmed.startsWith("+") ? trimmed : `+${digits}`;
}
