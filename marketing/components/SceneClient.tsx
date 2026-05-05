"use client";

import dynamic from "next/dynamic";

const Scene = dynamic(() => import("./Scene").then((m) => ({ default: m.Scene })), {
  ssr: false,
  loading: () => (
    <div
      aria-hidden
      className="fixed inset-0 -z-10 bg-ink"
      style={{
        background:
          "radial-gradient(circle at 50% 40%, rgba(187,251,70,0.12), transparent 55%), #0A0B0A",
      }}
    />
  ),
});

export function SceneClient() {
  return <Scene />;
}
