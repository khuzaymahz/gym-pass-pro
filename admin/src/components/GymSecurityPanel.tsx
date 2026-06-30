"use client";

import { useTranslations } from "next-intl";
import { useState } from "react";

import { useToast } from "@/components/ui/Toast";

type ResetAction = (
  password: string,
) => Promise<{ ok: boolean; error?: string }>;

// Readable-enough generated password: 14 chars, mixed case + digits, no
// ambiguous 0/O/1/l/I so the admin can dictate it over the phone.
function generatePassword(): string {
  const alphabet = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = new Uint32Array(14);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (n) => alphabet[n % alphabet.length]).join("");
}

/**
 * Bare panel (lives inside a CollapsibleSection) for the gym's security
 * controls. Today that's an admin-driven partner-password reset: there's
 * no self-service email/SMS reset in v1, so when a partner forgets their
 * password an admin sets a new one here and hands it over out of band.
 */
export function GymSecurityPanel({
  hasOwner,
  resetAction,
}: {
  hasOwner: boolean;
  resetAction: ResetAction;
}) {
  const t = useTranslations("gyms.security");
  const tCommon = useTranslations("common");
  const { toast } = useToast();
  const [password, setPassword] = useState("");
  const [pending, setPending] = useState(false);

  if (!hasOwner) {
    return <p className="text-[12px] text-muted">{t("noOwner")}</p>;
  }

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setPending(true);
    const result = await resetAction(password);
    setPending(false);
    if (!result.ok) {
      toast(result.error ?? tCommon("errorGeneric"), "error");
      return;
    }
    setPassword("");
    toast(t("resetToast"), "success");
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-3">
      <p className="text-[12px] text-muted">{t("resetHint")}</p>
      <div className="flex flex-wrap items-end gap-2">
        <label className="field min-w-[200px] flex-1">
          <span className="field-label">{t("newPassword")}</span>
          <input
            // Visible on purpose — the admin reads it back to the partner.
            type="text"
            className="input input-sm"
            required
            minLength={8}
            maxLength={128}
            autoComplete="off"
            placeholder={t("newPasswordPlaceholder")}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </label>
        <button
          type="button"
          className="btn-ghost btn-sm"
          onClick={() => setPassword(generatePassword())}
        >
          {t("generate")}
        </button>
        <button type="submit" className="btn-primary btn-sm" disabled={pending}>
          {pending ? tCommon("saving") : t("reset")}
        </button>
      </div>
    </form>
  );
}
