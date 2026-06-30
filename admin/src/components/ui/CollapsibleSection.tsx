import type { ReactNode } from "react";

/**
 * A panel-styled, collapsible section built on native `<details>`:
 * clicking the header toggles it. `<details>` keeps the body in the DOM
 * when collapsed (just hidden), so form state inside is preserved across
 * open/close — important for the gym-edit panels — and it's keyboard +
 * screen-reader accessible with zero client JS (this stays a server
 * component).
 */
export default function CollapsibleSection({
  title,
  subtitle,
  defaultOpen = false,
  badge,
  children,
}: {
  title: string;
  subtitle?: string;
  defaultOpen?: boolean;
  /** Optional trailing element in the header (e.g. a status pill). */
  badge?: ReactNode;
  children: ReactNode;
}) {
  return (
    <details className="panel group overflow-hidden" open={defaultOpen}>
      <summary className="flex cursor-pointer list-none items-center justify-between gap-3 p-4 transition-colors hover:bg-surface [&::-webkit-details-marker]:hidden">
        <div className="min-w-0">
          <h2 className="text-[14px] font-semibold text-paper">{title}</h2>
          {subtitle ? (
            <p className="mt-0.5 text-[12px] text-muted">{subtitle}</p>
          ) : null}
        </div>
        <div className="flex shrink-0 items-center gap-3">
          {badge}
          <svg
            aria-hidden
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            className="h-4 w-4 text-muted transition-transform duration-150 group-open:rotate-180"
          >
            <path d="M6 9l6 6 6-6" />
          </svg>
        </div>
      </summary>
      <div className="flex flex-col gap-4 border-t border-line p-4">
        {children}
      </div>
    </details>
  );
}
