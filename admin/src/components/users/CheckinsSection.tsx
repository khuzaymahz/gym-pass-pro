import { useTranslations } from "next-intl";

import StatusPill from "@/components/StatusPill";
import EmptyRow from "@/components/users/EmptyRow";
import { formatDateTime } from "@/components/users/format";
import type { AdminUserDetailCheckin, CheckinStatus } from "@/lib/sdk";

function checkinTone(status: CheckinStatus): "ok" | "warn" | "bad" | "mute" {
  if (status === "success") return "ok";
  if (status === "rate_limited") return "warn";
  return "bad";
}

/// Recent check-ins table on the user detail page.
export default function CheckinsSection({
  checkins,
}: {
  checkins: AdminUserDetailCheckin[];
}) {
  const t = useTranslations("users.detail");
  const tStatuses = useTranslations("checkinStatuses");
  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="h2">{t("recentCheckins")}</h2>
        <span className="text-[11px] text-muted">
          {t("lastCount", { count: checkins.length })}
        </span>
      </div>
      <div className="panel overflow-hidden">
        {checkins.length === 0 ? (
          <EmptyRow label={t("noCheckins")} />
        ) : (
          <table className="table table-compact">
            <thead>
              <tr>
                <th>{t("when")}</th>
                <th>{t("gym")}</th>
                <th>{t("status")}</th>
                <th>{t("reason")}</th>
              </tr>
            </thead>
            <tbody>
              {checkins.map((c) => (
                <tr key={c.id}>
                  <td className="num text-muted">
                    {formatDateTime(c.scannedAt)}
                  </td>
                  <td>{c.gymNameEn}</td>
                  <td>
                    <StatusPill tone={checkinTone(c.status)}>
                      {tStatuses(c.status)}
                    </StatusPill>
                  </td>
                  <td className="text-muted">{c.failureReason ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}
