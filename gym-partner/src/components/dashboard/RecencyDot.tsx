/// A 2px dot whose colour reflects how recent a check-in is.
/// - <60s old → animated lime ping (a check-in just happened)
/// - <24h old → solid lime (still "today")
/// - older → muted line colour
///
/// Pure presentational — accepts an ISO string and computes age at
/// render time. This means the dot doesn't update past 60s without
/// a re-render; that's fine because the dashboard layout's
/// `RealtimeBridge` triggers `router.refresh()` on every backend
/// event, which gives us a fresh render before the staleness
/// matters in practice.
export function RecencyDot({ scannedAt }: { scannedAt: string }) {
  const ageMs = Date.now() - new Date(scannedAt).getTime();
  if (!Number.isFinite(ageMs)) {
    return <span className="dot bg-line" aria-hidden />;
  }
  if (ageMs < 60_000) {
    return (
      <span
        className="relative inline-flex h-2 w-2 shrink-0"
        aria-label="just now"
      >
        <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent opacity-60" />
        <span className="relative inline-flex h-2 w-2 rounded-full bg-accent" />
      </span>
    );
  }
  if (ageMs < 24 * 60 * 60_000) {
    return <span className="dot bg-accent" aria-hidden />;
  }
  return <span className="dot bg-line-2" aria-hidden />;
}
