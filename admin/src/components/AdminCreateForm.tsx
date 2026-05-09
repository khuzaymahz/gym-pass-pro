"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

import type { ActionResult } from "@/lib/action-result";
import type { AdminCreateBody, AdminUser } from "@/lib/sdk";

type Props = {
  action: (data: AdminCreateBody) => Promise<ActionResult<AdminUser>>;
};

export default function AdminCreateForm({ action }: Props) {
  const router = useRouter();
  const t = useTranslations("admins.form");
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const [email, setEmail] = useState("");
  const [name, setName] = useState("");
  const [password, setPassword] = useState("");

  function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    startTransition(async () => {
      const result = await action({ email, name, password });
      if (result.ok) {
        setEmail("");
        setName("");
        setPassword("");
        router.refresh();
      } else {
        setError(result.message);
      }
    });
  }

  return (
    <form
      onSubmit={onSubmit}
      className="flex flex-wrap items-end gap-2 rounded-lg border border-line bg-surface p-3"
    >
      <label className="field">
        <span className="field-label">{t("email")}</span>
        <input
          className="input input-sm w-56"
          type="email"
          required
          maxLength={254}
          placeholder={t("emailPlaceholder")}
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
      </label>
      <label className="field">
        <span className="field-label">{t("name")}</span>
        <input
          className="input input-sm w-52"
          required
          maxLength={128}
          placeholder={t("namePlaceholder")}
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
      </label>
      <label className="field">
        <span className="field-label">{t("password")}</span>
        {/* Backend `AdminCreate.password` requires 12–128 chars plus
          * the complexity rules in `_validate_admin_password`. */}
        <input
          className="input input-sm w-52"
          type="password"
          required
          minLength={12}
          maxLength={128}
          placeholder={t("passwordPlaceholder")}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
      </label>
      <button className="btn-primary btn-sm" disabled={pending}>
        {pending ? t("submitting") : t("submit")}
      </button>
      {error ? (
        <span className="w-full text-[12px] text-red-300">{error}</span>
      ) : null}
    </form>
  );
}
