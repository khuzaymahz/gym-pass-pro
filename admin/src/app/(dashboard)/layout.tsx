import { redirect } from "next/navigation";
import type { ReactNode } from "react";
import { getServerSession } from "next-auth";

import Sidebar from "@/components/Sidebar";
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
  try {
    const stats = await AdminSDK.ticketStats();
    openTicketCount = stats.open + stats.inProgress + stats.waitingUser;
    const urgent = await AdminSDK.listTickets({
      priority: "urgent",
      page: 1,
      pageSize: 1,
    });
    urgentTicketCount = urgent.total;
  } catch {
    // tolerate backend hiccup in the shell
  }
  try {
    pendingApplicationCount = await AdminSDK.pendingApplicationCount();
  } catch {
    // partner-applications endpoint may not exist yet on pre-prod
    // backends running an older image; the badge just hides itself
    // when the count is 0 (default).
  }

  return (
    <div className="flex min-h-screen bg-ink text-paper">
      <Sidebar
        email={session.user.email}
        openTicketCount={openTicketCount}
        urgentTicketCount={urgentTicketCount}
        pendingApplicationCount={pendingApplicationCount}
      />
      <main className="flex-1 overflow-x-hidden">
        <div className="mx-auto w-full max-w-[1280px] px-10 py-8">
          {children}
        </div>
      </main>
    </div>
  );
}
