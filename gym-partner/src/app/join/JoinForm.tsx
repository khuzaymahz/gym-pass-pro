"use client";

import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useState } from "react";

import { resolveMediaUrl } from "@/lib/media";
import { normalizeJordanianPhone } from "@/lib/phone";
import type { AudienceGender, Category } from "@/lib/sdk-types";
import {
  MAX_UPLOAD_MB,
  validateImageFile,
  type ImageValidationError,
} from "@/lib/upload";

const CATEGORIES: Category[] = ["gym", "crossfit", "martial", "yoga"];
const AUDIENCES: AudienceGender[] = ["mixed", "female_only", "male_only"];

const MAX_PHOTOS = 6;

/// Public-side partner onboarding form. Hits the backend's
/// /api/v1/partner-applications endpoints directly (no NextAuth
/// session — the applicant has no account yet). The browser also
/// handles photo uploads itself, posting each file to
/// /api/v1/partner-applications/upload and collecting the returned
/// URLs into the submit payload.
export function JoinForm() {
  const t = useTranslations("join");
  const router = useRouter();
  const apiBase =
    process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://api.gym-pass.net";

  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [logoUrl, setLogoUrl] = useState<string | null>(null);
  const [logoUploading, setLogoUploading] = useState(false);
  const [photoUrls, setPhotoUrls] = useState<string[]>([]);
  const [photoUploading, setPhotoUploading] = useState(false);

  function imageValidationMessage(err: ImageValidationError): string {
    // Mirror the backend's two reject paths into localized strings.
    // The ARB-equivalent join.errorImageType / join.errorImageSize
    // keys already exist; if they ever drift, the fallback string
    // keeps the form usable rather than blank.
    if (err === "too_large") {
      return t("errorImageSize", { max: MAX_UPLOAD_MB });
    }
    return t("errorImageType");
  }

  async function uploadFile(file: File): Promise<string> {
    // Frontend-side MIME + size check before the network call. The
    // backend's `sniff_image` is the source of truth (re-validates
    // magic bytes regardless), but failing fast here means a 5 MB
    // HEIC photo doesn't waste the operator's mobile-data uploading
    // bytes that the backend will reject on receipt.
    const reason = validateImageFile(file);
    if (reason) {
      throw new Error(imageValidationMessage(reason));
    }
    const fd = new FormData();
    fd.append("file", file);
    const res = await fetch(`${apiBase}/api/v1/partner-applications/upload`, {
      method: "POST",
      body: fd,
    });
    if (!res.ok) {
      const body = await res.json().catch(() => null);
      throw new Error(body?.error?.message ?? "Upload failed");
    }
    const json = (await res.json()) as { url: string };
    return json.url;
  }

  async function onLogoChange(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setError(null);
    setLogoUploading(true);
    try {
      const url = await uploadFile(file);
      setLogoUrl(url);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLogoUploading(false);
      event.target.value = "";
    }
  }

  async function onPhotosChange(event: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(event.target.files ?? []);
    if (files.length === 0) return;
    if (photoUrls.length + files.length > MAX_PHOTOS) {
      setError(t("errorTooManyPhotos", { max: MAX_PHOTOS }));
      return;
    }
    // Validate every file up-front so the first reject doesn't
    // partially upload its siblings.
    for (const file of files) {
      const reason = validateImageFile(file);
      if (reason) {
        setError(imageValidationMessage(reason));
        return;
      }
    }
    setError(null);
    setPhotoUploading(true);
    try {
      const urls = await Promise.all(files.map(uploadFile));
      setPhotoUrls((prev) => [...prev, ...urls]);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setPhotoUploading(false);
      event.target.value = "";
    }
  }

  function removePhoto(url: string) {
    setPhotoUrls((prev) => prev.filter((u) => u !== url));
  }

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setError(null);
    const fd = new FormData(event.currentTarget);
    const phone = String(fd.get("ownerPhone") ?? "").trim();
    const body = {
      ownerName: String(fd.get("ownerName") ?? "").trim(),
      ownerPhone: normalizeJordanianPhone(phone),
      ownerEmail: String(fd.get("ownerEmail") ?? "").trim() || null,
      password: String(fd.get("password") ?? ""),
      gymNameEn: String(fd.get("gymNameEn") ?? "").trim(),
      gymNameAr: String(fd.get("gymNameAr") ?? "").trim(),
      gymArea: String(fd.get("gymArea") ?? "").trim(),
      gymAddressEn: String(fd.get("gymAddressEn") ?? "").trim(),
      gymAddressAr: String(fd.get("gymAddressAr") ?? "").trim(),
      gymLat: Number(fd.get("gymLat") ?? 31.95),
      gymLng: Number(fd.get("gymLng") ?? 35.91),
      gymCategory: fd.get("gymCategory") as Category,
      gymAudienceGender: fd.get("gymAudienceGender") as AudienceGender,
      gymPhone: String(fd.get("gymPhone") ?? "").trim() || null,
      logoUrl,
      photoUrls,
    };
    try {
      const res = await fetch(`${apiBase}/api/v1/partner-applications`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const json = await res.json().catch(() => null);
      if (!res.ok) {
        throw new Error(json?.error?.message ?? "Submission failed");
      }
      setSubmitted(true);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      setSubmitting(false);
    }
  }

  if (submitted) {
    return (
      <div className="panel p-6">
        <h2 className="h3 mb-3">{t("thankYouTitle")}</h2>
        <p className="mb-4 text-[13.5px] leading-relaxed text-muted">
          {t("thankYouBody")}
        </p>
        <button
          type="button"
          className="btn-primary btn-sm"
          onClick={() => router.push("/login")}
        >
          {t("backToLogin")}
        </button>
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-6">
      {/* Owner section */}
      <section className="panel flex flex-col gap-4 p-5">
        <h2 className="label">{t("sectionOwner")}</h2>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
          <label className="field">
            <span className="field-label">{t("ownerName")}</span>
            <input
              name="ownerName"
              className="input input-sm"
              required
              minLength={2}
              maxLength={128}
            />
          </label>
          <label className="field">
            <span className="field-label">{t("ownerPhone")}</span>
            <input
              name="ownerPhone"
              type="tel"
              dir="ltr"
              className="input input-sm"
              required
              placeholder="+962 7X XXX XXXX"
            />
            <span className="field-hint">{t("ownerPhoneHint")}</span>
          </label>
          <label className="field">
            <span className="field-label">{t("ownerEmail")}</span>
            <input
              name="ownerEmail"
              type="email"
              className="input input-sm"
              placeholder="owner@example.com"
            />
          </label>
          <label className="field">
            <span className="field-label">{t("password")}</span>
            <input
              name="password"
              type="password"
              className="input input-sm"
              required
              minLength={8}
              maxLength={128}
            />
            <span className="field-hint">{t("passwordHint")}</span>
          </label>
        </div>
      </section>

      {/* Gym section */}
      <section className="panel flex flex-col gap-4 p-5">
        <h2 className="label">{t("sectionGym")}</h2>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
          <label className="field">
            <span className="field-label">{t("gymNameEn")}</span>
            <input
              name="gymNameEn"
              className="input input-sm"
              required
              dir="ltr"
              maxLength={128}
            />
          </label>
          <label className="field">
            <span className="field-label">{t("gymNameAr")}</span>
            <input
              name="gymNameAr"
              className="input input-sm"
              required
              maxLength={128}
            />
          </label>
          <label className="field">
            <span className="field-label">{t("gymArea")}</span>
            <input
              name="gymArea"
              className="input input-sm"
              required
              maxLength={64}
              placeholder={t("gymAreaPlaceholder")}
            />
          </label>
          <label className="field">
            <span className="field-label">{t("gymPhone")}</span>
            <input
              name="gymPhone"
              type="tel"
              dir="ltr"
              className="input input-sm"
              maxLength={32}
              placeholder="+962 6 XXX XXXX"
            />
          </label>
          <label className="field md:col-span-2">
            <span className="field-label">{t("gymAddressEn")}</span>
            <input
              name="gymAddressEn"
              className="input input-sm"
              required
              dir="ltr"
              maxLength={512}
            />
          </label>
          <label className="field md:col-span-2">
            <span className="field-label">{t("gymAddressAr")}</span>
            <input
              name="gymAddressAr"
              className="input input-sm"
              required
              maxLength={512}
            />
          </label>
          <label className="field">
            <span className="field-label">{t("gymLat")}</span>
            <input
              name="gymLat"
              type="number"
              step="0.000001"
              className="input input-sm"
              required
              defaultValue="31.95"
              placeholder="31.95"
            />
          </label>
          <label className="field">
            <span className="field-label">{t("gymLng")}</span>
            <input
              name="gymLng"
              type="number"
              step="0.000001"
              className="input input-sm"
              required
              defaultValue="35.91"
              placeholder="35.91"
            />
          </label>
          <label className="field">
            <span className="field-label">{t("category")}</span>
            <select name="gymCategory" className="select input-sm" required>
              {CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {t(`categories.${c}`)}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            <span className="field-label">{t("audience")}</span>
            <select
              name="gymAudienceGender"
              className="select input-sm"
              defaultValue="mixed"
              required
            >
              {AUDIENCES.map((a) => (
                <option key={a} value={a}>
                  {t(`audiences.${a}`)}
                </option>
              ))}
            </select>
          </label>
        </div>
        <span className="field-hint">{t("latLngHint")}</span>
      </section>

      {/* Media section */}
      <section className="panel flex flex-col gap-4 p-5">
        <h2 className="label">{t("sectionMedia")}</h2>
        <div className="flex flex-col gap-3">
          <div>
            <span className="field-label mb-1 block">{t("logo")}</span>
            <div className="flex items-center gap-3">
              {logoUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={resolveMediaUrl(logoUrl)}
                  alt=""
                  className="h-16 w-16 rounded border border-line object-cover"
                />
              ) : (
                <span className="flex h-16 w-16 items-center justify-center rounded border border-dashed border-line-2 text-[10px] text-muted">
                  {t("noLogo")}
                </span>
              )}
              <label className="btn-ghost btn-sm cursor-pointer">
                <input
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  className="hidden"
                  onChange={onLogoChange}
                  disabled={logoUploading}
                />
                {logoUploading ? t("uploading") : t("uploadLogo")}
              </label>
              {logoUrl ? (
                <button
                  type="button"
                  className="btn-ghost btn-sm text-red-300"
                  onClick={() => setLogoUrl(null)}
                >
                  {t("remove")}
                </button>
              ) : null}
            </div>
          </div>

          <div>
            <span className="field-label mb-1 block">
              {t("photos")} ({photoUrls.length}/{MAX_PHOTOS})
            </span>
            <div className="flex flex-wrap items-center gap-2">
              {photoUrls.map((url) => (
                <div key={url} className="relative">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={resolveMediaUrl(url)}
                    alt=""
                    className="h-20 w-20 rounded border border-line object-cover"
                  />
                  <button
                    type="button"
                    onClick={() => removePhoto(url)}
                    className="absolute -top-2 -right-2 inline-flex h-6 w-6 items-center justify-center rounded-full border border-line bg-ink text-[11px] text-paper hover:text-red-300"
                    aria-label={t("remove")}
                  >
                    ×
                  </button>
                </div>
              ))}
              {photoUrls.length < MAX_PHOTOS ? (
                <label className="btn-ghost btn-sm cursor-pointer">
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    className="hidden"
                    onChange={onPhotosChange}
                    multiple
                    disabled={photoUploading}
                  />
                  {photoUploading ? t("uploading") : t("addPhotos")}
                </label>
              ) : null}
            </div>
          </div>
        </div>
      </section>

      {error ? (
        <p className="rounded-md border border-red-400/40 bg-red-500/10 px-3 py-2 text-[12.5px] text-red-200">
          {error}
        </p>
      ) : null}

      <button
        type="submit"
        className="btn-primary btn-sm self-start"
        disabled={submitting || logoUploading || photoUploading}
      >
        {submitting ? t("submitting") : t("submit")}
      </button>
    </form>
  );
}
