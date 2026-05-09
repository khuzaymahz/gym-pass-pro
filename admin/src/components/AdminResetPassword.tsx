"use client";

import { useTranslations } from "next-intl";
import { useState, useTransition } from "react";

import PendingButton from "@/components/PendingButton";
import type { ActionResult } from "@/lib/action-result";

type Props = {
  action: (password: string) => Promise<ActionResult<void>>;
};

export default function AdminResetPassword({ action }: Props) {
  const t = useTranslations("admins.reset");
  const tCommon = useTranslations("common");
  const [open, setOpen] = useState(false);
  const [password, setPassword] = useState("");
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{
    tone: "ok" | "err";
    text: string;
  } | null>(null);

  function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setMessage(null);
    startTransition(async () => {
      const result = await action(password);
      if (result.ok) {
        setMessage({ tone: "ok", text: t("success") });
        setPassword("");
        setOpen(false);
      } else {
        setMessage({ tone: "err", text: result.message });
      }
    });
  }

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="btn-ghost btn-sm"
      >
        {t("label")}
      </button>
    );
  }

  return (
    <form onSubmit={onSubmit} className="flex items-center justify-end gap-1.5">
      <input
        className="input input-sm w-40"
        type="password"
        required
        minLength={12}
        maxLength={128}
        placeholder={t("newPasswordPlaceholder")}
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />
      <PendingButton
        pending={pending}
        pendingLabel={t("submitting")}
        idleLabel={tCommon("save")}
      />
      <button
        type="button"
        onClick={() => {
          setOpen(false);
          setPassword("");
          setMessage(null);
        }}
        className="btn-ghost btn-sm"
      >
        {t("cancel")}
      </button>
      {message ? (
        <span
          className={`text-[11px] ${
            message.tone === "ok" ? "text-lime" : "text-red-300"
          }`}
        >
          {message.text}
        </span>
      ) : null}
    </form>
  );
}
