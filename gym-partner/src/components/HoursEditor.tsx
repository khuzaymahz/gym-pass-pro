"use client";

import { useEffect, useMemo, useState } from "react";
import { useTranslations } from "next-intl";

/// Editor for the opening-hours payload. Produces one of the three
/// shapes the rest of the app already understands (see Sidebar's
/// `OpeningHoursShape`):
///
///   - `{ "24_7": true }`                                — always-open
///   - `{ open: "06:00", close: "23:00" }`               — same every day
///   - `{ mon: {...}, tue: {closed: true}, ... }`        — per-day
///
/// Switching modes carries forward sensible defaults so the partner
/// never lands on an empty form when they flip from "24/7" to "per
/// day": each empty day grabs the current uniform window (or 06:00 →
/// 23:00 if there's no uniform either).

type DaySpec = { open: string; close: string; closed: boolean };
const DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"] as const;
type Day = (typeof DAYS)[number];

type Mode = "always_open" | "uniform" | "per_day";

type Props = {
  /** Initial opaque payload from the backend. */
  initial: Record<string, unknown> | null | undefined;
  /** Reported up to the parent every time the partner changes anything. */
  onChange: (next: Record<string, unknown>) => void;
};

const DEFAULT_OPEN = "06:00";
const DEFAULT_CLOSE = "23:00";

function inferMode(value: Record<string, unknown> | null | undefined): Mode {
  if (!value) return "uniform";
  if (value["24_7"] === true) return "always_open";
  const hasDayKey = DAYS.some((d) => d in value);
  if (hasDayKey) return "per_day";
  // Everything else — the legacy single-window `{open, close}` shape
  // and any unrecognised payload — defaults to the uniform editor.
  return "uniform";
}

function readUniform(value: Record<string, unknown> | null | undefined): {
  open: string;
  close: string;
} {
  const open = typeof value?.open === "string" ? (value.open as string) : DEFAULT_OPEN;
  const close = typeof value?.close === "string" ? (value.close as string) : DEFAULT_CLOSE;
  return { open, close };
}

function readPerDay(
  value: Record<string, unknown> | null | undefined,
  fallback: { open: string; close: string },
): Record<Day, DaySpec> {
  const out = {} as Record<Day, DaySpec>;
  for (const d of DAYS) {
    const raw = (value?.[d] ?? null) as Record<string, unknown> | null;
    if (raw && raw.closed === true) {
      out[d] = { open: fallback.open, close: fallback.close, closed: true };
    } else if (raw && typeof raw.open === "string" && typeof raw.close === "string") {
      out[d] = { open: raw.open, close: raw.close, closed: false };
    } else {
      out[d] = { open: fallback.open, close: fallback.close, closed: false };
    }
  }
  return out;
}

