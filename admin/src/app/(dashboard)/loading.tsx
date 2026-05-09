/// Per `nextjs-best-practices` — every server-component segment
/// that fetches data needs a `loading.tsx` so the navigation feels
/// instant: Next.js streams this skeleton in immediately while the
/// data is in flight, then swaps in the real page.
///
/// Operator-tool register (CLAUDE.md memory) — quiet pulse blocks
/// matched to the typical dashboard shape, not a bespoke per-page
/// placeholder.
export default function DashboardLoading() {
  return (
    <div className="flex flex-col gap-6 py-2 motion-safe:animate-pulse">
      {/* Header — title + subtitle stand-ins. */}
      <div className="flex flex-col gap-2">
        <div className="h-3 w-24 rounded-md bg-line" />
        <div className="h-7 w-72 rounded-md bg-surface" />
      </div>

      {/* Stat tile row — six blocks matching the dashboard overview. */}
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-6">
        {Array.from({ length: 6 }, (_, i) => (
          <div
            key={i}
            className="flex flex-col gap-2 rounded-lg border border-line bg-surface p-4"
          >
            <div className="h-3 w-16 rounded bg-line" />
            <div className="h-6 w-24 rounded bg-line" />
          </div>
        ))}
      </div>

      {/* Chart row stand-ins. */}
      <div className="grid grid-cols-1 gap-3 lg:grid-cols-3">
        <div className="lg:col-span-2 panel p-4">
          <div className="mb-3 h-4 w-32 rounded bg-line" />
          <div className="h-32 w-full rounded bg-surface" />
        </div>
        <div className="panel p-4">
          <div className="mb-3 h-4 w-24 rounded bg-line" />
          <div className="h-32 w-full rounded bg-surface" />
        </div>
      </div>

      {/* Table-like list. */}
      <div className="panel overflow-hidden">
        <div className="border-b border-line p-4">
          <div className="h-4 w-32 rounded bg-line" />
        </div>
        {Array.from({ length: 5 }, (_, i) => (
          <div
            key={i}
            className="flex items-center justify-between border-b border-line px-4 py-3 last:border-b-0"
          >
            <div className="h-3 w-40 rounded bg-line" />
            <div className="h-3 w-16 rounded bg-line" />
          </div>
        ))}
      </div>
    </div>
  );
}
