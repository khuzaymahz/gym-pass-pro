import { redirect } from "next/navigation";
import type { ReactNode } from "react";
import { getServerSession } from "next-auth";

import { Sidebar } from "@/components/Sidebar";
import { authOptions } from "@/lib/auth";
import { PartnerSDK } from "@/lib/sdk";

export const dynamic = "force-dynamic";

export default async function DashboardLayout({
  children,
}: {
  children: ReactNode;
}) {
  const session = await getServerSession(authOptions);
  if (!session?.serviceToken || !session?.phone) {
    redirect("/login");
  }

  // Resolve the gym name once at the shell so the sidebar shows the
  // partner what they're managing. Failure here is non-fatal — the
  // page beneath will surface the real error.
  let gymName = "—";
  try {
    const gym = await PartnerSDK.getGym();
    gymName = gym.nameEn;
  } catch {
    // tolerate transient backend hiccup; sidebar shows placeholder
  }

  return (
    <div className="flex min-h-screen bg-ink text-paper">
      <Sidebar gymName={gymName} phone={session.phone ?? ""} />
      <main className="flex-1 overflow-x-hidden">
        <div className="mx-auto w-full max-w-[1280px] px-10 py-8">
          {children}
        </div>
      </main>
    </div>
  );
}