export function HoursEditor({ initial, onChange }: Props) {
  const t = useTranslations("profile.hours");
  const tDays = useTranslations("profile.hours.days");

  const [mode, setMode] = useState<Mode>(() => inferMode(initial));
  const [uniform, setUniform] = useState(() => readUniform(initial));
  const [perDay, setPerDay] = useState<Record<Day, DaySpec>>(() =>
    readPerDay(initial, readUniform(initial)),
  );

  // Reduce three pieces of state into the single payload the backend
  // wants. Memoised so we don't rebuild on unrelated rerenders.
  const payload = useMemo<Record<string, unknown>>(() => {
    if (mode === "always_open") return { "24_7": true };
    if (mode === "uniform") return { open: uniform.open, close: uniform.close };
    const out: Record<string, unknown> = {};
    for (const d of DAYS) {
      const spec = perDay[d];
      out[d] = spec.closed
        ? { closed: true }
        : { open: spec.open, close: spec.close };
    }
    return out;
  }, [mode, uniform, perDay]);

  // Bubble the payload up on every change. Parent owns the
  // controlled-state contract with the form action. `onChange` is
  // intentionally not in the dep list — parents that pass a fresh
  // function each render would loop us forever, and the contract is
  // "call me whenever payload shifts", not "call me whenever the
  // identity of the callback shifts."
  useEffect(() => {
    onChange(payload);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [payload]);

  function switchMode(next: Mode) {
    if (next === mode) return;
    // Carry forward the partner's current values when flipping modes
    // so they don't lose what they typed.
    if (next === "per_day") {
      setPerDay((prev) => readPerDay({ ...prev }, uniform));
    }
    setMode(next);
  }

  return (
    <div className="flex flex-col gap-4">
      <ModeChips mode={mode} onSelect={switchMode} t={t} />

      {mode === "always_open" ? (
        <p className="text-[12.5px] text-muted">{t("alwaysOpenHint")}</p>
      ) : null}

      {mode === "uniform" ? (
        <UniformRow
          open={uniform.open}
          close={uniform.close}
          onOpen={(v) => setUniform((u) => ({ ...u, open: v }))}
          onClose={(v) => setUniform((u) => ({ ...u, close: v }))}
          t={t}
        />
      ) : null}

      {mode === "per_day" ? (
        <div className="flex flex-col gap-1">
          {DAYS.map((d) => (
            <PerDayRow
              key={d}
              label={tDays(d)}
              spec={perDay[d]}
              onChange={(next) => setPerDay((prev) => ({ ...prev, [d]: next }))}
              t={t}
            />
          ))}
        </div>
      ) : null}
    </div>
  );
}

function ModeChips({
  mode,
  onSelect,
  t,
}: {
  mode: Mode;
  onSelect: (m: Mode) => void;
  t: (key: string) => string;
}) {
  const items: { mode: Mode; label: string }[] = [
    { mode: "always_open", label: t("modeAlwaysOpen") },
    { mode: "uniform", label: t("modeUniform") },
    { mode: "per_day", label: t("modePerDay") },
  ];
  return (
    <div className="seg" role="radiogroup" aria-label={t("modeLabel")}>
      {items.map((item) => (
        <button
          key={item.mode}
          type="button"
          role="radio"
          aria-checked={mode === item.mode}
          className={mode === item.mode ? "is-active" : ""}
          onClick={() => onSelect(item.mode)}
        >
          {item.label}
        </button>
      ))}
    </div>
  );
}

function UniformRow({
  open,
  close,
  onOpen,
  onClose,
  t,
}: {
  open: string;
  close: string;
  onOpen: (v: string) => void;
  onClose: (v: string) => void;
  t: (key: string) => string;
}) {
  return (
    <div className="flex flex-wrap items-end gap-3">
      <label className="field min-w-[140px]">
        <span className="field-label">{t("open")}</span>
        <input
          type="time"
          className="input input-sm"
          value={open}
          onChange={(e) => onOpen(e.target.value)}
        />
      </label>
      <span className="pb-2 text-[13px] text-muted">→</span>
      <label className="field min-w-[140px]">
        <span className="field-label">{t("close")}</span>
        <input
          type="time"
          className="input input-sm"
          value={close}
          onChange={(e) => onClose(e.target.value)}
        />
      </label>
      <span className="pb-2 text-[12px] text-muted">{t("everyDayHint")}</span>
    </div>
  );
}

function PerDayRow({
  label,
  spec,
  onChange,
  t,
}: {
  label: string;
  spec: DaySpec;
  onChange: (next: DaySpec) => void;
  t: (key: string) => string;
}) {
  return (
    <div className="grid grid-cols-[100px_auto_auto_auto_1fr] items-center gap-3 rounded-md border border-line bg-surface px-3 py-2">
      <span className="text-[13px] text-paper">{label}</span>
      <label className="inline-flex items-center gap-2 text-[12.5px] text-muted">
        <input
          type="checkbox"
          checked={!spec.closed}
          onChange={(e) => onChange({ ...spec, closed: !e.target.checked })}
          className="h-4 w-4 rounded border-line bg-ink accent-accent"
        />
        {t("openToggle")}
      </label>
      <input
        type="time"
        className="input input-sm w-[110px] disabled:opacity-40"
        value={spec.open}
        disabled={spec.closed}
        onChange={(e) => onChange({ ...spec, open: e.target.value })}
        aria-label={t("open")}
      />
      <input
        type="time"
        className="input input-sm w-[110px] disabled:opacity-40"
        value={spec.close}
        disabled={spec.closed}
        onChange={(e) => onChange({ ...spec, close: e.target.value })}
        aria-label={t("close")}
      />
      <span className="text-end text-[11.5px] text-muted">
        {spec.closed ? t("closedLabel") : null}
      </span>
    </div>
  );
}
