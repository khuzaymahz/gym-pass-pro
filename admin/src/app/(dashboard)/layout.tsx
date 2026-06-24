import { redirect } from "next/navigation";
import type { ReactNode } from "react";
import { getServerSession } from "next-auth";

import { OfflineBanner } from "@/components/OfflineBanner";
import Sidebar from "@/components/Sidebar";
import { ToastProvider } from "@/components/ui/Toast";
import { authOptions } from "@/lib/auth";
import { AdminSDK } from "@/lib/sdk";

export const dynamic = "force-dynamic";

export default async function DashboardLayout({
  children,
}: {
  children: ReactNode;
}) {
  const session = await getServerSession(authOptions);
  if (!session?.user?.email) {
    redirect("/login");
  }
  // A session without a serviceToken means the JWT-callback exchange
  // failed on refresh and the dashboard would 401 every call. Bounce
  // back to /login so the user re-authenticates instead of staring at
  // a wall of broken widgets. The serviceExpiresAt sanity-check
  // catches the slow-clock case where the token is technically
  // present but already expired (`exp < now`).
  if (!session.serviceToken) {
    redirect("/login");
  }
  if (
    session.serviceExpiresAt &&
    Date.parse(session.serviceExpiresAt) <= Date.now()
  ) {
    redirect("/login");
  }

  let openTicketCount = 0;
  let urgentTicketCount = 0;
  let pendingApplicationCount = 0;
  // Fire the three sidebar-badge fetches in parallel. Previously
  // these ran sequentially in two `await` chains: a slow backend
  // turned a 200ms shell render into 600ms+. `Promise.allSettled`
  // keeps the fault-tolerance of the original (each fetch may
  // 500 on a pre-prod hiccup without dragging the others down).
  const [statsResult, urgentResult, applicationsResult] = await Promise.allSettled([
    AdminSDK.ticketStats(),
    AdminSDK.listTickets({ priority: "urgent", page: 1, pageSize: 1 }),
    AdminSDK.pendingApplicationCount(),
  ]);
  if (statsResult.status === "fulfilled") {
    const s = statsResult.value;
    openTicketCount = s.open + s.inProgress + s.waitingUser;
  }
  if (urgentResult.status === "fulfilled") {
    urgentTicketCount = urgentResult.value.total;
  }
  if (applicationsResult.status === "fulfilled") {
    pendingApplicationCount = applicationsResult.value;
  }
  // applicationsResult may reject on a backend image without the
  // partner-applications endpoint; the badge silently hides
  // (count stays 0).

  return (
    <div className="flex min-h-screen flex-col bg-ink text-paper">
      <OfflineBanner />
      <div className="flex flex-1">
        <Sidebar
          email={session.user.email}
          openTicketCount={openTicketCount}
          urgentTicketCount={urgentTicketCount}
          pendingApplicationCount={pendingApplicationCount}
        />
        <main className="min-w-0 flex-1 overflow-x-hidden">
          {/* pt clears the fixed mobile top bar (lg: the persistent rail
              takes its place, so normal top padding returns). */}
          <div className="fade-in mx-auto w-full max-w-[1280px] px-4 pb-12 pt-[72px] sm:px-6 lg:px-10 lg:pt-8">
            <ToastProvider>{children}</ToastProvider>
          </div>
        </main>
      </div>
    </div>
  );
}
