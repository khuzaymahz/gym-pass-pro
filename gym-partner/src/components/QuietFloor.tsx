/// "Floor's quiet" empty state. Replaces the generic "No data."
/// fallback in the dashboard panels with a line-art barbell + a
/// gym-voiced message. Single colour (muted), single stroke — the
/// drawing has to feel like it belongs on the same metal plate as
/// the rest of the dashboard, not a stock illustration.

export function QuietFloor({
  message,
  small,
}: {
  message: string;
  /** Tighter variant used inside compact panels (Tier mix, Hour mix,
   *  Recent check-ins). The chart panels use the regular variant. */
  small?: boolean;
}) {
  return (
    <div
      className={`flex flex-col items-center justify-center gap-2 text-center ${
        small ? "py-5" : "py-8"
      }`}
    >
      <Barbell size={small ? 32 : 44} />
      <p className="text-[12px] text-muted">{message}</p>
    </div>
  );
}

function Barbell({ size }: { size: number }) {
  return (
    <svg
      viewBox="0 0 64 24"
      width={size * 2}
      height={size}
      fill="none"
      stroke="currentColor"
      strokeWidth="1.25"
      strokeLinecap="round"
      strokeLinejoin="round"
      className="text-line-2"
      aria-hidden
    >
      {/* bar */}
      <line x1="14" y1="12" x2="50" y2="12" />
      {/* left plates */}
      <rect x="6" y="6" width="3" height="12" rx="0.5" />
      <rect x="10" y="3" width="3" height="18" rx="0.5" />
      {/* right plates */}
      <rect x="51" y="3" width="3" height="18" rx="0.5" />
      <rect x="55" y="6" width="3" height="12" rx="0.5" />
    </svg>
  );
}
