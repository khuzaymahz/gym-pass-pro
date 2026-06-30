import { redirect } from "next/navigation";
import type { ReactNode } from "react";
import { getServerSession } from "next-auth";

import { LocaleToggle } from "@/components/LocaleToggle";
import { OfflineBanner } from "@/components/OfflineBanner";
import { RealtimeBridge } from "@/components/RealtimeBridge";
import { Sidebar } from "@/components/Sidebar";
import { ThemeToggle } from "@/components/ThemeToggle";
import { authOptions } from "@/lib/auth";
import { selectedBranchId } from "@/lib/branch";
import {
  PartnerSDK,
  type LogoAlignment,
  type PartnerGymRef,
} from "@/lib/sdk";

export const dynamic = "force-dynamic";

/// `next/navigation`'s `redirect()` works by throwing an Error whose
/// `digest` starts with `NEXT_REDIRECT;...`. Catch blocks that swallow
/// errors must re-throw it or the redirect silently dies. Imported
/// from `next/dist/...` is the official internal helper but the path
/// changes between versions; checking the digest prefix ourselves is
/// stable across 14 / 15.
function isRedirectSignal(e: unknown): boolean {
  return (
    typeof e === "object" &&
    e !== null &&
    "digest" in e &&
    typeof (e as { digest?: unknown }).digest === "string" &&
    (e as { digest: string }).digest.startsWith("NEXT_REDIRECT")
  );
}

export default async function DashboardLayout({
  children,
}: {
  children: ReactNode;
}) {
  const session = await getServerSession(authOptions);
  if (!session?.serviceToken || !session?.phone) {
    redirect("/login");
  }

  // Resolve the gym name + logo once at the shell so the sidebar
  // shows the partner what they're managing. Transient backend
  // hiccups (5xx, network) are non-fatal — fall back to placeholders.
  // But the api layer's session-expired auto-redirect throws a
  // `NEXT_REDIRECT` signal that we MUST let propagate, otherwise
  // the catch swallows it and the dashboard keeps trying to render
  // with a stale token.
  let gymName = "—";
  let gymId: string | undefined;
  let logoUrl: string | null = null;
  let logoAlignment: LogoAlignment | null = null;
  let openingHours: Record<string, unknown> | null = null;
  try {
    const gym = await PartnerSDK.getGym();
    gymId = gym.id;
    gymName = gym.nameEn;
    logoUrl = gym.logoUrl;
    logoAlignment = gym.logoAlignment;
    openingHours = gym.openingHours ?? null;
  } catch (e) {
    if (isRedirectSignal(e)) throw e;
    // tolerate transient backend hiccup; sidebar shows placeholder
  }

  // Branch list for the switcher (chain owners). Tolerant of a transient
  // hiccup — a single-gym partner just gets a one-entry list the switcher
  // hides anyway. Active branch = the cookie, falling back to the gym the
  // backend resolved above (their primary).
  let branches: PartnerGymRef[] = [];
  try {
    branches = await PartnerSDK.myGyms();
  } catch (e) {
    if (isRedirectSignal(e)) throw e;
  }
  const currentBranchId = (await selectedBranchId()) ?? gymId;

  return (
    <div className="flex min-h-screen flex-col bg-ink text-paper">
      {/* Mounted once at the dashboard shell so a single WebSocket
          serves the whole portal. Calls router.refresh() on every
          backend event the partner is subscribed to (their gym's
          profile, photos, check-ins) so the UI mirrors backend
          state without manual reloads. */}
      <RealtimeBridge />
      <OfflineBanner />
      <div className="flex flex-1">
        <Sidebar
          gymName={gymName}
          logoUrl={logoUrl}
          logoAlignment={logoAlignment}
          phone={session.phone ?? ""}
          openingHours={openingHours}
          branches={branches}
          currentBranchId={currentBranchId}
        />
        <main className="relative flex-1 overflow-x-hidden">
          {/* Locale + theme toggles. The OUTER div carries `end-6` and
              inherits the page's writing direction so the cluster
              sits on the inline-end — top-right in LTR, top-left in
              RTL. The INNER div locks `dir="ltr"` to keep the two
              buttons in the same internal order (locale, then
              theme) regardless of the page's direction. Splitting
              the two roles is necessary because `end-6` on an
              element with its own `dir="ltr"` would always resolve
              to the right edge, defeating the flip. */}
          <div className="absolute end-6 top-6 z-10">
            <div dir="ltr" className="flex items-center gap-2">
              <LocaleToggle />
              <ThemeToggle />
            </div>
          </div>
          <div className="mx-auto w-full max-w-[1280px] px-10 py-8">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
}
