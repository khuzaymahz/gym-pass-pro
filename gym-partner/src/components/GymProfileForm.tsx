"use client";

import { useTranslations } from "next-intl";
import { useState } from "react";
import { useRouter } from "next/navigation";

import type { GymRead, GymUpdateBody } from "@/lib/sdk-types";
import { saveGymAction } from "@/app/(dashboard)/profile/actions";
import PendingButton from "@/components/PendingButton";

import { AmenitiesPicker } from "./AmenitiesPicker";

const CATEGORIES: GymUpdateBody["category"][] = [
  "gym",
  "crossfit",
  "martial",
  "yoga",
];

// Mirrors backend `schemas/gym.py::GymUpdate`. Drift here drops the
// UX hint to "you can type forever" while the backend silently 422s.
const FIELD_LIMITS = {
  name: 128,
  address: 512,
  area: 64,
  phone: 32,
} as const;

export function GymProfileForm({ gym }: { gym: GymRead }) {
  const t = useTranslations("profile");
  const tCat = useTranslations("profile.categories");
  const router = useRouter();
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState<"idle" | "ok" | "err">("idle");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  // Amenities is a controlled value — the structured picker can't
  // round-trip cleanly through a hidden form input the way the rest
  // of the simple text fields do, and treating it as state makes the
  // counter and the at-cap disable logic trivial.
  const [amenities, setAmenities] = useState<string[]>(
    () => gym.amenities ?? [],
  );

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setStatus("idle");
    setErrorMsg(null);
    const data = new FormData(event.currentTarget);
    const trimmed = (key: string): string =>
      String(data.get(key) ?? "").trim();
    const body: GymUpdateBody = {
      nameEn: trimmed("nameEn"),
      nameAr: trimmed("nameAr"),
      addressEn: trimmed("addressEn"),
      addressAr: trimmed("addressAr"),
      area: trimmed("area"),
      phone: trimmed("phone") || null,
      category: data.get("category") as GymUpdateBody["category"],
      // Pulled from controlled state, not the FormData. The picker
      // already enforces the 64-item cap, the lowercase normalization
      // and the de-duplication, so we forward the array as-is.
      amenities,
    };
    const result = await saveGymAction(body);
    setSaving(false);
    if (result.ok) {
      setStatus("ok");
      router.refresh();
    } else {
      setStatus("err");
      setErrorMsg(result.error ?? null);
    }
  }

  return (
    <form onSubmit={onSubmit} className="card flex flex-col gap-6">
      {/* SECTION: Identity — bilingual public name + address. These
          render on the member-app gym profile so they're the
          highest-stakes inputs to get right. */}
      <Section title={t("sectionIdentity")}>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Field
            label={t("nameEn")}
            name="nameEn"
            defaultValue={gym.nameEn}
            maxLength={FIELD_LIMITS.name}
            required
          />
          <Field
            label={t("nameAr")}
            name="nameAr"
            defaultValue={gym.nameAr}
            maxLength={FIELD_LIMITS.name}
            required
            dir="rtl"
          />
          <Field
            label={t("addressEn")}
            name="addressEn"
            defaultValue={gym.addressEn}
            maxLength={FIELD_LIMITS.address}
          />
          <Field
            label={t("addressAr")}
            name="addressAr"
            defaultValue={gym.addressAr}
            maxLength={FIELD_LIMITS.address}
            dir="rtl"
          />
        </div>
      </Section>

      {/* SECTION: Contact — area + phone. Phone is optional but,
          when set, members can tap-to-call from the gym detail
          page on mobile. The format hint matches the same E.164
          shape the rest of the app uses. */}
      <Section title={t("sectionContact")}>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Field
            label={t("area")}
            name="area"
            defaultValue={gym.area}
            maxLength={FIELD_LIMITS.area}
            required
            hint={t("areaHint")}
          />
          <Field
            label={t("phone")}
            name="phone"
            defaultValue={gym.phone ?? ""}
            dir="ltr"
            maxLength={FIELD_LIMITS.phone}
            hint={t("phoneHint")}
            placeholder="+962 7X XXX XXXX"
          />
        </div>
      </Section>

      {/* SECTION: Classification — category drives the explore-tab
          filter chip, tier is locked to the partner-team's
          commercial decision. */}
      <Section title={t("sectionClassification")}>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <label className="field">
            <span className="field-label">{t("category")}</span>
            <select
              name="category"
              className="select input-sm"
              defaultValue={gym.category}
            >
              {CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {tCat(c as string)}
                </option>
              ))}
            </select>
            <span className="field-hint">{t("categoryHint")}</span>
          </label>
          <label className="field">
            <span className="field-label">{t("tier")}</span>
            <input
              className="input input-sm"
              value={gym.requiredTier}
              disabled
            />
            <span className="field-hint">{t("tierLocked")}</span>
          </label>
        </div>
      </Section>

      {/* SECTION: Amenities — the structured picker. Replaces the
          old comma-separated free-text field; backed by a 64-item
          cap that mirrors `GymUpdate.amenities` at the schema level. */}
      <Section title={t("sectionAmenities")}>
        <AmenitiesPicker value={amenities} onChange={setAmenities} />
      </Section>

      <div className="flex items-center justify-end gap-3 border-t border-line pt-4">
        {status === "ok" ? (
          <span className="text-[12px] text-accent">{t("saved")}</span>
        ) : null}
        {status === "err" ? (
          <span className="text-[12px] text-red-400">
            {errorMsg ?? t("error")}
          </span>
        ) : null}
        <PendingButton
          pending={saving}
          pendingLabel={t("saving")}
          idleLabel={t("save")}
        />
      </div>
    </form>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="flex flex-col gap-3">
      <h3 className="text-[13px] font-semibold uppercase tracking-wide text-muted">
        {title}
      </h3>
      {children}
    </section>
  );
}

function Field({
  label,
  name,
  defaultValue,
  dir,
  maxLength,
  required,
  placeholder,
  hint,
}: {
  label: string;
  name: string;
  defaultValue?: string;
  dir?: "ltr" | "rtl";
  maxLength?: number;
  required?: boolean;
  placeholder?: string;
  hint?: string;
}) {
  return (
    <label className="field">
      <span className="field-label">{label}</span>
      <input
        className="input input-sm"
        name={name}
        defaultValue={defaultValue}
        dir={dir}
        maxLength={maxLength}
        required={required}
        placeholder={placeholder}
      />
      {hint ? <span className="field-hint">{hint}</span> : null}
    </label>
  );
}
