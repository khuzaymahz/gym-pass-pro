import type { ReactNode } from "react";

/// Generic instrument-panel container — tracked-out caps title above
/// an optional subtitle, with the body rendered as-is. Shared by all
/// of the dashboard's distribution cards (tier mix, hour heat strip,
/// recent check-ins) so the visual register stays consistent.
export function Panel({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
}) {
  return (
    <section className="steel rounded-lg p-5">
      <header className="mb-4">
        <h2 className="tracked text-[11.5px] text-muted">{title}</h2>
        {subtitle ? (
          <p className="mt-1 text-[12px] text-muted">{subtitle}</p>
        ) : null}
      </header>
      {children}
    </section>
  );
}
