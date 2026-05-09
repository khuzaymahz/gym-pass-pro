"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

import PendingButton from "@/components/PendingButton";
import type { ActionResult } from "@/lib/action-result";
import type { SupportTicketMessage, TicketReplyBody } from "@/lib/sdk";

type Props = {
  action: (body: TicketReplyBody) => Promise<ActionResult<SupportTicketMessage>>;
};

export default function TicketReplyForm({ action }: Props) {
  const router = useRouter();
  const t = useTranslations("support.reply");
  const tCommon = useTranslations("common");
  const [body, setBody] = useState("");
  const [isInternalNote, setInternal] = useState(false);
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{ tone: "ok" | "err"; text: string } | null>(
    null,
  );

  function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    if (!body.trim()) return;
    setMessage(null);
    startTransition(async () => {
      const result = await action({ body: body.trim(), isInternalNote });
      if (result.ok) {
        setBody("");
        setInternal(false);
        setMessage({
          tone: "ok",
          text: tCommon("savedDot"),
        });
        router.refresh();
      } else {
        setMessage({ tone: "err", text: result.message });
      }
    });
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-2">
      <textarea
        className={`input min-h-[7rem] ${
          isInternalNote ? "border-amber-400/40 bg-amber-400/[0.04]" : ""
        }`}
        value={body}
        onChange={(e) => setBody(e.target.value)}
        placeholder={t("body")}
        required
      />
      <div className="flex flex-wrap items-center gap-3">
        <label className="flex items-center gap-1.5 text-[12px] text-muted">
          <input
            type="checkbox"
            checked={isInternalNote}
            onChange={(e) => setInternal(e.target.checked)}
            className="h-3.5 w-3.5 accent-amber-300"
          />
          {t("internalToggle")}
        </label>
        {message ? (
          <span
            className={`text-[12px] ${
              message.tone === "ok" ? "text-lime" : "text-red-300"
            }`}
          >
            {message.text}
          </span>
        ) : null}
        <PendingButton
          pending={pending}
          disabled={!body.trim()}
          pendingLabel={t("submitting")}
          idleLabel={isInternalNote ? t("internalSubmit") : t("submit")}
          className="btn-primary btn-sm ml-auto"
        />
      </div>
    </form>
  );
}
