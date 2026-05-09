import Link from "next/link";
import { useTranslations } from "next-intl";

import StatusPill from "@/components/StatusPill";
import EmptyRow from "@/components/users/EmptyRow";
import { formatDate } from "@/components/users/format";
import type {
  AdminReferralPersonRef,
  AdminUserDetailReferral,
  ReferralStatus,
} from "@/lib/sdk";

function referralTone(status: ReferralStatus): "ok" | "warn" | "mute" {
  if (status === "converted") return "ok";
  if (status === "pending") return "warn";
  return "mute";
}

function MiniStat({
  label,
  value,
  tone,
}: {
  label: string;
  value: number;
  tone: "ok" | "warn" | "mute";
}) {
  const toneClass =
    tone === "ok"
      ? "text-lime"
      : tone === "warn"
        ? "text-amber-300"
        : "text-paper";
  return (
    <div className="flex flex-col gap-0.5">
      <span className="text-[10.5px] font-medium uppercase tracking-[0.04em] text-muted">
        {label}
      </span>
      <span className={`text-[18px] font-semibold num ${toneClass}`}>
        {value}
      </span>
    </div>
  );
}

/// Referral side panel: code, share link, three mini-stats, the
/// "invited by" link, and a table of invited friends.
export default function ReferralPanel({
  code,
  counts,
  invitedBy,
  referrals,
}: {
  code: string;
  counts: Record<ReferralStatus, number>;
  invitedBy: AdminReferralPersonRef | null;
  referrals: AdminUserDetailReferral[];
}) {
  const t = useTranslations("users.detail");
  const tStatuses = useTranslations("referralStatuses");
  const shareUrl = `https://gym-pass.net/invite/${code}`;
  return (
    <section className="flex flex-col gap-3">
      <h2 className="h2">{t("referrals")}</h2>

      <div className="panel flex flex-col gap-3 p-4">
        <div>
          <span className="field-label">{t("referralCode")}</span>
          <div className="mt-1 flex items-center gap-2">
            <span className="kbd text-[13px]">{code}</span>
            <span className="text-[11px] text-muted">
              {t("shareLink", { url: shareUrl })}
            </span>
          </div>
        </div>

        <div className="grid grid-cols-3 gap-2 border-t border-line pt-3">
          <MiniStat label={t("pending")} value={counts.pending} tone="warn" />
          <MiniStat
            label={tStatuses("converted")}
            value={counts.converted}
            tone="ok"
          />
          <MiniStat label={t("expired")} value={counts.expired} tone="mute" />
        </div>

        {invitedBy ? (
          <div className="border-t border-line pt-3">
            <span className="field-label">{t("invitedBy")}</span>
            <div className="mt-1 flex flex-col">
              <Link
                href={`/users/${invitedBy.id}`}
                className="text-paper hover:text-lime"
              >
                {invitedBy.name ??
                  invitedBy.email ??
                  invitedBy.phone ??
                  invitedBy.id.slice(0, 8)}
              </Link>
              <span className="text-[11px] text-muted num">
                #{invitedBy.id.slice(0, 8)}
              </span>
            </div>
          </div>
        ) : null}
      </div>

      <div className="panel overflow-hidden">
        {referrals.length === 0 ? (
          <EmptyRow label={t("noInvited")} />
        ) : (
          <table className="table table-compact">
            <thead>
              <tr>
                <th>{t("invited")}</th>
                <th>{t("status")}</th>
                <th>{t("when")}</th>
              </tr>
            </thead>
            <tbody>
              {referrals.map((r) => (
                <tr key={r.id}>
                  <td>
                    <Link
                      href={`/users/${r.invited.id}`}
                      className="text-paper hover:text-lime"
                    >
                      {r.invited.name ??
                        r.invited.email ??
                        r.invited.phone ??
                        r.invited.id.slice(0, 8)}
                    </Link>
                  </td>
                  <td>
                    <StatusPill tone={referralTone(r.status)}>
                      {tStatuses(r.status)}
                    </StatusPill>
                  </td>
                  <td className="num text-muted">
                    {formatDate(r.convertedAt ?? r.createdAt)}
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
