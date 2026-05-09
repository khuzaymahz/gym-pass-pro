import { QuietFloor } from "@/components/QuietFloor";
import type { PartnerDashboardMetrics } from "@/lib/sdk-types";

/// Hour-of-day strip styled as a heat row. Backend returns hours in
/// UTC; we shift to Asia/Amman (UTC+3, no DST) so the strip lines up
/// with what the partner experiences at the gym.
export function HourStrip({
  hours,
  empty,
}: {
  hours: PartnerDashboardMetrics["hourBreakdown"];
  empty: string;
}) {
  if (hours.length === 0) {
    return <QuietFloor message={empty} small />;
  }
  const buckets = new Array<number>(24).fill(0);
  for (const { hour, count } of hours) {
    const local = (hour + 3) % 24;
    buckets[local] += count;
  }
  const max = Math.max(...buckets, 1);
  return (
    <div className="flex flex-col gap-2">
      <div className="flex h-9 items-stretch overflow-hidden rounded-md border border-line/60">
        {buckets.map((v, i) => {
          const intensity = v === 0 ? 0 : 0.18 + (v / max) * 0.82;
          return (
            <div
              key={i}
              className="flex-1 transition-colors duration-200"
              style={{
                backgroundColor: `rgba(var(--c-accent) / ${intensity.toFixed(2)})`,
              }}
              title={`${i.toString().padStart(2, "0")}:00 — ${v} check-ins`}
            />
          );
        })}
      </div>
      <div className="num flex justify-between text-[10px] text-muted">
        <span>00</span>
        <span>06</span>
        <span>12</span>
        <span>18</span>
        <span>23</span>
      </div>
    </div>
  );
}
