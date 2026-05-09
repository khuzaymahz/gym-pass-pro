/// Empty-row stand-in shown inside a `panel` when a section's table
/// has nothing to render. Kept tiny because it's used five times on
/// the user-detail page.
export default function EmptyRow({ label }: { label: string }) {
  return <div className="px-4 py-6 text-[12.5px] text-muted">{label}</div>;
}
