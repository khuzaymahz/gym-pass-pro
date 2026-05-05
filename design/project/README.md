# Gym Pass — Design System

**Gym Pass** is a Jordan-based gym pass app. One subscription grants a member access to a network of gyms across a four-tier system (Silver / Gold / Platinum / Diamond). Members browse gyms, subscribe to a tier, and check in at any included gym via QR code.

The brand is **bold, editorial, fitness-confident** — think Off-White × Strava × a racing magazine. Black canvas, a single electric lime accent, oversized italic display type paired with a delicate serif, and monospaced micro-labels everywhere. Friendly, energetic, easy to use — but never soft.

## Sources

This design system was distilled from a single comprehensive source document:

- `uploads/gym-pass-design.html` — full design + prototype spec including 14 screen mockups, design tokens, Flutter widget contracts, routing model, AR/EN localization strategy, and RTL rules. **Target platform: Flutter (iOS + Android), Arabic-first with English parity.**

No Figma or codebase was attached — all fidelity is lifted directly from the source HTML's token definitions and prototype markup.

## Index

- **`README.md`** — this file (context, content fundamentals, visual foundations, iconography)
- **`colors_and_type.css`** — base + semantic CSS variables for color and type, importable into any design
- **`SKILL.md`** — Claude Skill definition (cross-compatible with Agent Skills)
- **`fonts/`** — typeface references (Google Fonts CDN; no files needed)
- **`assets/`** — logos, icons, brand SVGs
- **`preview/`** — Design System tab cards (type, color, spacing, components)
- **`ui_kits/mobile_app/`** — the core Member App UI kit (14 screens worth of components + interactive demo)

## Product surfaces

The v1.0 scope is **one product surface**: the **Member mobile app** (iOS + Android via Flutter). Out of scope for v1.0: gym-owner admin app, web version, class booking, social features, real payment gateway.

---

## CONTENT FUNDAMENTALS

Copy is **brief, punchy, and editorial**. Sentence length is short — think poster headlines, not paragraphs. The writing voice is a confident friend, not a cheerleader or a corporate product team.

### Voice rules

- **Second person, casual.** "Let's train." "You're in." "Pick a pass." Never "The user will…".
- **Two-word headlines are ideal.** "Scan & go." "Almost there." "Welcome to Gold." When longer, break onto multiple lines with intentional rhythm.
- **Italic serif accent words.** The display type is Archivo Black Italic, but critical punch-words are swapped to Instrument Serif Italic in lime. E.g. "Mohammad, *let's train.*" — the serif word is the emotional beat.
- **Lowercase friendly, all-caps for labels only.** Headlines are title-case. Overlines and micro-labels are ALL CAPS with wide tracking (0.14–0.24em) in JetBrains Mono.
- **No exclamation points in headlines.** "You're in." lands harder than "You're in!". Exclamations only in notification messages ("Great workout!").
- **Numbers stay numerals.** "45 visits", "90 visits/month", "3 mo". Never "forty-five".
- **Arabic is default locale.** Arabic copy is equally brief: "اشتراك واحد. كل النوادي." (one subscription. all the clubs.). English and Arabic have full string parity — every user-facing word is localized via ARB files.
- **No emoji in product UI.** The design system explicitly uses glyph characters (◆ ◇ ◈ ◉ ● →) as structural ornaments instead of emoji. The Jordan flag 🇯🇴 appears once, in README context only.
- **Overlines punctuate with `●`.** Every section overline starts with a bullet dot — "● ACTIVE PLAN", "● STEP 2 OF 3 — VERIFY", "● CHOOSE YOUR TIER". This is a brand tic.
- **Bilingual currency.** `45 JOD` (EN) / `٤٥ د.أ` (AR). Currency symbol comes after the number in both locales.

### Specific examples from the source

| Context | Copy |
|---|---|
| Login headline | "ONE PASS. / EVERY GYM." |
| Home greeting | "Mohammad, *let's train.*" |
| QR scan screen | "Scan *& go*" · "Point at gym's *QR code*" |
| Plans screen | "Pick a *pass.*" · "More gyms, more visits, more everything." |
| Payment screen | "Almost *there.*" |
| Success screen | "You're in. / *Welcome to Gold.*" |
| Upgrade CTA | "Upgrade to Platinum →" |
| Notif title | "Plan expires in 14 days" · "Checked in: Iron Forge" |

### What to avoid

- Marketing-speak ("Unlock your fitness journey")
- Product-team hedges ("We recommend…", "You may want to…")
- Emoji in any product surface
- Long paragraphs — if it needs explanation, redesign the screen
- Title Case For Every Word — only display headlines use title-case, and even there lowercase serif accents are preferred

---

## VISUAL FOUNDATIONS

Gym Pass is **dark-by-default, editorial, motion-forward**. Think a printed sports magazine cover: pitch-black paper, a single electric lime spot color, giant italic display type, and micro-labels in a monospaced font set in wide tracking. Rounded corners are **generous and friendly** (pill buttons, 16–20px cards, 28px hero pills) — this is the softness that keeps the aggressive type from feeling threatening.

