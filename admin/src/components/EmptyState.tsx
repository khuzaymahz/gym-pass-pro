import Link from "next/link";
import type { ReactNode } from "react";

type EmptyStateProps = {
  title: string;
  hint?: ReactNode;
  action?: { href: string; label: string };
};

/**
 * Empty-list placeholder. A soft inset medallion + dashed frame reads
 * as "intentionally empty" rather than "broken", matching the elevated
 * surface language without competing with real data panels.
 */
export default function EmptyState({ title, hint, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed border-line-2 bg-surface/40 px-6 py-12 text-center">
      <span
        aria-hidden
        className="flex h-10 w-10 items-center justify-center rounded-full border border-line-2 bg-surface text-muted shadow-[var(--highlight-top)]"
      >
        <svg
          viewBox="0 0 24 24"
          className="h-5 w-5"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <rect x="3" y="5" width="18" height="14" rx="2" />
          <path d="M3 10h18" />
        </svg>
      </span>
      <div className="flex flex-col gap-1">
        <p className="text-[13.5px] font-medium text-paper">{title}</p>
        {hint ? (
          <p className="mx-auto max-w-sm text-[12px] leading-relaxed text-muted">
            {hint}
          </p>
        ) : null}
      </div>
      {action ? (
        <Link href={action.href} className="btn-secondary btn-sm mt-1">
          {action.label}
        </Link>
      ) : null}
    </div>
  );
}
