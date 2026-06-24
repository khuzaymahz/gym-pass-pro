"use client";

import { useTranslations } from "next-intl";
import { useState } from "react";

import PendingButton from "@/components/PendingButton";
import { useToast } from "@/components/ui/Toast";
import type { GymOwnerRead } from "@/lib/gyms";

type CreateInput = { phone: string; password: string; name: string };

type CreateAction = (
  input: CreateInput,
) => Promise<
  | { ok: true; value: GymOwnerRead }
  | { ok: false; error: string }
>;

type DeleteAction = () => Promise<
  { ok: true } | { ok: false; error: string }
>;

type Props = {
  initial: GymOwnerRead | null;
  createAction: CreateAction;
  deleteAction: DeleteAction;
};

/// Owner is bound 1:1 to a gym. UI mirrors that:
///   - **No owner**: shows a "Create partner login" inline form
///     (phone + name + password). Submitting POSTs the new partner
///     and reveals the same row the GET branch would have shown.
///   - **Has owner**: shows the partner's phone + display name + a
///     destructive "Revoke login" button. No edit-in-place — phone
///     change requires revoke + recreate so the audit trail is
///     unambiguous about who held the credentials when.
export function GymOwnerPanel({
  initial,
  createAction,
  deleteAction,
}: Props) {
  const t = useTranslations("gyms.owner");
  const tCommon = useTranslations("common");
  const { toast } = useToast();
  const [owner, setOwner] = useState<GymOwnerRead | null>(initial);
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onCreate(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const result = await createAction({ phone, password, name });
    setBusy(false);
    if (!result.ok) {
      const msg = result.error || tCommon("errorGeneric");
      setError(msg);
      toast(msg, "error");
      return;
    }
    setOwner(result.value);
    setPhone("");
    setPassword("");
    setName("");
    toast(t("createdToast"), "success");
  }

  async function onRevoke() {
    if (
      !window.confirm(
        t("revokeConfirm", { phone: owner?.phone ?? "—" }),
      )
    ) {
      return;
    }
    setBusy(true);
    setError(null);
    const result = await deleteAction();
    setBusy(false);
    if (!result.ok) {
      const msg = result.error || tCommon("errorGeneric");
      setError(msg);
      toast(msg, "error");
      return;
    }
    setOwner(null);
    toast(t("revokedToast"), "success");
  }

  return (
    <section className="panel flex flex-col gap-4 p-4">
      <header className="flex items-start justify-between gap-3">
        <div>
          <h2 className="text-[14px] font-semibold text-paper">
            {t("title")}
          </h2>
          <p className="text-[12px] text-muted">{t("subtitle")}</p>
        </div>
      </header>

      {owner ? (
        <div className="flex flex-col gap-3">
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
            <Field label={t("namedLabel")} value={owner.name || "—"} />
            <Field label={t("phoneLabel")} value={owner.phone} dir="ltr" />
            <Field label={t("idLabel")} value={owner.id} dir="ltr" />
          </div>
          <div className="flex items-center justify-between border-t border-line pt-3">
            <p className="text-[11.5px] text-muted">{t("revokeHint")}</p>
            <PendingButton
              type="button"
              onClick={onRevoke}
              pending={busy}
              pendingLabel={tCommon("saving")}
              idleLabel={t("revoke")}
              className="btn-danger btn-sm"
            />
          </div>
          {error ? (
            <p className="text-[12px] text-red-300">{error}</p>
          ) : null}
        </div>
      ) : (
        <form
          onSubmit={onCreate}
          className="grid grid-cols-1 gap-3 sm:grid-cols-3"
        >
          <label className="field">
            <span className="field-label">{t("namedLabel")}</span>
            <input
              type="text"
              className="input input-sm"
              required
              minLength={1}
              maxLength={128}
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </label>
          <label className="field">
            <span className="field-label">{t("phoneLabel")}</span>
            <input
              type="tel"
              dir="ltr"
              className="input input-sm num"
              required
              minLength={8}
              maxLength={32}
              placeholder="+962 7X XXX XXXX"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
            />
          </label>
          <label className="field">
            <span className="field-label">{t("passwordLabel")}</span>
            <div className="relative">
              <input
                type={showPassword ? "text" : "password"}
                dir="ltr"
                className="input input-sm num w-full pr-12"
                required
                minLength={8}
                maxLength={128}
                autoComplete="new-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              <button
                type="button"
                onClick={() => setShowPassword((v) => !v)}
                className="absolute inset-y-0 right-2 text-[11px] text-muted hover:text-paper"
                tabIndex={-1}
              >
                {showPassword ? t("hide") : t("show")}
              </button>
            </div>
          </label>
          <div className="sm:col-span-3 flex items-center justify-between border-t border-line pt-3">
            {error ? (
              <p className="text-[12px] text-red-300">{error}</p>
            ) : (
              <p className="text-[11.5px] text-muted">{t("createHint")}</p>
            )}
            <PendingButton
              type="submit"
              pending={busy}
              pendingLabel={tCommon("saving")}
              idleLabel={t("create")}
              className="btn-primary btn-sm"
            />
          </div>
        </form>
      )}
    </section>
  );
}

function Field({
  label,
  value,
  dir,
}: {
  label: string;
  value: string;
  dir?: "ltr" | "rtl";
}) {
  return (
    <div className="flex flex-col gap-0.5">
      <span className="field-label">{label}</span>
      <span className="text-[13px] text-paper" dir={dir}>
        {value}
      </span>
    </div>
  );
}