### Colors

- **Canvas:** `#0A0B0A` (dark) / `#F8F8F4` (light). Not pure black/white — both have a whisper of warmth.
- **Primary accent:** `#BBFB46` electric lime. Used ONLY for: primary CTAs, active states, brand punch words, and key data points (visit counts, prices). If everything is lime, nothing is.
- **Lime gradient:** `#BBFB46 → #D5FF7E` on primary buttons, visit rings, avatar backgrounds.
- **Semantic:** `#FF453A` danger, `#30D158` success, `#FFD60A` warn, `#61CDFF` info. iOS-style saturation.
- **Tier palette:** Silver `#C0C0C0`, Gold `#FFD60A`, Platinum `#E0E6FF`, Diamond `#64D2FF`.
- **Category palette:** Gym=lime, Crossfit=green, Martial=red, Yoga=purple `#BF5AF2`.

### Type

- **Display:** `Archivo Black Italic` — 900 weight, italic by default. Sizes 26–54px+, letter-spacing `-0.03` to `-0.04em`, line-height `0.86–0.92`. Headlines feel like they're leaning forward.
- **Serif accent:** `Instrument Serif Italic` — paired with Archivo at ~0.7× the display size, colored lime. The emotional beat inside a headline.
- **Body:** `Inter` 400/500/600/700 — clean, neutral, legible at 13–15px.
- **Mono:** `JetBrains Mono` 400/500/600 — exclusively for overlines, labels, timestamps, codes, prices-in-mono-context. 9–11px with `0.14–0.24em` tracking, ALL CAPS.
- **Arabic swap:** in RTL, display swaps to **Cairo Black**, body to **Cairo Regular**. Archivo glyphs don't render Arabic.

### Backgrounds, textures, gradients

- **Dark canvas with subtle radial glow.** A lime radial gradient `ellipse 1000px 500px at 15% 0%` at 5–8% opacity gives the black a warmth, like studio lighting.
- **SVG fractal-noise overlay at 4% opacity** with `mix-blend-mode: overlay` — gives the black a faint grain, like newsprint. Not a hard texture, a whisper.
- **Card radial glows.** Hero cards (active subscription, plan details) have a `radial-gradient at top right, rgba(187,251,70,0.12), transparent 60%` that acts like a spotlight catching the edge of the card.
- **No stock photography.** Gym imagery placeholders use an abstract lime-tinted gradient background with an iconic line-art SVG (dumbbell, heart, activity) at ~25% opacity centered. This is intentional for AR cultural sensitivity and for the editorial visual voice.
- **No hand-drawn illustrations, no textures-as-backgrounds, no repeating patterns.** The grain is it.

### Animation & motion

- **Easing:** default `cubic-bezier(0.4, 0, 0.2, 1)` — iOS-style, a touch of snap. Springs on active state changes (tab switch).
- **Pulses.** The lime LIVE dot pulses: `scale(0.6→1.6)` + `opacity 1→0` over 1.8s, ease-out, infinite. Used on "LIVE NOW" hero cards and active-plan indicators.
- **QR scanline.** A lime horizontal line bounces top-to-bottom in the camera viewport, 2.5s ease-in-out infinite.
- **Cursor blink.** OTP active cell has a 2px lime bar blinking at 1s intervals.
- **Success ring.** On payment-success, a lime concentric ring pulses outward once, ~600ms.
- **Page transitions.** Slide-in from leading edge (auto-flips in RTL).
- **No bounces, no wobbles, no fades longer than 200ms.** The motion vocabulary is tight and technical.

### Hover & press states

- **Hover (web/card previews):** text links shift to lime. Cards gain `border-color: rgba(187,251,70,0.25)` at 150ms.
- **Press:** buttons drop shadow intensity and scale `0.97`. Tabs in the bottom bar scale-spring to lime background. Haptic feedback on every primary action (medium impact for CTAs, light for taps).
- **Disabled:** 40% opacity, no other treatment. Do not desaturate or change color.

### Borders, dividers, shadows

- **Borders:** `rgba(255,255,255,0.08)` default (dark) / `rgba(10,11,10,0.08)` default (light). Stronger borders at `0.14` for card edges and tab bar.
- **Dividers:** `1px dashed transparent` on list hovers, `1px solid var(--border)` between rows, `linear-gradient(90deg, transparent, var(--border-2), transparent)` for decorative section dividers.
- **Outer shadows:** `0 15px 30px -10px rgba(187,251,70,0.3)` on primary lime buttons — a colored glow below, not a neutral drop shadow. `0 30px 60px -15px rgba(0,0,0,0.7)` on phone frames.
- **Inner shadows:** on focused inputs: `box-shadow: 0 0 0 3px rgba(187,251,70,0.08)` — a soft lime halo outside the border.
- **No protection gradients** behind text over imagery — instead a bottom-to-top `linear-gradient(to bottom, transparent 40%, rgba(10,11,10,0.95))` overlay on hero images.

### Transparency & blur

