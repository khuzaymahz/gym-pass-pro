/// Shared formatting helpers for the user-detail page sub-components.
/// Kept in plain TypeScript (no client/server boundary) so any of
/// the presentational sections can pull them in without ceremony.

export function formatDate(value: string | null | undefined): string {
  if (!value) return "—";
  try {
    return new Date(value).toLocaleDateString("en-GB", {
      day: "2-digit",
      month: "short",
      year: "numeric",
    });
  } catch {
    return value.slice(0, 10);
  }
}

export function formatDateTime(value: string | null | undefined): string {
  if (!value) return "—";
  try {
    return new Date(value).toLocaleString("en-GB", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return value.slice(0, 16).replace("T", " ");
  }
}
