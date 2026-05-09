import { QuietFloor } from "@/components/QuietFloor";

const TIER_ORDER = ["silver", "gold", "platinum", "diamond"] as const;

/// Horizontal bars showing what fraction of the last-30-days check-ins
/// came from each tier. Empty cohort → quiet-floor message; otherwise
/// the bars normalise to either the explicit `total` (dashboard's
/// 30-day count) or the sum of the input map when total is unset.
export function TierBreakdown({
  tiers,
  total,
  empty,
}: {
  tiers: Record<string, number>;
  total: number;
  empty: string;
}) {
  const sum = Object.values(tiers).reduce((a, b) => a + b, 0);
  if (sum === 0) {
    return <QuietFloor message={empty} small />;
  }
  const denom = total > 0 ? total : sum;
  return (
    <ul className="flex flex-col gap-2.5">
      {TIER_ORDER.map((tier) => {
        const count = tiers[tier] ?? 0;
        const pct = denom > 0 ? (count / denom) * 100 : 0;
        return (
          <li key={tier} className="flex items-center gap-3 text-[12px]">
            <span className="tracked w-16 text-[10px] text-muted">{tier}</span>
            <div className="relative h-1.5 flex-1 overflow-hidden rounded-full bg-line">
              <div
                className="absolute inset-y-0 left-0 rounded-full bg-paper/45 transition-[width] duration-700 ease-out"
                style={{ width: `${pct}%` }}
              />
            </div>
            <span className="num w-10 text-right text-paper">{count}</span>
            <span className="num w-10 text-right text-[10.5px] text-muted">
              {pct.toFixed(0)}%
            </span>
          </li>
        );
      })}
    </ul>
  );
}
