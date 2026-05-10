"use client";

import { useTranslations } from "next-intl";
import { useState } from "react";

/// Mirror of `gym-partner/src/components/AmenitiesPicker.tsx`. The
/// admin and partner portals operate on the same backend gym record,
/// so they share the preset vocabulary, the cap (64), and the custom-
/// entry rules. Keep this file in sync with the partner portal —
/// drift means an amenity a partner adds via their portal might not
/// show its localized label when an admin edits the same gym.
const PRESETS: { value: string; group: "basics" | "popular" }[] = [
  { value: "wifi", group: "basics" },
  { value: "lockers", group: "basics" },
  { value: "showers", group: "basics" },
  { value: "changing_rooms", group: "basics" },
  { value: "parking", group: "basics" },
  { value: "towels", group: "basics" },
  { value: "water_fountain", group: "basics" },
  { value: "ac", group: "basics" },
  { value: "free_weights", group: "basics" },
  { value: "cardio_machines", group: "basics" },
  { value: "sauna", group: "popular" },
  { value: "pool", group: "popular" },
  { value: "steam_room", group: "popular" },
  { value: "group_classes", group: "popular" },
  { value: "personal_training", group: "popular" },
  { value: "kids_area", group: "popular" },
  { value: "women_only_area", group: "popular" },
  { value: "prayer_room", group: "popular" },
  { value: "juice_bar", group: "popular" },
  { value: "wheelchair_access", group: "popular" },
];

const PRESET_VALUES = new Set(PRESETS.map((p) => p.value));

const MAX_AMENITIES = 64; // mirrors backend `GymUpdate.amenities` cap
const MAX_CUSTOM_LENGTH = 48;

export function AmenitiesPicker({
  value,
  onChange,
}: {
  value: string[];
  onChange: (next: string[]) => void;
}) {
  const t = useTranslations("amenities");
  const [customInput, setCustomInput] = useState("");

  const selected = new Set(value);
  const customs = value.filter((v) => !PRESET_VALUES.has(v));

  function toggle(val: string): void {
    if (selected.has(val)) {
      onChange(value.filter((v) => v !== val));
      return;
    }
    if (value.length >= MAX_AMENITIES) return;
    onChange([...value, val]);
  }

  function addCustom(): void {
    const cleaned = customInput.trim().toLowerCase().replace(/,/g, "");
    if (!cleaned) return;
    if (selected.has(cleaned)) {
      setCustomInput("");
      return;
    }
    if (value.length >= MAX_AMENITIES) return;
    onChange([...value, cleaned]);
    setCustomInput("");
  }

  function removeAmenity(val: string): void {
    onChange(value.filter((v) => v !== val));
  }

  const basics = PRESETS.filter((p) => p.group === "basics");
  const popular = PRESETS.filter((p) => p.group === "popular");
  const atMax = value.length >= MAX_AMENITIES;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-3">
        <span className="field-label">{t("label")}</span>
        <span className="text-[11px] text-muted">
          {t("count", { current: value.length, max: MAX_AMENITIES })}
        </span>
      </div>
      <p className="text-[12px] text-muted">{t("subtitle")}</p>

      <PresetGroup
        label={t("basics")}
        items={basics}
        selected={selected}
        atMax={atMax}
        onToggle={toggle}
      />
      <PresetGroup
        label={t("popular")}
        items={popular}
        selected={selected}
        atMax={atMax}
        onToggle={toggle}
      />

      <div className="flex flex-col gap-2 border-t border-line pt-3">
        <span className="field-label">{t("customLabel")}</span>
        <div className="flex gap-2">
          <input
            type="text"
            className="input input-sm flex-1"
            placeholder={t("customPlaceholder")}
            value={customInput}
            onChange={(e) => setCustomInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                addCustom();
              }
            }}
            maxLength={MAX_CUSTOM_LENGTH}
            disabled={atMax}
          />
          <button
            type="button"
            className="btn-ghost btn-sm"
            onClick={addCustom}
            disabled={!customInput.trim() || atMax}
          >
            {t("customAdd")}
          </button>
        </div>
        {customs.length > 0 ? (
          <div className="flex flex-wrap gap-1.5">
            {customs.map((c) => (
              <span
                key={c}
                className="inline-flex items-center gap-1.5 rounded-full border border-line bg-surface px-2.5 py-0.5 text-[12px] text-paper"
              >
                <span dir="ltr">{c}</span>
                <button
                  type="button"
                  onClick={() => removeAmenity(c)}
                  aria-label={t("customRemove", { value: c })}
                  title={t("customRemove", { value: c })}
                  className="-me-1 inline-flex h-4 w-4 items-center justify-center rounded-full text-muted transition-colors hover:bg-line/40 hover:text-paper"
                >
                  ×
                </button>
              </span>
            ))}
          </div>
        ) : null}
        <span className="field-hint">{t("customHint")}</span>
      </div>
    </div>
  );
}

function PresetGroup({
  label,
  items,
  selected,
  atMax,
  onToggle,
}: {
  label: string;
  items: { value: string }[];
  selected: Set<string>;
  atMax: boolean;
  onToggle: (val: string) => void;
}) {
  const t = useTranslations("amenities.presets");
  return (
    <div className="flex flex-col gap-1.5">
      <span className="field-label">{label}</span>
      <div className="grid grid-cols-2 gap-1.5 sm:grid-cols-3 lg:grid-cols-4">
        {items.map(({ value }) => {
          const checked = selected.has(value);
          const disabled = !checked && atMax;
          return (
            <label
              key={value}
              className={`inline-flex cursor-pointer items-center gap-2 rounded-md border bg-surface px-2.5 py-1.5 text-[12.5px] transition-colors ${
                checked
                  ? "border-accent text-paper"
                  : "border-line text-muted hover:border-line-2 hover:text-paper"
              } ${disabled ? "cursor-not-allowed opacity-50" : ""}`}
            >
              <input
                type="checkbox"
                checked={checked}
                disabled={disabled}
                onChange={() => onToggle(value)}
                className="h-4 w-4 shrink-0 rounded border-line bg-ink accent-accent"
              />
              <span className="truncate">{t(value)}</span>
            </label>
          );
        })}
      </div>
    </div>
  );
}
