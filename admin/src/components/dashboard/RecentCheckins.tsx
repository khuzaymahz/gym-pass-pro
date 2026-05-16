import { useTranslations } from "next-intl";

import StatusPill from "@/components/StatusPill";
import type { CheckinStatus } from "@/lib/sdk";

const CHECKIN_TONE: Record<CheckinStatus, "ok" | "warn" | "bad" | "mute"> = {
  success: "ok",
  tier_locked: "warn",
  // `gender_locked` shares the same operator semantics as
  // `tier_locked` — both are "access correctly denied at the door,"
  // not a system fault. Same warn tone keeps the dashboard's
  // recent-activity stream readable without inflating bad-tone
  // signals.
  gender_locked: "warn",
  no_visits: "warn",
  expired: "bad",
  invalid_qr: "bad",
  rate_limited: "bad",
};

function formatTime(iso: string): string {
  try {
    return new Date(iso).toLocaleString("en-GB", {
      day: "2-digit",
      month: "short",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

function toneToDot(tone: "ok" | "warn" | "bad" | "info" | "mute") {
  switch (tone) {
    case "ok":
      return "bg-lime";
    case "warn":
      return "bg-amber-300";
    case "bad":
      return "bg-red-400";
    case "info":
      return "bg-sky-400";
    default:
      return "bg-muted";
  }
}

type CheckinRow = {
  id: string;
  userId: string;
  userName: string | null;
  gymNameEn: string;
  status: CheckinStatus;
  scannedAt: string;
};

/// Recent-scans feed on the dashboard. Each row shows a tone dot +
/// member name + gym + status pill + relative-ish time.
export default function RecentCheckins({
  checkins,
}: {
  checkins: CheckinRow[];
}) {
  const t = useTranslations("dashboard.feeds");
  const tStatuses = useTranslations("checkinStatuses");
  if (checkins.length === 0) {
    return (
      <p className="py-4 text-center text-[12px] text-muted">{t("noScans")}</p>
    );
  }
  return (
    <ul className="-mx-1 flex flex-col">
      {checkins.map((c) => {
        const tone = CHECKIN_TONE[c.status] ?? "mute";
        return (
          <li
            key={c.id}
            className="flex items-center gap-3 rounded-md px-1 py-2 hover:bg-line/40"
          >
            <span className={`dot ${toneToDot(tone)}`} />
            <div className="min-w-0 flex-1">
              <p className="truncate text-[13px] text-paper">
                {c.userName ?? c.userId.slice(0, 8)}
              </p>
              <p className="truncate text-[11.5px] text-muted">{c.gymNameEn}</p>
            </div>
            <span className="shrink-0">
              <StatusPill tone={tone} withDot={false}>
                {tStatuses(c.status)}
              </StatusPill>
            </span>
            <span className="num shrink-0 text-[11px] text-muted">
              {formatTime(c.scannedAt)}
            </span>
          </li>
        );
      })}
    </ul>
  );
}
