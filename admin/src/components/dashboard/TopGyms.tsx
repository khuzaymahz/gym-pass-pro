import Link from "next/link";
import { useTranslations } from "next-intl";

/// Top-N gym table by check-ins. Server-rendered. Each row links to
/// /gyms/[id] so the operator can drill into a hot venue.
export default function TopGyms({
  gyms,
}: {
  gyms: { gymId: string; nameEn: string; count: number }[];
}) {
  const t = useTranslations("dashboard.feeds");
  if (gyms.length === 0) {
    return (
      <p className="py-4 text-center text-[12px] text-muted">
        {t("topGymsEmpty")}
      </p>
    );
  }
  const max = Math.max(...gyms.map((g) => g.count), 1);
  return (
    <ul className="flex flex-col gap-2">
      {gyms.slice(0, 6).map((g, i) => {
        const pct = (g.count / max) * 100;
        return (
          <li key={g.gymId}>
            <Link
              href={`/gyms/${g.gymId}`}
              className="group flex items-center gap-2.5 text-[12.5px]"
            >
              <span className="num w-5 text-right text-[11px] text-muted">
                {i + 1}
              </span>
              <span className="min-w-0 flex-1 truncate text-paper group-hover:text-lime">
                {g.nameEn}
              </span>
              <span className="relative hidden h-1 w-16 overflow-hidden rounded-full bg-line md:block">
                <span
                  className="absolute inset-y-0 left-0 rounded-full bg-lime/80"
                  style={{ width: `${pct}%` }}
                />
              </span>
              <span className="num w-8 text-right text-paper">{g.count}</span>
            </Link>
          </li>
        );
      })}
    </ul>
  );
}
