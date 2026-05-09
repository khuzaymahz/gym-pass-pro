const TIER_ORDER = ["silver", "gold", "platinum", "diamond"] as const;

/// Active subscriptions split by tier. Pure presentation — caller
/// passes the totals dict + total active count; the row shows label,
/// progress bar, count, and percentage.
export default function TierBreakdown({
  tiers,
  total,
}: {
  tiers: Record<string, number>;
  total: number;
}) {
  return (
    <ul className="flex flex-col gap-2.5">
      {TIER_ORDER.map((tier) => {
        const count = tiers[tier] ?? 0;
        const pct = total > 0 ? (count / total) * 100 : 0;
        return (
          <li key={tier} className="flex items-center gap-3 text-[12px]">
            <span className="w-14 capitalize text-muted">{tier}</span>
            <div className="relative h-1 flex-1 overflow-hidden rounded-full bg-line">
              <div
                className="absolute inset-y-0 left-0 rounded-full bg-lime"
                style={{ width: `${pct}%` }}
              />
            </div>
            <span className="num w-10 text-right text-paper">{count}</span>
            <span className="num w-10 text-right text-[11px] text-muted">
              {pct.toFixed(0)}%
            </span>
          </li>
        );
      })}
    </ul>
  );
}
