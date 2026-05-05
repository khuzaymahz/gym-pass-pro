import Link from "next/link";
import type { ReactNode } from "react";

type EmptyStateProps = {
  title: string;
  hint?: ReactNode;
  action?: { href: string; label: string };
};

export default function EmptyState({ title, hint, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center gap-2 border-y border-line py-10 text-center">
      <p className="text-[13px] font-medium text-paper">{title}</p>
      {hint ? (
        <p className="max-w-sm text-[12px] text-muted">{hint}</p>
      ) : null}
      {action ? (
        <Link href={action.href} className="btn-secondary btn-sm mt-2">
          {action.label}
        </Link>
      ) : null}
    </div>
  );
}
