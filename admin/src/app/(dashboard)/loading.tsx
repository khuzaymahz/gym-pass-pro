import { getTranslations } from "next-intl/server";

import GymLoader from "@/components/GymLoader";

/// Segment-level loading state for the whole dashboard. Next.js streams
/// this in the instant you navigate to ANY route under (dashboard),
/// while the target page renders (and, in dev, compiles on first
/// visit). The sidebar stays put; the content area shows the brand
/// loader — so a click gives immediate feedback instead of a frozen
/// page.
///
/// One file covers every section: routes without their own loading.tsx
/// bubble up to this boundary. Uses the GymPass `GymLoader` (same mark
/// as the mobile app + the inline form buttons) for a consistent
/// "we're working" signal across the console.
export default async function DashboardLoading() {
  const t = await getTranslations("common");
  return (
    <div
      className="flex min-h-[55vh] flex-col items-center justify-center gap-3"
      role="status"
      aria-live="polite"
    >
      <GymLoader size="lg" ariaLabel={t("loading")} />
      <span className="label text-muted">{t("loading")}</span>
    </div>
  );
}
