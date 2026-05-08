type Tone = "default" | "ok" | "warn" | "bad";

export function StatTile({
  label,
  value,
  unit,
  sub,
  tone = "default",
}: {
  label: string;
  value: string | number;
  unit?: string;
  sub?: string;
  tone?: Tone;
}) {
  const valueClass =
    tone === "ok"
      ? "text-accent"
      : tone === "warn"
        ? "text-amber-400"
        : tone === "bad"
          ? "text-red-400"
          : "text-paper";
  return (
    <div className="stat">
      <span className="stat-label">{label}</span>
      <div className="flex items-baseline gap-1">
        <span className={`stat-value ${valueClass}`}>{value}</span>
        {unit ? (
          <span className="text-[10.5px] font-medium uppercase text-muted">
            {unit}
          </span>
        ) : null}
      </div>
      {sub ? <span className="stat-delta">{sub}</span> : null}
    </div>
  );
}
