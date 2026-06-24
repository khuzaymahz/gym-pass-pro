import { useTranslations } from "next-intl";
import type { ReactNode } from "react";

import StatusPill from "@/components/StatusPill";
import EmptyRow from "@/components/users/EmptyRow";
import { formatDate } from "@/components/users/format";
import type {
  AdminUserDetailSubscription,
  SubscriptionStatus,
} from "@/lib/sdk";

function subTone(status: SubscriptionStatus): "ok" | "warn" | "bad" | "mute" {
  switch (status) {
    case "active":
      return "ok";
    case "pending":
      return "warn";
    case "cancelled":
      return "bad";
    case "expired":
    default:
      return "mute";
  }
}

/// Subscriptions + tier history table for the user detail page.
/// Pure presentation — caller passes the array; this component
/// renders the table or an empty row.
export default function SubscriptionsSection({
  subscriptions,
  renderActions,
}: {
  subscriptions: AdminUserDetailSubscription[];
  /// Optional per-row management control (injected by the page so this
  /// component stays presentation-only). When omitted the table is
  /// read-only, matching its original behaviour.
  renderActions?: (sub: AdminUserDetailSubscription) => ReactNode;
}) {
  const t = useTranslations("users.detail");
  const tStatuses = useTranslations("subscriptionStatuses");
  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="h2">{t("subsHistory")}</h2>
        <span className="text-[11px] text-muted">
          {subscriptions.length === 1
            ? t("records", { count: subscriptions.length })
            : t("recordsPlural", { count: subscriptions.length })}
        </span>
      </div>
      <div className="panel overflow-hidden">
        {subscriptions.length === 0 ? (
          <EmptyRow label={t("noSubs")} />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>{t("tier")}</th>
                <th>{t("status")}</th>
                <th>{t("window")}</th>
                <th className="num">{t("visits")}</th>
                <th className="num">{t("price")}</th>
                <th>{t("autoRenew")}</th>
                {renderActions ? <th className="w-0" /> : null}
              </tr>
            </thead>
            <tbody>
              {subscriptions.map((s) => (
                <tr key={s.id}>
                  <td>
                    <div className="flex flex-col">
                      <span className="font-medium capitalize">{s.tier}</span>
                      {s.planDurationMonths ? (
                        <span className="text-[11px] text-muted">
                          {t("monthsPlan", { count: s.planDurationMonths })}
                        </span>
                      ) : null}
                    </div>
                  </td>
                  <td>
                    <StatusPill tone={subTone(s.status)}>
                      {tStatuses(s.status)}
                    </StatusPill>
                  </td>
                  <td className="num text-muted">
                    {formatDate(s.startsAt)} → {formatDate(s.expiresAt)}
                    {s.cancelledAt ? (
                      <div className="text-[11px] text-red-300">
                        {t("cancelled", { date: formatDate(s.cancelledAt) })}
                      </div>
                    ) : null}
                  </td>
                  <td className="num">
                    {s.visitsUsed}
                    {s.planMonthlyVisits ? ` / ${s.planMonthlyVisits}` : ""}
                  </td>
                  <td className="num">{s.planPriceJod ?? "—"}</td>
                  <td>
                    {s.autoRenew ? (
                      <span className="text-lime">on</span>
                    ) : (
                      <span className="text-muted">off</span>
                    )}
                  </td>
                  {renderActions ? (
                    <td className="text-right">{renderActions(s)}</td>
                  ) : null}
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}
