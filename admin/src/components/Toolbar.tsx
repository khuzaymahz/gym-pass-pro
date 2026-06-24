import type { ReactNode } from "react";

type ToolbarProps = {
  title: string;
  description?: string;
  count?: { label: string; value: number | string };
  actions?: ReactNode;
};

/**
 * Page header. Density-first with a premium read: a short amber rail
 * anchors the title (brand presence without a heavy banner), the count
 * sits in a tabular chip, and the primary action lives top-right.
 */
export default function Toolbar({
  title,
  description,
  count,
  actions,
}: ToolbarProps) {
  return (
    <header className="mb-6 flex items-start justify-between gap-4 border-b border-line pb-5">
      <div className="min-w-0">
        <div className="flex items-center gap-3">
          {/* Brand rail — a 3px amber bar keyed to the title height. */}
          <span
            aria-hidden
            className="h-[22px] w-[3px] shrink-0 rounded-full bg-accent shadow-[0_0_10px_rgba(234,179,8,0.5)]"
          />
          <h1 className="h1">{title}</h1>
          {count ? (
            <span className="num inline-flex items-center gap-1.5 rounded-full border border-line bg-surface px-2.5 py-0.5 text-[11.5px] text-muted shadow-[var(--shadow-sm),var(--highlight-top)]">
              <span className="font-semibold text-paper">{count.value}</span>
              {count.label}
            </span>
          ) : null}
        </div>
        {description ? (
          <p className="mt-1.5 max-w-2xl pl-[15px] text-[12.5px] leading-relaxed text-muted">
            {description}
          </p>
        ) : null}
      </div>
      {actions ? (
        <div className="flex shrink-0 items-center gap-2">{actions}</div>
      ) : null}
    </header>
  );
}
