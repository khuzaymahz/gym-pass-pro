import { redirect } from "next/navigation";
import type { ReactNode } from "react";
import { getServerSession } from "next-auth";

import { LocaleToggle } from "@/components/LocaleToggle";
import { Sidebar } from "@/components/Sidebar";
import { ThemeToggle } from "@/components/ThemeToggle";
import { authOptions } from "@/lib/auth";
import { PartnerSDK } from "@/lib/sdk";

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
  let logoUrl: string | null = null;
  try {
    const gym = await PartnerSDK.getGym();
    gymName = gym.nameEn;
    logoUrl = gym.logoUrl;
  } catch (e) {
    if (isRedirectSignal(e)) throw e;
    // tolerate transient backend hiccup; sidebar shows placeholder
  }

  return (
    <div className="flex min-h-screen bg-ink text-paper">
      <Sidebar
        gymName={gymName}
        logoUrl={logoUrl}
        phone={session.phone ?? ""}
      />
      <main className="relative flex-1 overflow-x-hidden">
        {/* System chrome cluster — locale + theme toggles as a
            single tight pair at the top-end of every dashboard
            page. Both render as 36×36 chips so the row reads as
            one control group instead of two competing affordances.
            `end-6` flips correctly under RTL so Arabic operators
            see the cluster on the left side where their eye lands
            first. The login page renders its own copy in the same
            position for visual continuity before sign-in. */}
        <div className="absolute end-6 top-6 z-10 flex items-center gap-2">
          <LocaleToggle />
          <ThemeToggle />
        </div>
        <div className="mx-auto w-full max-w-[1280px] px-10 py-8">
          {children}
        </div>
      </main>
    </div>
  );
}
