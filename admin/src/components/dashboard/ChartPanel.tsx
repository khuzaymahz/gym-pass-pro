import type { ReactNode } from "react";

/// Stat-headed chart wrapper: title, subtitle, big total in the
/// header, chart body in children. Used for the check-ins and
/// revenue trend cards.
export default function ChartPanel({
  title,
  subtitle,
  total,
  unit,
  children,
  className = "",
}: {
  title: string;
  subtitle?: string;
  total: number | string;
  unit?: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`panel p-4 ${className}`}>
      <header className="mb-3 flex items-baseline justify-between gap-2">
        <div>
          <h2 className="h2">{title}</h2>
          {subtitle ? (
            <p className="mt-0.5 text-[11.5px] text-muted">{subtitle}</p>
          ) : null}
        </div>
        <div className="flex items-baseline gap-1">
          <span className="num text-[18px] font-semibold text-paper">
            {total}
          </span>
          {unit ? (
            <span className="text-[10.5px] font-medium uppercase text-muted">
              {unit}
            </span>
          ) : null}
        </div>
      </header>
      {children}
    </section>
  );
}
