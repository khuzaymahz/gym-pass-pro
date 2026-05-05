import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "#0A0B0A",
        "ink-1": "#111312",
        "ink-2": "#171A19",
        "ink-3": "#1E2221",
        paper: "#F4F4F0",
        "paper-2": "#CACBC2",
        "paper-3": "#8E8F86",
        "paper-4": "#5A5B54",
        lime: "#BBFB46",
        "lime-light": "#D5FF7E",
        "lime-dim": "#7FA82E",
        tier: {
          silver: "#C0C0C0",
          gold: "#FFD60A",
          platinum: "#B8D4FF",
          diamond: "#64D2FF",
        },
      },
      fontFamily: {
        display: ["Archivo", "system-ui", "sans-serif"],
        body: ["Inter", "system-ui", "sans-serif"],
        mono: ["JetBrains Mono", "ui-monospace", "monospace"],
        serif: ["'Instrument Serif'", "serif"],
      },
      letterSpacing: {
        tightest: "-0.04em",
      },
      boxShadow: {
        cta: "0 15px 40px -10px rgba(187,251,70,0.35)",
        phone: "0 30px 80px -15px rgba(0,0,0,0.8)",
      },
    },
  },
  plugins: [],
};

export default config;
