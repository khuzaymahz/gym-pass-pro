import Link from "next/link";
import { useTranslations } from "next-intl";
import type { ReactNode } from "react";

/// Generic panel wrapper used across the dashboard's secondary and
/// feed rows. Title + optional subtitle, optional "view all" link.
/// Server-rendered — no state. Lives under `components/dashboard/`
/// to keep the dashboard `page.tsx` skeletal.
export default function Panel({
  title,
  subtitle,
  linkHref,
  linkLabel,
  children,
  className = "",
}: {
  title: string;
  subtitle?: string;
  linkHref?: string;
  linkLabel?: string;
  children: ReactNode;
  className?: string;
}) {
  const tCommon = useTranslations("common");
  return (
    <section className={`panel p-4 ${className}`}>
      <header className="mb-3 flex items-baseline justify-between gap-2">
        <div>
          <h2 className="h2">{title}</h2>
          {subtitle ? (
            <p className="mt-0.5 text-[11.5px] text-muted">{subtitle}</p>
          ) : null}
        </div>
        {linkHref ? (
          <Link
            href={linkHref}
            className="text-[11.5px] text-muted hover:text-lime"
          >
            {linkLabel ?? tCommon("viewAll")} →
          </Link>
        ) : null}
      </header>
      {children}
    </section>
  );
}
