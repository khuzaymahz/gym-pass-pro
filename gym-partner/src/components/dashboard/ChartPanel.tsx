import type { ReactNode } from "react";

/// Wraps a trend chart with a tracked-out title, optional subtitle, a
/// running delta pill, and a gauge-style total readout on the inline
/// end. Used for the check-in and revenue trend cards on the home
/// dashboard.
export function ChartPanel({
  title,
  subtitle,
  total,
  unit,
  delta,
  children,
}: {
  title: string;
  subtitle?: string;
  total: number | string;
  unit?: string;
  delta?: number | null;
  children: ReactNode;
}) {
  return (
    <section className="steel rounded-lg p-5">
      <header className="mb-4 flex items-baseline justify-between gap-2">
        <div>
          <h2 className="tracked text-[11.5px] text-muted">{title}</h2>
          {subtitle ? (
            <p className="mt-1 text-[12px] text-muted">{subtitle}</p>
          ) : null}
        </div>
        <div className="flex items-baseline gap-3">
          {delta != null ? <ChartDelta delta={delta} /> : null}
          <div className="flex items-baseline gap-1">
            <span className="gauge text-[28px] text-paper">{total}</span>
            {unit ? (
              <span className="tracked text-[11px] text-muted">{unit}</span>
            ) : null}
          </div>
        </div>
      </header>
      {children}
    </section>
  );
}

function ChartDelta({ delta }: { delta: number }) {
  const abs = Math.abs(delta);
  const flat = abs < 1;
  const color = flat
    ? "text-muted"
    : delta > 0
      ? "text-accent"
      : "text-red-400";
  const arrow = flat ? "—" : delta > 0 ? "▲" : "▼";
  return (
    <span className={`num text-[11px] font-medium ${color}`}>
      {arrow} {flat ? "—" : `${abs.toFixed(abs < 10 ? 1 : 0)}%`}
    </span>
  );
}
