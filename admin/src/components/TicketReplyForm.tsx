"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import type { ActionResult } from "@/lib/action-result";
import type { SupportTicketMessage, TicketReplyBody } from "@/lib/sdk";

type Props = {
  action: (body: TicketReplyBody) => Promise<ActionResult<SupportTicketMessage>>;
};

export default function TicketReplyForm({ action }: Props) {
  const router = useRouter();
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
          text: isInternalNote ? "Internal note saved." : "Reply sent.",
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
        placeholder={
          isInternalNote
            ? "Internal note — visible only to admins."
            : "Reply to the member…"
        }
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
          Internal note
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
        <button
          className="btn-primary btn-sm ml-auto"
          disabled={pending || !body.trim()}
        >
          {pending ? "Sending…" : isInternalNote ? "Save note" : "Send reply"}
        </button>
      </div>
    </form>
  );
}
