"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import type { GymRead } from "@/lib/gyms";
import { suggestTier } from "@/lib/tierSuggestion";

type Props = {
  initial?: Partial<GymRead>;
  action: (data: Partial<GymRead>) => Promise<{ ok: boolean; error?: string }>;
  submitLabel: string;
};

// Mirrors backend `schemas/gym.py::GymBase`. Drift here drops UX
// hints to "you can type forever" while the backend silently 422s.
const FIELD_LIMITS = {
  slug: 64,
  name: 128,
  address: 512,
  area: 64,
  amenities: 256,
} as const;
const SLUG_PATTERN = "[a-z0-9-]{2,64}";

export default function GymForm({ initial, action, submitLabel }: Props) {
  const router = useRouter();
  const [state, setState] = useState<Partial<GymRead>>({
    slug: "",
    nameEn: "",
    nameAr: "",
    addressEn: "",
    addressAr: "",
    area: "",
    category: "gym",
    requiredTier: "silver",
    perVisitRateJod: "2.00",
    amenities: [],
    openingHours: { "24_7": true },
    ...initial,
  });
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError(null);
    const result = await action(state);
    setLoading(false);
    if (!result.ok) {
      setError(result.error ?? "Something went wrong.");
      return;
    }
    router.push("/gyms");
    router.refresh();
  }

  function bind<K extends keyof GymRead>(key: K) {
    return {
      value: (state[key] as string) ?? "",
      onChange: (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
        setState((s) => ({ ...s, [key]: e.target.value })),
    };
  }

  const amenitiesText = (state.amenities ?? []).join(", ");
  const suggestion = suggestTier({
    perVisitRateJod: state.perVisitRateJod,
    amenities: state.amenities,
  });
  const suggestionMatches = suggestion.tier === state.requiredTier;

  return (
    <form onSubmit={onSubmit} className="panel flex flex-col gap-4 p-4">
      <div className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
        <label className="field">
          <span className="field-label">Slug</span>
          <input
            className="input input-sm num"
            required
            maxLength={FIELD_LIMITS.slug}
            pattern={SLUG_PATTERN}
            title="Lowercase letters, digits, and hyphens (2–64 chars)"
            {...bind("slug")}
          />
        </label>
        <label className="field">
          <span className="field-label">Area</span>
          <input
            className="input input-sm"
            required
            maxLength={FIELD_LIMITS.area}
            {...bind("area")}
          />
        </label>
        <label className="field">
          <span className="field-label">Category</span>
          <select className="select input-sm" {...bind("category")}>
            {["gym", "crossfit", "martial", "yoga"].map((v) => (
              <option key={v} value={v}>
                {v}
              </option>
            ))}
          </select>
        </label>
        <label className="field">
          <span className="field-label">Name (EN)</span>
          <input
            className="input input-sm"
            required
            maxLength={FIELD_LIMITS.name}
            {...bind("nameEn")}
          />
        </label>
        <label className="field">
          <span className="field-label">Name (AR)</span>
          <input
            className="input input-sm"
            required
            dir="rtl"
            maxLength={FIELD_LIMITS.name}
            {...bind("nameAr")}
          />
        </label>
        <label className="field">
          <span className="field-label">Required tier</span>
          <div className="flex items-center gap-2">
            <select
              className="select input-sm flex-1"
              {...bind("requiredTier")}
            >
              {["silver", "gold", "platinum", "diamond"].map((v) => (
                <option key={v} value={v}>
                  {v}
                </option>
              ))}
            </select>
            <button
              type="button"
              className="btn-ghost btn-sm whitespace-nowrap"
              onClick={() =>
                setState((s) => ({ ...s, requiredTier: suggestion.tier }))
              }
              disabled={suggestionMatches}
              title={suggestion.reason}
            >
              {suggestionMatches ? "Matches" : `Suggest ${suggestion.tier}`}
            </button>
          </div>
        </label>
        <label className="field md:col-span-2 lg:col-span-3">
          <span className="field-label">Address (EN)</span>
          <input
            className="input input-sm"
            required
            maxLength={FIELD_LIMITS.address}
            {...bind("addressEn")}
          />
        </label>
        <label className="field md:col-span-2 lg:col-span-3">
          <span className="field-label">Address (AR)</span>
          <input
            className="input input-sm"
            required
            dir="rtl"
            maxLength={FIELD_LIMITS.address}
            {...bind("addressAr")}
          />
        </label>
        <label className="field">
          <span className="field-label">Latitude</span>
          <input
            className="input input-sm num"
            required
            type="number"
            step="0.000001"
            {...bind("lat")}
          />
        </label>
        <label className="field">
          <span className="field-label">Longitude</span>
          <input
            className="input input-sm num"
            required
            type="number"
            step="0.000001"
            {...bind("lng")}
          />
        </label>
        <label className="field">
          <span className="field-label">Rate (JOD / visit)</span>
          <input
            className="input input-sm num"
            required
            {...bind("perVisitRateJod")}
          />
        </label>
        <label className="field md:col-span-2 lg:col-span-3">
          <span className="field-label">
            Amenities (comma-separated, e.g. sauna, pool, spa)
          </span>
          <input
            className="input input-sm"
            value={amenitiesText}
            maxLength={FIELD_LIMITS.amenities}
            onChange={(e) =>
              setState((s) => ({
                ...s,
                amenities: e.target.value
                  .split(",")
                  .map((a) => a.trim().toLowerCase())
                  .filter(Boolean)
                  .slice(0, 64),
              }))
            }
          />
        </label>
      </div>

      <div className="flex items-center justify-between border-t border-line pt-3">
        {error ? (
          <p className="text-[12px] text-red-300">{error}</p>
        ) : (
          <p className="text-[11px] text-muted">
            Changes apply immediately. Audit log captures the before/after diff.
          </p>
        )}
        <button className="btn-primary btn-sm" disabled={loading}>
          {loading ? "Saving…" : submitLabel}
        </button>
      </div>
    </form>
  );
}
