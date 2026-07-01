"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useState } from "react";

import GymForm from "@/components/GymForm";
import CollapsibleSection from "@/components/ui/CollapsibleSection";
import type { GymRead, OwnerProvision } from "@/lib/gyms";
import { isValidJordanianPhone, normalizeJordanianPhone } from "@/lib/phone";

type CreateGymWithOwnerAction = (
  data: Partial<GymRead>,
  owner: OwnerProvision | null,
) => Promise<{ ok: boolean; gymId?: string; error?: string }>;
type UploadPhotoAction = (
  gymId: string,
  formData: FormData,
) => Promise<{ ok: boolean; error?: string }>;

type OwnerMode = "new" | "link";

/**
 * Create flow: the gym form plus an optional Partner-login + Photos section,
 * so a gym can be stood up in one shot. Gym + owner are created together
 * via an atomic backend endpoint — if the owner step fails, the gym is
 * rolled back too, so a bad phone never leaves an orphan gym behind.
 *
 * The partner section has two modes: "new" mints a fresh login (phone +
 * name + password); "link" attaches an EXISTING partner by phone — the
 * multi-branch path, so one owner spans several branch gyms. Photos upload
 * after creation (multipart); a photo failure routes to the edit page.
 */
export default function NewGymForm({
  submitLabel,
  createGymWithOwnerAction,
  uploadPhotoAction,
}: {
  submitLabel: string;
  createGymWithOwnerAction: CreateGymWithOwnerAction;
  uploadPhotoAction: UploadPhotoAction;
}) {
  const router = useRouter();
  const tOwner = useTranslations("gyms.owner");
  const tSec = useTranslations("gyms.sections");
  const tCreate = useTranslations("gyms.create");

  const [ownerMode, setOwnerMode] = useState<OwnerMode>("new");
  const [phone, setPhone] = useState("");
  const [name, setName] = useState("");
  const [password, setPassword] = useState("");
  const [photos, setPhotos] = useState<File[]>([]);
  const [phoneError, setPhoneError] = useState<string | null>(null);
  const [nameError, setNameError] = useState<string | null>(null);
  const [passwordError, setPasswordError] = useState<string | null>(null);

  // In "link" mode only the phone matters; in "new" mode the backend needs
  // phone + name + an 8+ char password together. Any touched field makes
  // the set required ("all or nothing"). An empty section creates a bare
  // gym with no owner — that's allowed.
  function wantsOwner(): boolean {
    return ownerMode === "link"
      ? Boolean(phone.trim())
      : Boolean(phone.trim() || name.trim() || password);
  }

  function validateOwner(): boolean {
    if (!wantsOwner()) {
      setPhoneError(null);
      setNameError(null);
      setPasswordError(null);
      return true;
    }
    const pErr = isValidJordanianPhone(phone) ? null : tOwner("phoneInvalid");
    if (ownerMode === "link") {
      setPhoneError(pErr);
      setNameError(null);
      setPasswordError(null);
      return !pErr;
    }
    const nErr = name.trim() ? null : tOwner("nameRequired");
    const pwErr = password.length >= 8 ? null : tOwner("passwordShort");
    setPhoneError(pErr);
    setNameError(nErr);
    setPasswordError(pwErr);
    return !pErr && !nErr && !pwErr;
  }

  async function action(data: Partial<GymRead>) {
    if (!validateOwner()) {
      return { ok: false, error: tCreate("fixPartnerFields") };
    }

    let owner: OwnerProvision | null = null;
    if (wantsOwner()) {
      owner =
        ownerMode === "link"
          ? { mode: "link", phone: normalizeJordanianPhone(phone) }
          : {
              mode: "new",
              phone: normalizeJordanianPhone(phone),
              name: name.trim(),
              password,
            };
    }

    const created = await createGymWithOwnerAction(data, owner);
    if (!created.ok || !created.gymId) {
      // Atomic: nothing was created, so the operator just fixes the
      // field and re-submits — no orphan gym, no slug collision.
      return { ok: false, error: created.error };
    }
    const gymId = created.gymId;

    // Photos attach after creation (multipart, separate call). If one
    // fails the gym + owner already exist, so finish on the edit page.
    for (const file of photos) {
      const fd = new FormData();
      fd.append("file", file);
      const uploaded = await uploadPhotoAction(gymId, fd);
      if (!uploaded.ok) {
        router.push(`/gyms/${gymId}`);
        return {
          ok: false,
          error: tCreate("photoFailed", { error: uploaded.error ?? "" }),
        };
      }
    }

    return { ok: true };
  }

  return (
    <GymForm action={action} submitLabel={submitLabel}>
      <CollapsibleSection
        title={tSec("partner")}
        subtitle={tCreate("partnerOptional")}
      >
        {/* New-login vs link-existing toggle. Link is the multi-branch
            path: attach a partner who already has a login to this gym. */}
        <div
          className="inline-flex rounded-md border border-line p-0.5"
          role="tablist"
          aria-label={tOwner("modeLabel")}
        >
          {(["new", "link"] as const).map((m) => (
            <button
              key={m}
              type="button"
              role="tab"
              aria-selected={ownerMode === m}
              className={`rounded px-3 py-1 text-[12px] font-medium transition ${
                ownerMode === m
                  ? "bg-accent text-ink"
                  : "text-muted hover:text-paper"
              }`}
              onClick={() => {
                setOwnerMode(m);
                setPhoneError(null);
                setNameError(null);
                setPasswordError(null);
              }}
            >
              {m === "new" ? tOwner("modeNew") : tOwner("modeLink")}
            </button>
          ))}
        </div>

        <div className="mt-3 grid grid-cols-1 gap-3 md:grid-cols-3">
          <label className="field">
            <span className="field-label">{tOwner("phoneLabel")}</span>
            <input
              type="tel"
              dir="ltr"
              className={`input input-sm${phoneError ? " border-red-500/60" : ""}`}
              maxLength={32}
              placeholder="+962 7X XXX XXXX"
              aria-invalid={phoneError ? true : undefined}
              value={phone}
              onChange={(e) => {
                setPhone(e.target.value);
                if (phoneError) setPhoneError(null);
              }}
              onBlur={() =>
                setPhoneError(
                  phone.trim() && !isValidJordanianPhone(phone)
                    ? tOwner("phoneInvalid")
                    : null,
                )
              }
            />
            {phoneError ? (
              <span className="text-[11px] text-red-300">{phoneError}</span>
            ) : null}
          </label>

          {ownerMode === "new" ? (
            <>
              <label className="field">
                <span className="field-label">{tOwner("namedLabel")}</span>
                <input
                  className={`input input-sm${nameError ? " border-red-500/60" : ""}`}
                  maxLength={128}
                  aria-invalid={nameError ? true : undefined}
                  value={name}
                  onChange={(e) => {
                    setName(e.target.value);
                    if (nameError) setNameError(null);
                  }}
                />
                {nameError ? (
                  <span className="text-[11px] text-red-300">{nameError}</span>
                ) : null}
              </label>
              <label className="field">
                <span className="field-label">{tOwner("passwordLabel")}</span>
                <input
                  type="text"
                  className={`input input-sm${passwordError ? " border-red-500/60" : ""}`}
                  minLength={8}
                  maxLength={128}
                  autoComplete="off"
                  aria-invalid={passwordError ? true : undefined}
                  value={password}
                  onChange={(e) => {
                    setPassword(e.target.value);
                    if (passwordError) setPasswordError(null);
                  }}
                  onBlur={() =>
                    setPasswordError(
                      password && password.length < 8
                        ? tOwner("passwordShort")
                        : null,
                    )
                  }
                />
                {passwordError ? (
                  <span className="text-[11px] text-red-300">
                    {passwordError}
                  </span>
                ) : null}
              </label>
            </>
          ) : null}
        </div>
        <p className="text-[11px] text-muted">
          {ownerMode === "new" ? tOwner("createHint") : tOwner("linkHint")}
        </p>
      </CollapsibleSection>

      <CollapsibleSection
        title={tSec("photos")}
        subtitle={tCreate("photosOptional")}
      >
        <input
          type="file"
          accept="image/jpeg,image/png,image/webp"
          multiple
          className="input input-sm"
          onChange={(e) => setPhotos(Array.from(e.target.files ?? []))}
        />
        {photos.length > 0 ? (
          <p className="text-[11px] text-muted">
            {tCreate("photosSelected", { count: photos.length })}
          </p>
        ) : null}
      </CollapsibleSection>
    </GymForm>
  );
}
