# Gym Pass — Marketing Site

Standalone 3D immersive showcase. Not the app, not the admin — a single long-scroll landing page pinned behind a persistent React Three Fiber canvas.

## Run

```bash
# local
npm install
npm run dev              # http://localhost:3002

# inside compose
docker compose up -d marketing
```

## Stack

- Next.js 15 App Router (RSC for content, client boundary at `Scene` + `Nav`)
- React Three Fiber 8 + Drei for the 3D canvas
- Tailwind with design tokens mirrored from `design/project/colors_and_type.css`
- Fonts via Google Fonts CDN (Archivo / Inter / JetBrains Mono / Instrument Serif)

## Layout

```
app/layout.tsx        — root shell, dark metadata
app/page.tsx          — composes Scene + Nav + 6 sections
app/globals.css       — tokens, utility classes, reduced-motion override
components/Scene.tsx  — persistent R3F canvas (fixed, -z-10)
components/scene/     — Particles, TierOrbs, Equipment, FloatingPhone
components/sections/  — Hero, Tiers, HowItWorks, Network, Pricing, CTA
hooks/                — useScrollProgress, useReducedMotion
```

## Scroll choreography

`useScrollProgress()` returns 0..1. `Scene.tsx` maps that to camera / object transforms:

| beat | progress | focus                                |
| ---- | -------- | ------------------------------------ |
| Hero | 0.00     | orbs centered, phone off-stage right |
| Tiers| 0.17     | orbs spread                          |
| How  | 0.33     | phone flies in                       |
| Net  | 0.50     | equipment drifts forward             |
| Price| 0.67     | re-compose                           |
| CTA  | 0.83     | pull back, lime glow                 |

## Accessibility / perf

- `prefers-reduced-motion` swaps the canvas for a static radial gradient
- `@react-three/drei` `AdaptiveDpr` drops pixel ratio on slow frames
- Pre-mount render also uses the gradient fallback to avoid layout shift
