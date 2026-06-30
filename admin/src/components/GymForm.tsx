"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useState, type ReactNode } from "react";

import { AmenitiesPicker } from "@/components/AmenitiesPicker";
import { LocationPicker } from "@/components/LocationPicker";
import { useToast } from "@/components/ui/Toast";
import type { GymRead } from "@/lib/gyms";
import { suggestTier } from "@/lib/tierSuggestion";

type Props = {
  initial?: Partial<GymRead>;
  action: (data: Partial<GymRead>) => Promise<{ ok: boolean; error?: string }>;
  submitLabel: string;
  // Optional extra sections rendered inside the form, just above the submit
  // bar — used by the create flow to fold in optional partner-login + photos
  // so a gym can be set up in one shot.
  children?: ReactNode;
};

// Mirrors backend `schemas/gym.py::GymBase`. Drift here drops UX
// hints to "you can type forever" while the backend silently 422s.
const FIELD_LIMITS = {
  slug: 64,
  name: 128,
  address: 512,
  area: 64,
} as const;
const SLUG_PATTERN = "[a-z0-9-]{2,64}";

// Mirror of the backend `_slugify` (partner_application_service.py) so the
// admin-create suggestion matches what partner auto-onboarding generates:
// lowercase, non-alphanumeric runs → "-", trimmed, capped.
function slugify(name: string): string {
  return name
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48);
}

