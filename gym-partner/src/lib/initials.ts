/// Derive a 1–2 character avatar fallback from a gym name. Used as the
/// placeholder inside the logo chip when a gym hasn't uploaded a logo
/// yet (Sidebar status card + the profile LogoPanel both render it).
///
/// - Empty / whitespace-only name → "?"
/// - Single word → its first two letters ("Powerhouse" → "PO")
/// - Two+ words → first letter of the first two words ("Iron Temple" → "IT")
export function makeInitials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
