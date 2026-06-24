import type { Config } from "tailwindcss";

/**
 * Theme-aware Tailwind palette. Every colour resolves to a CSS
 * variable defined in `globals.css`, so the same class set works in
 * dark and light without per-utility variants. Runtime theme is
 * selected by the `data-theme` attribute on `<html>` (set by the
 * `ThemeToggle`); CSS variables flip and the whole UI re-themes
 * without a single React re-render.
 *
 * Naming intent:
 *   - `ink` / `paper` — the two surface poles. Inverted under
 *     light: in dark, `ink` is near-black and `paper` is near-white;
 *     in light, `ink` is near-white and `paper` is near-black. So a
 *     `bg-ink text-paper` chip reads correctly in both modes.
 *   - `surface` ramp — three-step elevation layered above `ink`.
 *   - `line` / `line-2` — borders, with `-2` slightly stronger.
 *   - `muted` — secondary copy.
 *   - `accent` / `accent-ink` — brand amber (#EAB308) + readable
 *     foreground for it. Replaces the previous lime — pairs cleanly
 *     on both light and dark surfaces (the lime-on-cream contrast
 *     was the blocker for shipping light mode).
 *   - `lime` alias — back-compat for sites mid-migration; resolves
 *     to the same `--c-accent`. Drop once the codebase is fully
 *     converted.
 */
const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "rgb(var(--c-ink) / <alpha-value>)",
        paper: "rgb(var(--c-paper) / <alpha-value>)",
        surface: "rgb(var(--c-surface) / <alpha-value>)",
        "surface-1": "rgb(var(--c-surface-1) / <alpha-value>)",
        "surface-2": "rgb(var(--c-surface-2) / <alpha-value>)",
        line: "rgb(var(--c-line) / <alpha-value>)",
        "line-2": "rgb(var(--c-line-2) / <alpha-value>)",
        muted: "rgb(var(--c-muted) / <alpha-value>)",
        accent: "rgb(var(--c-accent) / <alpha-value>)",
        "accent-ink": "rgb(var(--c-accent-ink) / <alpha-value>)",
        // Back-compat: existing `bg-lime` / `text-lime` sites keep
        // compiling while we migrate references to `accent`.
        lime: "rgb(var(--c-accent) / <alpha-value>)",
      },
      fontFamily: {
        sans: [
          "var(--font-sans)",
          "Inter",
          "ui-sans-serif",
          "system-ui",
          "sans-serif",
        ],
        // Display — headings, brand, big numbers. Archivo's wider
        // grotesque gives the dashboard a distinct voice vs. the Inter
        // body. Falls back to the sans stack for Arabic glyphs.
        display: [
          "var(--font-display)",
          "var(--font-sans)",
          "Inter",
          "ui-sans-serif",
          "system-ui",
          "sans-serif",
        ],
        // Mono — tabular data, ids, labels. JetBrains Mono mirrors the
        // mobile app's label face.
        mono: [
          "var(--font-mono)",
          "ui-monospace",
          "SFMono-Regular",
          "monospace",
        ],
      },
      fontSize: {
        "2xs": ["11px", { lineHeight: "14px" }],
      },
      borderRadius: {
        md: "6px",
        lg: "8px",
        xl: "10px",
        "2xl": "12px",
      },
      transitionTimingFunction: {
        // `DEFAULT` makes the bare `ease` utility resolve to our
        // signature curve (snappy out-glide), used across buttons,
        // rows, inputs and the nav for one consistent motion feel.
        DEFAULT: "cubic-bezier(0.2, 0.7, 0.2, 1)",
        ease: "cubic-bezier(0.2, 0.7, 0.2, 1)",
      },
    },
  },
  plugins: [],
};

export default config;
