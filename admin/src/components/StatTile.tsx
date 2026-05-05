import type { ReactNode } from "react";

type Tone = "default" | "ok" | "warn" | "bad" | "info";

const TONE: Record<Tone, string> = {
  default: "text-paper",
  ok: "text-lime",
  warn: "text-amber-300",
  bad: "text-red-300",
  info: "text-sky-300",
};

type StatTileProps = {
  label: string;
  value: ReactNode;
  sub?: ReactNode;
  tone?: Tone;
  unit?: string;
};

export default function StatTile({
  label,
  value,
  sub,
  tone = "default",
  unit,
}: StatTileProps) {
  return (
    <div className="stat">
      <span className="stat-label">{label}</span>
      <div className="flex items-baseline gap-1.5">
        <span className={`stat-value ${TONE[tone]}`}>{value}</span>
        {unit ? (
          <span className="text-[11px] font-medium uppercase text-muted">
            {unit}
          </span>
        ) : null}
      </div>
      {sub ? <span className="stat-delta">{sub}</span> : null}
    </div>
  );
}
