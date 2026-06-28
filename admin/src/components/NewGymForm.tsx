"use client";

import { useTranslations } from "next-intl";
import { useState } from "react";

import GymForm from "@/components/GymForm";
import CollapsibleSection from "@/components/ui/CollapsibleSection";
import type { GymRead } from "@/lib/gyms";

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
  const tOwner = useTranslations("gyms.owner");
  const tSec = useTranslations("gyms.sections");
  const tCreate = useTranslations("gyms.create");

  const [phone, setPhone] = useState("");
  const [name, setName] = useState("");
  const [password, setPassword] = useState("");
  const [photos, setPhotos] = useState<File[]>([]);

  async function action(data: Partial<GymRead>) {
    const created = await createGymAction(data);
    if (!created.ok || !created.gymId) {
      return { ok: false, error: created.error };
    }
    const gymId = created.gymId;

    // Partner login is optional; only when both phone + password are given.
    if (phone.trim() && password) {
      const owner = await createOwnerAction(gymId, {
        phone: phone.trim(),
        name: name.trim(),
        password,
      });
      if (!owner.ok) {
        return { ok: false, error: tCreate("ownerFailed", { error: owner.error ?? "" }) };
      }
    }

    // Photos are optional + best-effort — the gym already exists, so a
    // failed upload surfaces an error but doesn't roll anything back.
    for (const file of photos) {
      const fd = new FormData();
      fd.append("file", file);
      const uploaded = await uploadPhotoAction(gymId, fd);
      if (!uploaded.ok) {
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
              className="input input-sm"
              maxLength={32}
              placeholder="+962 7X XXX XXXX"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
            />
          </label>
          <label className="field">
            <span className="field-label">{tOwner("namedLabel")}</span>
            <input
              className="input input-sm"
              maxLength={128}
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </label>
          <label className="field">
            <span className="field-label">{tOwner("passwordLabel")}</span>
            <input
              type="text"
              className="input input-sm"
              minLength={8}
              maxLength={128}
              autoComplete="off"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
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
