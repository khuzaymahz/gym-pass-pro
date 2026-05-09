import Link from "next/link";
import { useTranslations } from "next-intl";

import StatusPill from "@/components/StatusPill";
import type { DashboardMetrics } from "@/lib/sdk";

/// Amber strip that surfaces "needs attention" counts: urgent
/// tickets, open tickets, expiring subscriptions. Hidden when there
/// is nothing pressing — handled by the parent page (this component
/// only renders when at least one count is > 0).
export default function AttentionStrip({ m }: { m: DashboardMetrics }) {
  const t = useTranslations("dashboard");
  const tAttn = useTranslations("dashboard.attention");

  const items: {
    label: string;
    value: number;
    tone: "ok" | "warn" | "bad";
    href: string;
  }[] = [];
  if (m.urgentTicketCount > 0)
    items.push({
      label: tAttn("urgentTickets"),
      value: m.urgentTicketCount,
      tone: "bad",
      href: "/support?priority=urgent",
    });
  if (m.openTicketCount > 0)
    items.push({
      label: tAttn("openTickets"),
      value: m.openTicketCount,
      tone: "warn",
      href: "/support?status=open",
    });
  if (m.expiringSubscriptionsCount > 0)
    items.push({
      label: tAttn("expiringSubs"),
      value: m.expiringSubscriptionsCount,
      tone: "warn",
      href: "/subscriptions",
    });

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-amber-400/20 bg-amber-400/[0.04] px-4 py-2.5">
      <div className="flex flex-wrap items-center gap-2">
        <span className="label text-amber-300/90">{t("needsAttention")}</span>
        {items.map((it) => (
          <Link
            key={it.label}
            href={it.href}
            className="inline-flex items-center gap-1.5 text-[12.5px] text-paper hover:underline"
          >
            <StatusPill tone={it.tone} withDot={false}>
              <span className="num font-semibold">{it.value}</span>
              <span className="ml-1 opacity-80">{it.label}</span>
            </StatusPill>
          </Link>
        ))}
      </div>
      <Link href="/support" className="btn-secondary btn-sm">
        {t("openQueue")} →
      </Link>
    </div>
  );
}
