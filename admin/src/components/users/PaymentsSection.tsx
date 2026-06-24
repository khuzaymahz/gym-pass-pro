import { useTranslations } from "next-intl";
import type { ReactNode } from "react";

import StatusPill from "@/components/StatusPill";
import EmptyRow from "@/components/users/EmptyRow";
import { formatDateTime } from "@/components/users/format";
import type {
  AdminUserDetailPayment,
  AdminUserDetailPaymentMethod,
  PaymentMethod,
  PaymentStatus,
} from "@/lib/sdk";

function payTone(status: PaymentStatus): "ok" | "warn" | "bad" | "mute" {
  switch (status) {
    case "succeeded":
      return "ok";
    case "pending":
      return "warn";
    case "refunded":
      return "mute";
    case "failed":
    default:
      return "bad";
  }
}

function methodSummaryDescription(
  entry: AdminUserDetailPaymentMethod,
): string | null {
  const last = entry.last;
  if (!last) return null;
  if (entry.method === "cliq") {
    const alias = typeof last.alias === "string" ? last.alias : null;
    const phone = typeof last.phone === "string" ? last.phone : null;
    return alias ?? phone ?? null;
  }
  if (entry.method === "card") {
    const brand = typeof last.brand === "string" ? last.brand : null;
    const last4 = typeof last.last4 === "string" ? last.last4 : null;
    if (brand && last4) return `${brand.toUpperCase()} •• ${last4}`;
    if (last4) return `•• ${last4}`;
    return brand ?? null;
  }
  return null;
}

function paymentMetaSummary(
  method: PaymentMethod,
  meta: Record<string, unknown>,
): string | null {
  if (method === "cliq") {
    const alias = typeof meta.alias === "string" ? meta.alias : null;
    const phone = typeof meta.phone === "string" ? meta.phone : null;
    return alias ?? phone ?? null;
  }
  if (method === "card") {
    const brand = typeof meta.brand === "string" ? meta.brand : null;
    const last4 = typeof meta.last4 === "string" ? meta.last4 : null;
    if (brand && last4) return `${brand.toUpperCase()} •• ${last4}`;
    if (last4) return `•• ${last4}`;
    return brand ?? null;
  }
  return null;
}

/// Payments table + saved payment-methods cards. Server-rendered.
export default function PaymentsSection({
  payments,
  paymentMethods,
  renderActions,
}: {
  payments: AdminUserDetailPayment[];
  paymentMethods: AdminUserDetailPaymentMethod[];
  /// Optional per-row action (e.g. refund), injected by the page so
  /// this component stays presentation-only.
  renderActions?: (payment: AdminUserDetailPayment) => ReactNode;
}) {
  const t = useTranslations("users.detail");
  const tStatuses = useTranslations("paymentStatuses");
  const tMethods = useTranslations("paymentMethods");
  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="h2">{t("payments")}</h2>
        <span className="text-[11px] text-muted">
          {payments.length === 1
            ? t("records", { count: payments.length })
            : t("recordsPlural", { count: payments.length })}
        </span>
      </div>

      {paymentMethods.length > 0 ? (
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          {paymentMethods.map((m) => (
            <div key={m.method} className="panel p-3">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-medium uppercase tracking-[0.04em] text-muted">
                  {tMethods(m.method)}
                </span>
                <span className="text-[11px] text-muted num">
                  ×{m.count}
                </span>
              </div>
              <div className="mt-1 text-[13px] text-paper">
                {methodSummaryDescription(m) ?? (
                  <span className="text-muted">—</span>
                )}
              </div>
            </div>
          ))}
        </div>
      ) : null}

      <div className="panel overflow-hidden">
        {payments.length === 0 ? (
          <EmptyRow label={t("noPayments")} />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>{t("when")}</th>
                <th>{t("method")}</th>
                <th>{t("detail")}</th>
                <th>{t("tier")}</th>
                <th>{t("status")}</th>
                <th className="num">{t("amount")}</th>
                {renderActions ? <th className="w-0" /> : null}
              </tr>
            </thead>
            <tbody>
              {payments.map((p) => (
                <tr key={p.id}>
                  <td className="num text-muted">
                    {formatDateTime(p.processedAt ?? p.createdAt)}
                  </td>
                  <td>{tMethods(p.method)}</td>
                  <td className="text-muted">
                    {paymentMetaSummary(p.method, p.meta) ?? (
                      <span className="text-muted">—</span>
                    )}
                  </td>
                  <td className="capitalize">{p.subscriptionTier ?? "—"}</td>
                  <td>
                    <StatusPill tone={payTone(p.status)}>
                      {tStatuses(p.status)}
                    </StatusPill>
                  </td>
                  <td className="num">{p.amountJod} JOD</td>
                  {renderActions ? (
                    <td className="text-right">{renderActions(p)}</td>
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
