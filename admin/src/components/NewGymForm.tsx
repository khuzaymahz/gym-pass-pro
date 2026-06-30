"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useState } from "react";

import GymForm from "@/components/GymForm";
import CollapsibleSection from "@/components/ui/CollapsibleSection";
import type { GymRead } from "@/lib/gyms";
import { isValidJordanianPhone, normalizeJordanianPhone } from "@/lib/phone";

type CreateGymAction = (
  data: Partial<GymRead>,
) => Promise<{ ok: boolean; gymId?: string; error?: string }>;
type CreateOwnerAction = (
  gymId: string,
  owner: { phone: string; name: string; password: string },
) => Promise<{ ok: boolean; error?: string }>;
type UploadPhotoAction = (
  gymId: string,
  formData: FormData,
) => Promise<{ ok: boolean; error?: string }>;

/**
 * Create flow: the gym form plus optional Partner-login + Photos sections,
 * so a gym can be stood up in one shot. On submit the gym is created first
 * (it must exist before an owner or photos can attach to it), then — only
 * if filled — the partner login, then each photo. None are mandatory; a
 * bare gym still creates fine.
 */
export default function NewGymForm({
  submitLabel,
  createGymAction,
  createOwnerAction,
  uploadPhotoAction,
}: {
  submitLabel: string;
  createGymAction: CreateGymAction;
  createOwnerAction: CreateOwnerAction;
  uploadPhotoAction: UploadPhotoAction;
}) {
  const router = useRouter();
  const tOwner = useTranslations("gyms.owner");
  const tSec = useTranslations("gyms.sections");
  const tCreate = useTranslations("gyms.create");

  const [phone, setPhone] = useState("");
  const [name, setName] = useState("");
  const [password, setPassword] = useState("");
  const [photos, setPhotos] = useState<File[]>([]);
  const [phoneError, setPhoneError] = useState<string | null>(null);
  const [nameError, setNameError] = useState<string | null>(null);
  const [passwordError, setPasswordError] = useState<string | null>(null);

  // Validate the optional partner login, setting per-field errors. The
  // backend needs phone (a real Jordanian mobile) + name + an 8+ char
  // password together — catching it here (before the gym is created)
  // avoids creating an orphaned gym then 422-ing on the owner POST.
  // "All or nothing": any touched field makes all three required.
  function validateOwner(): boolean {
    const wantsOwner = Boolean(phone.trim() || name.trim() || password);
    if (!wantsOwner) {
      setPhoneError(null);
      setNameError(null);
      setPasswordError(null);
      return true;
    }
    const pErr = isValidJordanianPhone(phone) ? null : tOwner("phoneInvalid");
    const nErr = name.trim() ? null : tOwner("nameRequired");
    const pwErr = password.length >= 8 ? null : tOwner("passwordShort");
    setPhoneError(pErr);
    setNameError(nErr);
    setPasswordError(pwErr);
    return !pErr && !nErr && !pwErr;
  }

  async function action(data: Partial<GymRead>) {
    const wantsOwner = Boolean(phone.trim() || name.trim() || password);
    if (!validateOwner()) {
      return { ok: false, error: tCreate("fixPartnerFields") };
    }

    const created = await createGymAction(data);
    if (!created.ok || !created.gymId) {
      return { ok: false, error: created.error };
    }
    const gymId = created.gymId;

    // The gym now EXISTS. If a follow-up step fails, send the operator to
    // the gym's edit page (which has the partner + photos sections) to
    // finish — re-submitting here would re-POST the slug and hard-collide.
    if (wantsOwner) {
      const owner = await createOwnerAction(gymId, {
        phone: normalizeJordanianPhone(phone),
        name: name.trim(),
        password,
      });
      if (!owner.ok) {
        router.push(`/gyms/${gymId}`);
        return { ok: false, error: tCreate("ownerFailed", { error: owner.error ?? "" }) };
      }
    }

    for (const file of photos) {
      const fd = new FormData();
      fd.append("file", file);
      const uploaded = await uploadPhotoAction(gymId, fd);
      if (!uploaded.ok) {
        router.push(`/gyms/${gymId}`);
        return { ok: false, error: tCreate("photoFailed", { error: uploaded.error ?? "" }) };
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
        <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
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
              <span className="text-[11px] text-red-300">{passwordError}</span>
            ) : null}
          </label>
        </div>
        <p className="text-[11px] text-muted">{tOwner("createHint")}</p>
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
