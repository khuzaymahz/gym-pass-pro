import { useTranslations } from "next-intl";

/// SVG area chart, no client-side dependency. Plots a normalized
/// line + filled area over a 30-day window. Empty-state when the
/// caller has no data.
export default function AreaChart({
  points,
  labels,
}: {
  points: number[];
  labels: string[];
}) {
  const tCommon = useTranslations("common");
  if (points.length === 0) {
    return (
      <div className="flex h-36 items-center justify-center rounded-md border border-dashed border-line">
        <p className="label">{tCommon("empty")}</p>
      </div>
    );
  }
  const max = Math.max(...points, 1);
  const w = 600;
  const h = 120;
  const stepX = w / Math.max(1, points.length - 1);
  const coords = points.map((p, i) => {
    const x = i * stepX;
    const y = h - (p / max) * (h - 8) - 4;
    return { x, y };
  });
  const line = coords
    .map((c, i) => `${i === 0 ? "M" : "L"}${c.x.toFixed(1)},${c.y.toFixed(1)}`)
    .join(" ");
  const area = `${line} L${w},${h} L0,${h} Z`;
  return (
    <div>
      <svg
        viewBox={`0 0 ${w} ${h}`}
        className="h-32 w-full"
        preserveAspectRatio="none"
      >
        <defs>
          <linearGradient id="areaFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#BBFB46" stopOpacity="0.22" />
            <stop offset="100%" stopColor="#BBFB46" stopOpacity="0" />
          </linearGradient>
        </defs>
        {[0.25, 0.5, 0.75].map((f) => (
          <line
            key={f}
            x1={0}
            x2={w}
            y1={h * f}
            y2={h * f}
            stroke="#1F1F23"
            strokeWidth="1"
          />
        ))}
        <path d={area} fill="url(#areaFill)" />
        <path
          d={line}
          fill="none"
          stroke="#BBFB46"
          strokeWidth="1.75"
          strokeLinejoin="round"
        />
      </svg>
      <div className="mt-2 flex justify-between text-[10.5px] text-muted num">
        <span>{labels[0]?.slice(5)}</span>
        <span>{labels[Math.floor(labels.length / 2)]?.slice(5)}</span>
        <span>{labels[labels.length - 1]?.slice(5)}</span>
      </div>
    </div>
  );
}
