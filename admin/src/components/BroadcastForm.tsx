"use client";

import { useState, useTransition } from "react";

import type { ActionResult } from "@/lib/action-result";
import type { BroadcastBody, Tier } from "@/lib/sdk";

type Props = {
  action: (body: BroadcastBody) => Promise<
    ActionResult<{ recipients: number }>
  >;
};

const TIERS: Tier[] = ["silver", "gold", "platinum", "diamond"];

export default function BroadcastForm({ action }: Props) {
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{
    tone: "ok" | "err";
    text: string;
  } | null>(null);

  const [titleEn, setTitleEn] = useState("");
  const [titleAr, setTitleAr] = useState("");
  const [bodyEn, setBodyEn] = useState("");
  const [bodyAr, setBodyAr] = useState("");
  const [targetTier, setTargetTier] = useState<"" | Tier>("");

  function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    if (!confirm("Send this broadcast to every matching member?")) return;
    setMessage(null);

    const payload: BroadcastBody = {
      titleEn,
      titleAr,
      bodyEn,
      bodyAr,
      targetTier: targetTier === "" ? null : (targetTier as Tier),
    };

    startTransition(async () => {
      const result = await action(payload);
      if (result.ok) {
        setMessage({
          tone: "ok",
          text: `Sent to ${result.data.recipients} member(s).`,
        });
        setTitleEn("");
        setTitleAr("");
        setBodyEn("");
        setBodyAr("");
      } else {
        setMessage({ tone: "err", text: result.message });
      }
    });
  }

  return (
    <form onSubmit={onSubmit} className="panel flex flex-col">
      <div className="grid grid-cols-1 gap-3 border-b border-line p-4 md:grid-cols-2">
        <Field label="Title · EN">
          <input
            className="input input-sm"
            required
            value={titleEn}
            onChange={(e) => setTitleEn(e.target.value)}
          />
        </Field>
        <Field label="Title · AR">
          <input
            className="input input-sm"
            required
            dir="rtl"
            value={titleAr}
            onChange={(e) => setTitleAr(e.target.value)}
          />
        </Field>
        <Field label="Body · EN">
          <textarea
            className="input min-h-[6rem]"
            required
            value={bodyEn}
            onChange={(e) => setBodyEn(e.target.value)}
          />
        </Field>
        <Field label="Body · AR">
          <textarea
            className="input min-h-[6rem]"
            required
            dir="rtl"
            value={bodyAr}
            onChange={(e) => setBodyAr(e.target.value)}
          />
        </Field>
        <Field label="Target tier">
          <select
            className="select input-sm"
            value={targetTier}
            onChange={(e) => setTargetTier(e.target.value as "" | Tier)}
          >
            <option value="">All active members</option>
            {TIERS.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <footer className="flex items-center justify-between gap-3 px-4 py-3">
        {message ? (
          <p
            className={`text-[12px] ${
              message.tone === "ok" ? "text-lime" : "text-red-300"
            }`}
          >
            {message.text}
          </p>
        ) : (
          <span className="text-[12px] text-muted">
            Both languages required. Confirm before send.
          </span>
        )}
        <button className="btn-primary btn-sm" disabled={pending}>
          {pending ? "Sending…" : "Send broadcast"}
        </button>
      </footer>
    </form>
  );
}

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="field">
      <span className="field-label">{label}</span>
      {children}
    </label>
  );
}
