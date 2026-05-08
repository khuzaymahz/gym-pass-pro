"use client";

import { useTranslations } from "next-intl";
import { useState } from "react";
import { useRouter } from "next/navigation";

import type { GymRead, GymUpdateBody } from "@/lib/sdk";
import { saveGymAction } from "@/app/(dashboard)/profile/actions";

const CATEGORIES: GymUpdateBody["category"][] = [
  "gym",
  "crossfit",
  "martial",
  "yoga",
];

export function GymProfileForm({ gym }: { gym: GymRead }) {
  const t = useTranslations("profile");
  const router = useRouter();
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState<"idle" | "ok" | "err">("idle");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setStatus("idle");
    setErrorMsg(null);
    const data = new FormData(event.currentTarget);
    const body: GymUpdateBody = {
      nameEn: String(data.get("nameEn") ?? ""),
      nameAr: String(data.get("nameAr") ?? ""),
      addressEn: String(data.get("addressEn") ?? ""),
      addressAr: String(data.get("addressAr") ?? ""),
      area: String(data.get("area") ?? ""),
      phone: String(data.get("phone") ?? "") || null,
      category: data.get("category") as GymUpdateBody["category"],
      amenities: String(data.get("amenities") ?? "")
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
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
    <form onSubmit={onSubmit} className="card flex flex-col gap-4">
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <Field label={t("nameEn")} name="nameEn" defaultValue={gym.nameEn} />
        <Field label={t("nameAr")} name="nameAr" defaultValue={gym.nameAr} />
        <Field
          label={t("addressEn")}
          name="addressEn"
          defaultValue={gym.addressEn}
        />
        <Field
          label={t("addressAr")}
          name="addressAr"
          defaultValue={gym.addressAr}
        />
        <Field label={t("area")} name="area" defaultValue={gym.area} />
        <Field
          label={t("phone")}
          name="phone"
          defaultValue={gym.phone ?? ""}
          dir="ltr"
        />
        <label className="field">
          <span className="field-label">{t("category")}</span>
          <select
            name="category"
            className="select input-sm"
            defaultValue={gym.category}
          >
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
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

      <Field
        label={t("amenities")}
        name="amenities"
        defaultValue={gym.amenities.join(", ")}
      />

      <div className="flex items-center justify-end gap-3">
        {status === "ok" ? (
          <span className="text-[12px] text-accent">{t("saved")}</span>
        ) : null}
        {status === "err" ? (
          <span className="text-[12px] text-red-400">
            {errorMsg ?? t("error")}
          </span>
        ) : null}
        <button
          type="submit"
          className="btn-primary btn-sm"
          disabled={saving}
        >
          {saving ? t("saving") : t("save")}
        </button>
      </div>
    </form>
  );
}

function Field({
  label,
  name,
  defaultValue,
  dir,
}: {
  label: string;
  name: string;
  defaultValue?: string;
  dir?: "ltr";
}) {
  return (
    <label className="field">
      <span className="field-label">{label}</span>
      <input
        className="input input-sm"
        name={name}
        defaultValue={defaultValue}
        dir={dir}
      />
    </label>
  );
}
