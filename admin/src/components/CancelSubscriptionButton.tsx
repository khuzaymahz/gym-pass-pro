"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

import type { ActionResult } from "@/lib/action-result";

type Props = {
  action: () => Promise<ActionResult<void>>;
};

export default function CancelSubscriptionButton({ action }: Props) {
  const router = useRouter();
  const t = useTranslations("subscriptions");
  const tCommon = useTranslations("common");
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function onClick() {
    if (!confirm(t("cancelConfirm"))) return;
    setError(null);
    startTransition(async () => {
      const result = await action();
      if (result.ok) {
        router.refresh();
      } else {
        setError(result.message);
      }
    });
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <button
        type="button"
        onClick={onClick}
        disabled={pending}
        className="btn-danger btn-sm disabled:opacity-50"
      >
        {pending ? tCommon("loading") : t("cancel")}
      </button>
      {error ? <span className="text-[11px] text-red-300">{error}</span> : null}
    </div>
  );
}
