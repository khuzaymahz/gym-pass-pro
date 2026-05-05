# Admin console — design direction

> Read this before touching UI in `admin/`. It exists so every new surface lands in the same visual register instead of defaulting to generic dashboard chrome.

## Brief

The GymPass admin is an **operations console**, not a marketing dashboard. The audience is internal: 2–5 people who open it every day to spot anomalies, resolve tickets, audit payouts, and rotate QR codes. They need **density without clutter** and **immediate legibility of the single most important number on every page**.

Visual reference: Bloomberg Terminal × Monocle magazine × The New York Times masthead. Editorial, typographic, hairline-ruled. Not "web app card grid".

## Principles

1. **Typography does the heavy lifting.** The design tokens ship three distinctive typefaces (Instrument Serif italic for display, Archivo Black for compact display, JetBrains Mono for data, Inter for body). Lean into that. A large italic serif numeral is a stronger design choice than a bordered card containing a small number.

2. **No card chrome.** The existing `.card` class (rounded border + padding + faint inner shadow) is avoided on new surfaces. Use `border-t border-line` rules with generous vertical padding to separate sections. Cards are reserved for genuinely floating panels (a ticket's reply composer, a modal), not for structuring the page itself.

3. **One hero per page.** Each page has a single headline metric rendered at magazine scale: italic serif, 6–9rem, with tiny all-caps mono label and delta directly underneath. Secondary metrics render as a typographic row separated by hairline vertical rules — think a newspaper masthead's weather/ticker strip.

4. **Asymmetric grids.** Avoid uniform 4-ups and 3-ups. Prefer 8/4, 7/5, 9/3 splits. Give the most important column the most space. Grid gaps are hairline rules, not gap-6 air.

5. **Lime is an accent, not a fill.** Use `text-lime` for the single most important interactive/positive signal on the page — the active filter, a positive delta, a "live" indicator. Don't flood the page with lime.

6. **Status as typography, not pills.** `● Open` (colored dot + word) beats a rounded badge with a background fill. The dot carries the tone; the word carries the meaning. Pills only for things the user directly clicks (filter chips).

7. **Tables are hairline-ruled lists.** No header background. No zebra-striping. Column headers are 10px uppercase mono with `tracking-[0.2em]`. Rows separated by `divide-y divide-line`. Hover is a subtle `bg-surface/40` tonal shift — never a lift or border change.

8. **Feeds read like agate columns.** Left: serif subject + small muted meta. Right: mono timestamp. A single hairline rule between rows. No avatars, no action buttons inline — click the row to drill in.

9. **Motion is subtle.** One staggered fade-in on first paint (`animation-delay` cascading through children). Hover states change color, never position. No toast explosions, no confetti.

10. **Whitespace is not the enemy.** Operators scan dense layouts faster when the dense regions are framed by generous air. Don't compress the masthead to fit more KPIs; cut the KPIs.

## Utility classes (globals.css)

Use these rather than re-inventing per-page styling:

- `.rule` — `border-t border-line`, top margin 8, top padding 8. A section divider.
- `.label` — `text-[10px] font-mono uppercase tracking-[0.25em] text-muted`. All-caps section labels.
- `.hero-num` — `font-display text-[7rem] leading-none italic text-paper`. The page's headline number.
- `.stat-num` — `font-display text-4xl italic text-paper`. Secondary metric numerals.
- `.vr` — a 1px vertical rule for row-based dividers.
- `.chip` / `.chip-active` — inline filter chips with a dot prefix.
- `.agate` — feed-item list row: hairline-ruled, flex justify-between, serif-left / mono-right.
- `.fade-in` — 400ms ease-out translate+opacity with a CSS var `--delay` for staggering.

## Anti-patterns

- ❌ A row of 4–6 identically sized stat cards with bordered rounded corners.
- ❌ Rounded pill badges for status (`● Open` is enough).
- ❌ Chart containers with titles, borders, and gap — charts should live inline with the metric they illustrate.
- ❌ Adding color on color (amber on red on lime) — one accent per element, and the accent is almost always lime.
- ❌ Using purple/sky/pink tones. We have lime, amber, red. That's enough.
- ❌ Lift-on-hover (translate, shadow, border thickening). We shift color only.

## Per-page hero metrics

Use this as the default "hero number" for each page. Override only with reason.

| Page | Hero |
|---|---|
| `/` (Dashboard) | Revenue MTD (JOD) with ±% vs. prev month |
| `/support` | Open tickets, with urgent count in red underneath |
| `/gyms` | Active gyms, with new-this-month delta |
| `/users` | Total members, with signups-this-week delta |
| `/subscriptions` | Active subscriptions, with MRR underneath |
| `/checkins` | Check-ins MTD, with today's count underneath |
| `/payouts` | Pending payout total, with count of gyms due |
| `/audit` | Events today, with flagged-events count |

## Checklist before shipping a new page

- [ ] One hero number at magazine scale.
- [ ] Zero `.card` wrappers unless the content genuinely floats.
- [ ] Column headers, section labels, section dividers are all in the mono label style.
- [ ] Status is a dot + word, not a filled pill.
- [ ] Filters are chips at the top of the list, not a form panel.
- [ ] The page reads as a single editorial column, not a grid of rectangles.
