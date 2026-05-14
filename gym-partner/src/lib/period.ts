/// Period-selector vocabulary shared between the (client)
/// PeriodSelector component and the (server) dashboard page. Has to
/// live in a non-client module — Next.js doesn't reliably forward
/// non-function exports across the "use client" boundary, so a
/// server component importing `PERIOD_PRESETS` from the selector
/// directly gets a proxy reference that fails `.includes(...)` at
/// runtime.

export type PeriodPreset = "today" | "week" | "30d" | "90d" | "custom";

export const PERIOD_PRESETS: readonly PeriodPreset[] = [
  "today",
  "week",
  "30d",
  "90d",
  "custom",
];

export function isPeriodPreset(value: string | undefined): value is PeriodPreset {
  return (
    value === "today" ||
    value === "week" ||
    value === "30d" ||
    value === "90d" ||
    value === "custom"
  );
}
