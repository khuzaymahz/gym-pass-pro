/// Decorative rule-of-thirds grid painted as four hairline SVG
/// lines. `vector-effect: non-scaling-stroke` keeps the strokes 1px
/// regardless of the SVG viewport size so the grid reads the same
/// in a small dialog and a wide one.

const GRID_LINES = [33.33, 66.66] as const;
const STROKE = "rgb(255 255 255 / 0.18)";
const STROKE_WIDTH = 0.4;

export function ThirdsOverlay() {
  return (
    <svg
      className="pointer-events-none absolute inset-0 h-full w-full"
      viewBox="0 0 100 100"
      preserveAspectRatio="none"
      aria-hidden
    >
      {GRID_LINES.map((p) => (
        <line
          key={`v${p}`}
          x1={p}
          y1="0"
          x2={p}
          y2="100"
          stroke={STROKE}
          strokeWidth={STROKE_WIDTH}
          vectorEffect="non-scaling-stroke"
        />
      ))}
      {GRID_LINES.map((p) => (
        <line
          key={`h${p}`}
          x1="0"
          y1={p}
          x2="100"
          y2={p}
          stroke={STROKE}
          strokeWidth={STROKE_WIDTH}
          vectorEffect="non-scaling-stroke"
        />
      ))}
    </svg>
  );
}
