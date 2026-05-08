/// Per `nextjs-best-practices` — every server-component segment
/// that fetches data needs a `loading.tsx` so the navigation feels
/// instant: Next.js streams this skeleton in immediately while the
/// data is in flight, then swaps in the real page. Without it the
/// browser appears frozen during the round-trip to backend.
///
/// Operator-tool register (CLAUDE.md memory) — the skeleton is a
/// few neutral pulse blocks matched to the typical dashboard
/// shape, not a bespoke per-page placeholder. Fast network won't
/// see it more than a frame; slow network gets a quiet "we're
/// working" instead of a blank screen.
export default function DashboardLoading() {
  return (
    <div className="flex flex-col gap-6 py-2 motion-safe:animate-pulse">
      {/* Header — title + subtitle stand-ins. */}
      <div className="flex flex-col gap-2">
        <div className="h-3 w-24 rounded-md bg-line" />
        <div className="h-7 w-72 rounded-md bg-surface-2" />
      </div>

      {/* Stat tile row — four blocks matching the metrics overview. */}
      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        {Array.from({ length: 4 }, (_, i) => (
          <div
            key={i}
            className="flex flex-col gap-2 rounded-xl border border-line bg-surface p-4"
          >
            <div className="h-3 w-16 rounded bg-line-2" />
            <div className="h-6 w-24 rounded bg-line-2" />
          </div>
        ))}
      </div>

      {/* Table-like list. */}
      <div className="rounded-xl border border-line bg-surface">
        <div className="border-b border-line p-4">
          <div className="h-4 w-32 rounded bg-line-2" />
        </div>
        {Array.from({ length: 5 }, (_, i) => (
          <div
            key={i}
            className="flex items-center justify-between border-b border-line px-4 py-3 last:border-b-0"
          >
            <div className="h-3 w-40 rounded bg-line-2" />
            <div className="h-3 w-16 rounded bg-line-2" />
          </div>
        ))}
      </div>
    </div>
  );
}
