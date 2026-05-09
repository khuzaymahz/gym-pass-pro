import { useTranslations } from "next-intl";

/// 30-bar daily strip used for the signup chart on the dashboard.
/// Pads the head with zeros when fewer than 30 points are passed in
/// so the strip width is stable regardless of data range.
export default function BarStrip({ points }: { points: number[] }) {
  const t = useTranslations("dashboard.feeds");
  const slots = 30;
  const series =
    points.length >= slots
      ? points.slice(-slots)
      : [...Array(slots - points.length).fill(0), ...points];
  const total = series.reduce((a, b) => a + b, 0);
  if (total === 0) {
    return (
      <div className="flex h-16 items-center justify-center rounded-md border border-dashed border-line">
        <p className="label">{t("noSignups")}</p>
      </div>
    );
  }
  const max = Math.max(...series, 1);
  return (
    <div className="flex h-16 items-end gap-[2px]">
      {series.map((p, i) => (
        <div
          key={i}
          className={`flex-1 rounded-sm ${p === 0 ? "bg-line" : "bg-lime/80"}`}
          style={{ height: `${Math.max(6, (p / max) * 100)}%` }}
          title={`${p}`}
        />
      ))}
    </div>
  );
}
