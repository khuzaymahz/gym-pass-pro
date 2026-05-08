import { getTranslations } from "next-intl/server";

import { StatusPill } from "@/components/StatusPill";
import { Toolbar } from "@/components/Toolbar";
import { PartnerSDK } from "@/lib/sdk";

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString("en-GB", {
      day: "2-digit",
      month: "short",
      year: "numeric",
    });
  } catch {
    return iso;
  }
}

function formatJod(value: string): string {
  const num = Number.parseFloat(value);
  if (!Number.isFinite(num)) return value;
  return num.toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

export const dynamic = "force-dynamic";

export default async function PayoutsPage() {
  const t = await getTranslations("payouts");
  const tD = await getTranslations("dashboard");
  const result = await PartnerSDK.listPayouts({ pageSize: 50 });

  return (
    <section className="flex flex-col gap-6">
      <Toolbar title={t("title")} description={t("subtitle")} />

      <div className="panel overflow-hidden">
        {result.items.length === 0 ? (
          <p className="p-8 text-center text-[12.5px] text-muted">
            {t("noPayouts")}
          </p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>{t("period")}</th>
                <th className="num">{t("amount")}</th>
                <th className="num">{t("entries")}</th>
                <th>{t("status")}</th>
                <th>{t("paidAt")}</th>
              </tr>
            </thead>
            <tbody>
              {result.items.map((p) => (
                <tr key={p.id}>
                  <td className="num text-[12.5px]">
                    {formatDate(p.periodStart)} → {formatDate(p.periodEnd)}
                  </td>
                  <td className="num">
                    {formatJod(p.totalAmountJod)}{" "}
                    <span className="text-[10.5px] uppercase text-muted">
                      {tD("jod")}
                    </span>
                  </td>
                  <td className="num">{p.entryCount}</td>
                  <td>
                    <StatusPill tone={p.status === "paid" ? "ok" : "warn"}>
                      {t(p.status)}
                    </StatusPill>
                  </td>
                  <td className="num text-[12.5px] text-muted">
                    {p.paidAt ? formatDate(p.paidAt) : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}
