import { useTranslations } from "next-intl";

import StatusPill from "@/components/StatusPill";

/// "All systems / Degraded" pill plus per-component dots.
/// Caller passes the {db, redis, api} record from the dashboard
/// metrics endpoint; the row goes amber if any service isn't ok.
export default function HealthRow({
  health,
}: {
  health: { db: string; redis: string; api: string };
}) {
  const t = useTranslations("dashboard.health");
  const entries = Object.entries(health);
  const allOk = entries.every(([, v]) => v === "ok");
  return (
    <div className="flex items-center gap-1.5">
      <StatusPill tone={allOk ? "ok" : "bad"}>
        {allOk ? t("allSystems") : t("degraded")}
      </StatusPill>
      <div className="hidden items-center gap-2 px-2 text-[11px] text-muted md:flex">
        {entries.map(([k, v]) => {
          const ok = v === "ok";
          return (
            <span key={k} className="flex items-center gap-1">
              <span className={`dot ${ok ? "bg-lime" : "bg-red-400"}`} />
              <span className="uppercase tracking-wide">{k}</span>
            </span>
          );
        })}
      </div>
    </div>
  );
}
