import type { ReactNode } from "react";

type Tone = "ok" | "warn" | "bad" | "info" | "mute";

const TONE_CLASS: Record<Tone, string> = {
  ok: "pill-ok",
  warn: "pill-warn",
  bad: "pill-bad",
  info: "pill-info",
  mute: "pill-mute",
};

const DOT_COLOR: Record<Tone, string> = {
  ok: "bg-lime",
  warn: "bg-amber-300",
  bad: "bg-red-400",
  info: "bg-sky-400",
  mute: "bg-muted",
};

export default function StatusPill({
  tone,
  children,
  withDot = true,
}: {
  tone: Tone;
  children: ReactNode;
  withDot?: boolean;
}) {
  return (
    <span className={`pill ${TONE_CLASS[tone]}`}>
      {withDot ? <span className={`dot ${DOT_COLOR[tone]}`} /> : null}
      <span className="whitespace-nowrap">{children}</span>
    </span>
  );
}

export function StatusDot({
  tone,
  children,
}: {
  tone: Tone;
  children: ReactNode;
}) {
  return (
    <span className="inline-flex items-center gap-1.5 text-[12px] text-paper">
      <span className={`dot ${DOT_COLOR[tone]}`} />
      <span>{children}</span>
    </span>
  );
}