export default function GymForm({
  initial,
  action,
  submitLabel,
  children,
}: Props) {
  const router = useRouter();
  const t = useTranslations("gyms.form");
  const tCommon = useTranslations("common");
  const { toast } = useToast();
  const [state, setState] = useState<Partial<GymRead>>({
    slug: "",
    nameEn: "",
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

  // Slug is the gym's permanent public URL handle (gym-pass.net/gyms/<slug>)
  // and the mobile by-slug lookup key, so it's immutable once a gym exists.
  // On create we auto-fill it from the English name until the operator edits
  // the slug by hand; on edit we lock the field entirely.
  const isEdit = Boolean(initial?.id);
  const [slugTouched, setSlugTouched] = useState(isEdit);

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    // Range-check the numeric fields first; surface per-field errors and
    // bail before hitting the backend if any is out of bounds.
    const nErrs: Partial<Record<NumKey, string>> = {};
    for (const k of ["lat", "lng", "perVisitRateJod"] as NumKey[]) {
      const err = rangeError(k);
      if (err) nErrs[k] = err;
    }
    if (Object.keys(nErrs).length > 0) {
      setNumErrors(nErrs);
      return;
    }
    setLoading(true);
    setError(null);
    const result = await action(state);
    setLoading(false);
    if (!result.ok) {
      const msg = result.error ?? tCommon("errorGeneric");
      setError(msg);
      toast(msg, "error");
      return;
    }
    toast(tCommon("savedToast"), "success");
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

  // Numeric fields (lat/lng/rate) are text inputs with a strict filter so
  // letters can never be typed (type="number" still lets through `e`/`+`/`-`),
  // plus a range check on blur. `signed` allows a leading minus (coordinates).
  type NumKey = "lat" | "lng" | "perVisitRateJod";
  const NUM_BOUNDS: Record<NumKey, { signed: boolean; min: number; max: number }> = {
    lat: { signed: true, min: -90, max: 90 },
    lng: { signed: true, min: -180, max: 180 },
    perVisitRateJod: { signed: false, min: 0, max: 100 },
  };
  const [numErrors, setNumErrors] = useState<Partial<Record<NumKey, string>>>(
    {},
  );

  function rangeError(key: NumKey): string | undefined {
    const raw = (state[key] as string) ?? "";
    if (raw === "" || raw === "-" || raw === ".") return undefined;
    const n = Number(raw);
    const { min, max } = NUM_BOUNDS[key];
    if (Number.isFinite(n) && n >= min && n <= max) return undefined;
    return t("hints.range", { min, max });
  }

  function bindNum(key: NumKey) {
    const { signed } = NUM_BOUNDS[key];
    const re = signed ? /^-?\d*\.?\d*$/ : /^\d*\.?\d*$/;
    return {
      value: (state[key] as string) ?? "",
      inputMode: "decimal" as const,
      "aria-invalid": numErrors[key] ? (true as const) : undefined,
      onChange: (e: React.ChangeEvent<HTMLInputElement>) => {
        const v = e.target.value;
        // Reject the keystroke entirely if it isn't a valid in-progress
        // number — the controlled value simply doesn't update.
        if (v === "" || re.test(v)) {
          setState((s) => ({ ...s, [key]: v }));
          if (numErrors[key]) setNumErrors((p) => ({ ...p, [key]: undefined }));
        }
      },
      onBlur: () => setNumErrors((p) => ({ ...p, [key]: rangeError(key) })),
    };
  }

  const suggestion = suggestTier({
    perVisitRateJod: state.perVisitRateJod,
    amenities: state.amenities,
  });
  const suggestionMatches = suggestion.tier === state.requiredTier;

  return (
    <form onSubmit={onSubmit} className="panel flex flex-col gap-4 p-4">
      <div className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
        <label className="field">
          <span className="field-label">{t("slug")}</span>
          <input
            className="input input-sm num disabled:cursor-not-allowed disabled:opacity-60"
            required
            maxLength={FIELD_LIMITS.slug}
            pattern={SLUG_PATTERN}
            title={t("slugTitle")}
            disabled={isEdit}
            value={state.slug ?? ""}
            onChange={(e) => {
              setSlugTouched(true);
              setState((s) => ({ ...s, slug: e.target.value }));
            }}
          />
          <span className="text-[11px] text-muted">
            {isEdit ? t("slugLockedHint") : t("hints.slug")}
          </span>
        </label>
        <label className="field">
          <span className="field-label">{t("area")}</span>
          <input
            className="input input-sm"
            required
            maxLength={FIELD_LIMITS.area}
            {...bind("area")}
          />
          <span className="text-[11px] text-muted">{t("hints.area")}</span>
        </label>
        <label className="field">
          <span className="field-label">{t("category")}</span>
          <select className="select input-sm" {...bind("category")}>
            {["gym", "crossfit", "martial", "yoga"].map((v) => (
              <option key={v} value={v}>
                {v}
              </option>
            ))}
          </select>
          <span className="text-[11px] text-muted">{t("hints.category")}</span>
        </label>
        <label className="field">
          <span className="field-label">{t("nameEn")}</span>
          <input
            className="input input-sm"
            required
            maxLength={FIELD_LIMITS.name}
            value={state.nameEn ?? ""}
            onChange={(e) => {
              const nameEn = e.target.value;
              // On create the slug tracks the name until the operator edits
              // the slug by hand; on edit the slug is locked, so never derive.
              setState((s) => ({
                ...s,
                nameEn,
                ...(!isEdit && !slugTouched ? { slug: slugify(nameEn) } : {}),
              }));
            }}
          />
          <span className="text-[11px] text-muted">{t("hints.nameEn")}</span>
        </label>
        <label className="field">
          <span className="field-label">{t("requiredTier")}</span>
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
              {suggestionMatches
                ? t("matches")
                : t("suggest", { tier: suggestion.tier })}
            </button>
          </div>
          <span className="text-[11px] text-muted">
            {t("hints.requiredTier")}
          </span>
        </label>
        <label className="field md:col-span-2 lg:col-span-3">
          <span className="field-label">{t("addressEn")}</span>
          <input
            className="input input-sm"
            required
            maxLength={FIELD_LIMITS.address}
            {...bind("addressEn")}
          />
          <span className="text-[11px] text-muted">{t("hints.addressEn")}</span>
        </label>
        <label className="field md:col-span-2 lg:col-span-3">
          <span className="field-label">{t("addressAr")}</span>
          <input
            className="input input-sm"
            required
            dir="rtl"
            maxLength={FIELD_LIMITS.address}
            {...bind("addressAr")}
          />
          <span className="text-[11px] text-muted">{t("hints.addressAr")}</span>
        </label>

        {/* Map picker: search or drop a pin to capture lat/lng and
            auto-fill the area via reverse geocoding. The lat/lng/area
            inputs below stay editable as a manual fallback. */}
        <div className="field md:col-span-2 lg:col-span-3">
          <span className="field-label">{t("mapLabel")}</span>
          <LocationPicker
            lat={state.lat ? Number(state.lat) : null}
            lng={state.lng ? Number(state.lng) : null}
            onPick={({ lat, lng, area }) =>
              setState((s) => ({
                ...s,
                lat: lat.toFixed(6),
                lng: lng.toFixed(6),
                ...(area ? { area } : {}),
              }))
            }
          />
        </div>

        <label className="field">
          <span className="field-label">{t("lat")}</span>
          <input
            className={`input input-sm num${numErrors.lat ? " border-red-500/60" : ""}`}
            required
            {...bindNum("lat")}
          />
          {numErrors.lat ? (
            <span className="text-[11px] text-red-300">{numErrors.lat}</span>
          ) : (
            <span className="text-[11px] text-muted">{t("hints.lat")}</span>
          )}
        </label>
        <label className="field">
          <span className="field-label">{t("lng")}</span>
          <input
            className={`input input-sm num${numErrors.lng ? " border-red-500/60" : ""}`}
            required
            {...bindNum("lng")}
          />
          {numErrors.lng ? (
            <span className="text-[11px] text-red-300">{numErrors.lng}</span>
          ) : (
            <span className="text-[11px] text-muted">{t("hints.lng")}</span>
          )}
        </label>
        <label className="field">
          <span className="field-label">{t("rate")}</span>
          <input
            className={`input input-sm num${numErrors.perVisitRateJod ? " border-red-500/60" : ""}`}
            required
            {...bindNum("perVisitRateJod")}
          />
          {numErrors.perVisitRateJod ? (
            <span className="text-[11px] text-red-300">
              {numErrors.perVisitRateJod}
            </span>
          ) : (
            <span className="text-[11px] text-muted">{t("hints.rate")}</span>
          )}
        </label>
      </div>

      {/* Amenities — checkbox grid + custom-entry chip list. Same
          component the partner portal uses, so the vocabulary
          (preset list, cap of 64, custom-entry rules) stays in
          lockstep across both surfaces editing the same backend
          gym record. */}
      <div className="border-t border-line pt-4">
        <AmenitiesPicker
          value={state.amenities ?? []}
          onChange={(next) => setState((s) => ({ ...s, amenities: next }))}
        />
      </div>

      {/* Active toggle — soft-delete is destructive (clears partner
          login, breaks deep links). This boolean lets an operator
          temporarily *hide* a gym from the member explore tab
          without losing the partner relationship. Mobile filters
          inactive gyms out of `/api/v1/gyms` automatically. */}
      <label className="flex items-start gap-3 border-t border-line pt-4">
        <input
          type="checkbox"
          className="mt-0.5 h-4 w-4 rounded border-line bg-ink accent-accent"
          checked={state.isActive ?? true}
          onChange={(e) =>
            setState((s) => ({ ...s, isActive: e.target.checked }))
          }
        />
        <span className="flex flex-col gap-0.5">
          <span className="field-label">{t("activeLabel")}</span>
          <span className="text-[11.5px] text-muted">
            {t("activeHint")}
          </span>
        </span>
      </label>

      {children}

      <div className="flex items-center justify-between border-t border-line pt-3">
        {error ? (
          <p className="text-[12px] text-red-300">{error}</p>
        ) : (
          <p className="text-[11px] text-muted">{t("footerHint")}</p>
        )}
        <button className="btn-primary btn-sm" disabled={loading}>
          {loading ? tCommon("saving") : submitLabel}
        </button>
      </div>
    </form>
  );
}
