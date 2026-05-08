import type { ReactNode } from "react";

type Tone = "ok" | "warn" | "bad" | "info" | "mute";

export function StatusPill({
  tone,
  children,
  withDot = true,
}: {
  tone: Tone;
  children: ReactNode;
  withDot?: boolean;
}) {
  const klass = {
    ok: "pill pill-ok",
    warn: "pill pill-warn",
    bad: "pill pill-bad",
    info: "pill pill-info",
    mute: "pill pill-mute",
  }[tone];
  const dotClass = {
    ok: "bg-accent",
    warn: "bg-amber-400",
    bad: "bg-red-400",
    info: "bg-sky-400",
    mute: "bg-muted",
  }[tone];
  return (
    <span className={klass}>
      {withDot ? <span className={`dot ${dotClass}`} /> : null}
      {children}
    </span>
  );
}
