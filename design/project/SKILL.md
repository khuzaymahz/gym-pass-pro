---
name: Gym Pass
description: Design system for Gym Pass — a Jordan-based gym subscription app (Silver/Gold/Platinum/Diamond tiers, QR check-in). Bold editorial aesthetic — black canvas, electric lime accent, oversized italic Archivo Black display, Instrument Serif italic accents, JetBrains Mono micro-labels. Use when designing anything Gym Pass: member app screens, onboarding flows, payment, check-in, venue cards, tier chips, marketing. Flutter target (iOS + Android); Arabic-first with EN parity and full RTL support.
---

# Gym Pass — How to design with this system

This is a **dark-only**, **editorial-fitness** design system. Commit to the vibe: black canvas, one lime accent, oversized italic type, mono micro-labels. Softness, pastel gradients, rounded everything, and generic "SaaS dashboard" looks are wrong here.

## Always start here

1. **Read `README.md`** for the full content rules, visual foundations, iconography, and copywriting voice.
2. **Link `colors_and_type.css`** in any HTML you build. It defines every base + semantic CSS variable and the @font-face / Google Font imports.
3. **Reference `ui_kits/mobile_app/`** for worked examples of screens (Login, Home, QR Scan, Plans, Success, Profile). Copy its `common.jsx` primitives — `<Wordmark>`, `<Overline>`, `<Display>`, `<SerifAccent>`, `<PillButton>`, `<TabBar>`, `<Screen>` — rather than reinventing them.
4. **Browse `preview/`** to see how tokens render as cards in the Design System tab.

## The non-negotiables

- **Black canvas.** Background is `--color-bg` (#0A0B0A). Never white, never light mode.
- **One accent color.** `--color-accent` (#BBFB46 electric lime). Use it sparingly: primary CTA, active state, a single accent word, a progress bar, a notification dot. If everything glows lime, nothing does.
- **Italic Archivo Black for display.** Always italic, always uppercase, tight tracking (-0.035em to -0.045em), tight leading (0.9–0.95). This is the brand's voice.
- **Instrument Serif italic for emotional beats.** Swap one punch-word per headline to Instrument Serif Italic in lime, lowercase. "Mohammad, *let's train.*" / "Scan *& go.*" / "Pick a *pass.*"
- **JetBrains Mono for micro-labels.** All-caps, 10–11px, tracked 0.14–0.24em. Overlines, status pills, timestamps, tier chips, meta rows.
- **Inter for body copy only.** Never for headlines. Never bold. 13–15px.
- **Pill CTAs.** Primary buttons are full-radius pills, lime-gradient fill, black italic uppercase label, soft outer glow. Secondary: pill with dark-3 fill, 1px border, normal-case label.
- **Tier glyphs, not logos.** Silver ◇, Gold ◆, Platinum ◈, Diamond ✦. Always with the tier name.
- **Mono status dots.** Lead overlines with `●` + ALL-CAPS mono label.

## Copy voice

- Short and declarative. Two-word headlines are ideal. Never write paragraphs on a screen.
- Second person, friendly-but-direct. "You're in." "Let's train."
- Italicize the beat word in serif. The serif word carries the emotion.
- ALL-CAPS labels for meta, title-case for headlines. Never lowercase body prose in UI chrome.

## Iconography

Use **Lucide**-style 2px stroke icons at 22px, `currentColor`, no fill. The `common.jsx` in the UI kit shows the inline SVG pattern. Do not invent elaborate illustrated icons — they fight the mono/display type system.

## Layout rules

- Mobile-first. iPhone 14 artboards are 390×844. Safe vertical margins ~40px top / 34px bottom for home indicator.
- Generous negative space. Let type breathe. One hero element per screen.
- Cards use `--color-bg-2` fill, 16–20px radius, 1px subtle border (`rgba(255,255,255,0.08)`). No heavy shadows — use soft radial glows from the lime accent instead for depth.
- Tab bar is a floating pill, `bg-3` w/ blur, lime QR button overhanging in the center.

## Localization

Arabic-first. Use `:dir(rtl)` selectors for mirrored layouts. Numbers stay Latin. Currency is JOD. The italic display type works for both scripts — Archivo has Arabic cuts; serif accents swap to an appropriate Arabic serif.

## What to produce

- **Member app screens** — use the `Screen` wrapper from `ui_kits/mobile_app/common.jsx`. Drop into a `DesignCanvas` for multi-screen flows.
- **Onboarding / flows** — chain screens with a shared `Step N of 3` overline and consistent back-button chrome.
- **Marketing one-offs** — same type system + lime accent, can break mobile frame; lean into poster-scale display type.

## Never do

- Never use emoji in UI (except ● mono status dot, and tier glyphs).
- Never use gradients as decorative fills — only for the primary CTA and subtle radial glows behind hero content.
- Never use blue links, rounded-rectangle iOS-style buttons, or system fonts for display.
- Never write placeholder lorem. Write real GymPass copy in-voice (see README "VOICE RULES").
- Never add Inter to a headline. Never make Archivo non-italic.