- **Bottom tab bar:** `rgba(14,14,12,0.92)` + `backdrop-filter: blur(20px)` — the one place glass-morphism appears.
- **Image overlays:** solid gradients, not blur.
- **Modal backdrops:** `rgba(0,0,0,0.55)` solid — no blur, to keep the UI feeling printed.

### Corner radii (the friendly rounding)

- **8px** — small chips, tags
- **12px** — icon tiles, small buttons, inputs inside cards
- **16px** — inputs, standard cards
- **18–20px** — large cards, sheets, phone screen content
- **28px** — input pills, hero pill cards (this is the signature friendly radius — aggressively round without being full-pill)
- **100px (pill)** — every primary button, every bottom-tab item, every chip, every tier badge. **When in doubt, pill it.**

### Cards

- Background: `#171A19` (dark) / `#FFFFFF` (light)
- Border: 1px, 8% opposite-ink
- Radius: 16–20px
- Padding: 16–24px
- No drop shadow by default. Elevation is communicated by the lime radial-glow in the top-right corner of hero cards and by the border contrast.

### Layout rules

- **Mobile-first 390px safe width.** All screens designed at 375–414px width.
- **Fixed elements:** bottom tab bar (58px tall, pill container, 12px margin from screen edge), status bar (44px, always styled). Sticky bottom CTAs on detail screens have a 24px margin from the bottom edge.
- **Screen padding:** 18px horizontal is standard. 20–24px on auth screens for more breathing room.
- **Vertical rhythm:** 22–28px between major sections. Section heads are 12px above content.
- **Grid systems:** 2-col for gym cards, 3-col for stats, 4-col for amenities and category pickers. Gaps: 6–10px (tight) for equipment grids, 10–16px (medium) for content grids.

---

## ICONOGRAPHY

Gym Pass uses **Lucide-style monochromatic line icons** at 1.5–2px stroke weight. No icon font, no emoji — all icons are inline SVG defined once in a `<defs>` block and referenced with `<use href="#pi-..."/>`. Stroke is always `currentColor` so color inherits from context.

### Icon set

The source defines **~30 custom SVG icons** matching the Lucide/Feather style family: `pi-arrow`, `pi-back`, `pi-bell`, `pi-home`, `pi-qr`, `pi-user`, `pi-search`, `pi-filter`, `pi-heart`, `pi-star`, `pi-pin`, `pi-dumbbell`, `pi-activity`, `pi-flash`, `pi-flame`, `pi-wifi`, `pi-lock`, `pi-droplet`, `pi-car`, `pi-shield`, `pi-gift`, `pi-check`, `pi-chev`, `pi-clock`, `pi-receipt`, `pi-card`, `pi-gear`, `pi-logout`, `pi-sun`, `pi-moon`, `pi-globe`, `pi-mail`.

These are stored as a single sprite in `assets/icons.svg` and can be referenced from any screen via `<svg><use href="assets/icons.svg#pi-dumbbell"/></svg>`.

**Substitution note:** The source file inlines custom Lucide-style SVGs. For parity and maintainability, the UI kit uses **Lucide** (`https://unpkg.com/lucide@latest`) via CDN — stroke weight, line caps, and style match perfectly. If production Flutter code is built, use `lucide_icons` package.

### Glyph characters (non-icon ornaments)

The brand also uses **Unicode glyphs as structural ornaments** in copy and labels:

| Glyph | Usage |
|---|---|
| `◆` | Sub-section prefix, Gold tier badge, section dividers |
| `◇` | Silver tier badge |
| `◈` | Platinum tier badge |
| `◉` | Diamond tier badge |
| `●` | Overline/label bullet (always before UPPERCASE micro-labels), live status dots |
| `→` | Inline CTAs, "view more" affordance |
| `·` | Inline metadata separator ("Abdoun · 0.8 km") |

These are NOT icons — they're typography. They live inside `<span>` or directly in copy, never inside an icon slot.

### Logos

The brand mark is a **wordmark only** — **GYMPASS** set as a single word in Archivo Black Italic. `GYM` in ink, `PASS` in lime `#BBFB46`. Leaning forward (italic), punched-together (no space, no separator). Letter-spacing `-0.045em`. Sizes 22–112px+.

`assets/gym-pass-wordmark.svg` provides the wordmark. For chip-sized UI (nav bars, badges), use the full wordmark — do NOT abbreviate or separate. Never swap colors, never use pure black/green, never use non-italic. Outside dark canvas: GYMPASS set in a lime pill with both words in `#0A0B0A` (PASS at 55% opacity) is the alternate lockup.

### Imagery strategy

**No stock photography.** Per cultural-sensitivity notes in the source: imagery of gym equipment is OK; avoid revealing workout attire; prefer abstract/icon-driven visuals over photos of people. Gym placeholders render as a **dark gradient tile with a large, lime-tinted line-art SVG centered at low opacity**. This is not a limitation — it's the aesthetic.

---

*Next: see `ui_kits/mobile_app/index.html` for the interactive member-app prototype and `preview/*.html` for all design-system tokens rendered as review cards.*
