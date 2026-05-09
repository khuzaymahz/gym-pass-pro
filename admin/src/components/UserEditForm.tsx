"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

import PendingButton from "@/components/PendingButton";
import type { ActionResult } from "@/lib/action-result";
import type { AdminUser, AdminUserUpdate, Gender } from "@/lib/sdk";

type Props = {
  user: AdminUser;
  action: (data: AdminUserUpdate) => Promise<ActionResult<AdminUser>>;
};

export default function UserEditForm({ user, action }: Props) {
  const router = useRouter();
  const t = useTranslations("users.edit");
  const tCommon = useTranslations("common");
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{
    tone: "ok" | "err";
    text: string;
  } | null>(null);

  const [firstName, setFirstName] = useState(user.firstName ?? "");
  const [lastName, setLastName] = useState(user.lastName ?? "");
  const [gender, setGender] = useState<Gender | "">(user.gender ?? "");
  const [birthdate, setBirthdate] = useState(user.birthdate ?? "");
  const [role, setRole] = useState<AdminUser["role"]>(user.role);
  const [locale, setLocale] = useState<AdminUser["locale"]>(user.locale);
  const [isActive, setIsActive] = useState(user.deletedAt === null);

  function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setMessage(null);
    const initialActive = user.deletedAt === null;
    const payload: AdminUserUpdate = {};
    if (firstName !== (user.firstName ?? "")) payload.firstName = firstName;
    if (lastName !== (user.lastName ?? "")) payload.lastName = lastName;
    if (gender !== (user.gender ?? "")) {
      payload.gender = gender === "" ? undefined : (gender as Gender);
    }
    if (birthdate !== (user.birthdate ?? "")) {
      payload.birthdate = birthdate === "" ? undefined : birthdate;
    }
    if (role !== user.role) payload.role = role;
    if (locale !== user.locale) payload.locale = locale;
    if (isActive !== initialActive) payload.isActive = isActive;

    if (Object.keys(payload).length === 0) {
      setMessage({ tone: "ok", text: tCommon("noChangesToSave") });
      return;
    }

    startTransition(async () => {
      const result = await action(payload);
      if (result.ok) {
        setMessage({ tone: "ok", text: tCommon("savedDot") });
        router.refresh();
      } else {
        setMessage({ tone: "err", text: result.message });
      }
    });
  }

  return (
    <form onSubmit={onSubmit} className="panel flex flex-col gap-4 p-4">
      <div className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
        <label className="field">
          <span className="field-label">{t("firstName")}</span>
          <input
            className="input input-sm"
            value={firstName}
            onChange={(e) => setFirstName(e.target.value)}
          />
        </label>
        <label className="field">
          <span className="field-label">{t("lastName")}</span>
          <input
            className="input input-sm"
            value={lastName}
            onChange={(e) => setLastName(e.target.value)}
          />
        </label>
        <label className="field">
          <span className="field-label">{t("gender")}</span>
          <select
            className="select input-sm"
            value={gender}
            onChange={(e) => setGender(e.target.value as Gender | "")}
          >
            <option value="">—</option>
            <option value="male">{t("genderMale")}</option>
            <option value="female">{t("genderFemale")}</option>
          </select>
        </label>
        <label className="field">
          <span className="field-label">{t("birthdate")}</span>
          <input
            type="date"
            className="input input-sm"
            value={birthdate}
            onChange={(e) => setBirthdate(e.target.value)}
          />
        </label>
        <label className="field">
          <span className="field-label">{t("email")}</span>
          <input
            className="input input-sm num"
            value={user.email ?? ""}
            readOnly
            disabled
          />
        </label>
        <label className="field">
          <span className="field-label">{t("phone")}</span>
          <input
            className="input input-sm num"
            value={user.phone ?? ""}
            readOnly
            disabled
          />
        </label>
        <label className="field">
          <span className="field-label">{t("role")}</span>
          <select
            className="select input-sm"
            value={role}
            onChange={(e) => setRole(e.target.value as AdminUser["role"])}
          >
            <option value="member">{t("roleMember")}</option>
            <option value="admin">{t("roleAdmin")}</option>
          </select>
        </label>
        <label className="field">
          <span className="field-label">{t("locale")}</span>
          <select
            className="select input-sm"
            value={locale}
            onChange={(e) =>
              setLocale(e.target.value as AdminUser["locale"])
            }
          >
            <option value="ar">{t("localeAr")}</option>
            <option value="en">{t("localeEn")}</option>
          </select>
        </label>
        <label className="field">
          <span className="field-label">{t("status")}</span>
          <label className="flex h-[34px] items-center gap-2 text-[12.5px] text-paper">
            <input
              type="checkbox"
              className="h-3.5 w-3.5 accent-lime"
              checked={isActive}
              onChange={(e) => setIsActive(e.target.checked)}
            />
            {t("active")}
          </label>
        </label>
      </div>

      <div className="flex items-center justify-between border-t border-line pt-3">
        {message ? (
          <p
            className={`text-[12px] ${
              message.tone === "ok" ? "text-lime" : "text-red-300"
            }`}
          >
            {message.text}
          </p>
        ) : (
          <p className="text-[11px] text-muted">{t("footerHint")}</p>
        )}
        <PendingButton
          pending={pending}
          pendingLabel={tCommon("saving")}
          idleLabel={t("save")}
        />
      </div>
    </form>
  );
}
