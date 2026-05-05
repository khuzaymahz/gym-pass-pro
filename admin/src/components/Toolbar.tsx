import type { ReactNode } from "react";

type ToolbarProps = {
  title: string;
  description?: string;
  count?: { label: string; value: number | string };
  actions?: ReactNode;
};

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
          <h1 className="h1">{title}</h1>
          {count ? (
            <span className="inline-flex items-center gap-1.5 rounded-md border border-line bg-surface px-2 py-0.5 text-[11.5px] text-muted num">
              <span className="text-paper font-medium">{count.value}</span>
              {count.label}
            </span>
          ) : null}
        </div>
        {description ? (
          <p className="mt-1 max-w-2xl text-[12.5px] leading-relaxed text-muted">
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
