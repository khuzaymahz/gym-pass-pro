import { QuietFloor } from "@/components/QuietFloor";

/// Oscilloscope-style chart. Lane-grid background, single luminous
/// accent stroke, no gradient fill. A thin "now" tick on the last
/// data point gives the eye an anchor without competing with the
/// stroke for attention.
export function LaneChart({
  points,
  labels,
  empty,
  ariaLabel,
}: {
  points: number[];
  labels: string[];
  empty: string;
  ariaLabel?: string;
}) {
  if (points.length === 0) {
    return (
      <div className="flex h-36 items-center justify-center rounded-md border border-dashed border-line">
        <QuietFloor message={empty} small />
      </div>
    );
  }
  const max = Math.max(...points, 1);
  const min = Math.min(...points, 0);
  const w = 600;
  const h = 130;
  const pad = 6;
  const stepX = (w - pad * 2) / Math.max(1, points.length - 1);
  const coords = points.map((p, i) => {
    const x = pad + i * stepX;
    const y =
      h -
      pad -
      ((p - min) / Math.max(max - min, 1)) * (h - pad * 2);
    return { x, y };
  });
  const line = coords
    .map((c, i) => `${i === 0 ? "M" : "L"}${c.x.toFixed(1)},${c.y.toFixed(1)}`)
    .join(" ");
  const last = coords[coords.length - 1];
  return (
    <div>
      <div className="lane-grid h-32 w-full overflow-hidden rounded-md border border-line/60">
        <svg
          viewBox={`0 0 ${w} ${h}`}
          className="h-full w-full"
          preserveAspectRatio="none"
          role={ariaLabel ? "img" : "presentation"}
          aria-label={ariaLabel}
        >
          <path
            d={line}
            fill="none"
            stroke="rgb(var(--c-accent))"
            strokeWidth="1.75"
            strokeLinejoin="round"
            strokeLinecap="round"
          />
          {/* Now-tick on the most recent point. */}
          {Number.isFinite(last.x) ? (
            <>
              <line
                x1={last.x}
                x2={last.x}
                y1={pad}
                y2={h - pad}
                stroke="rgb(var(--c-accent))"
                strokeWidth="1"
                strokeDasharray="1 3"
                opacity="0.4"
              />
              <circle
                cx={last.x}
                cy={last.y}
                r="2.5"
                fill="rgb(var(--c-accent))"
                stroke="rgb(var(--c-ink))"
                strokeWidth="1.5"
              />
            </>
          ) : null}
        </svg>
      </div>
      <div className="num mt-2 flex justify-between text-[10.5px] text-muted">
        <span>{labels[0]?.slice(5)}</span>
        <span>{labels[Math.floor(labels.length / 2)]?.slice(5)}</span>
        <span>{labels[labels.length - 1]?.slice(5)}</span>
      </div>
    </div>
  );
}
