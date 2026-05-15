# website/ — GymPass marketing site

Single-page marketing surface served at the apex `https://gym-pass.net`.
Two purposes:

1. Pitch the member app — three-scene scrolly explaining sign-in,
   tier pick, and QR scan. Closes with an APK download button.
2. Hand off gym owners — partner-pill in the nav, dedicated partner
   strip, both pointing at `https://partner.gym-pass.net`.

There is **no registration, payment, or auth here.** All of that
lives inside the Flutter member app. The website's only job is to
get a member to the APK and a partner to their portal.

## How the page is served

The actual design is a Claude-Design HTML prototype:
**[public/register-flow.html](public/register-flow.html)**.

Next.js is wrapped around it for three reasons:

- `output: 'standalone'` makes the production container ~120 MB
  instead of a multi-GB Node runtime.
- The `/downloads/gympass.apk` static asset rides on the same
  container (so APK release = re-deploy of one service).
- Matches the admin / gym-partner deployment shape, so
  `docker-compose.prod.yml` doesn't need a special path for this.

A single rewrite in [next.config.js](next.config.js) maps `/` →
`/register-flow.html` so the canonical URL stays clean.

## Updating the design

The design is owned by **Claude Design** (claude.ai/design). The
incoming bundle from the design tool lands in `/design-brief/` of
the repo, with the canonical HTML prototype + a chat transcript
explaining intent.

To re-flow a new design pass:

1. Read the new chat transcript under `design-brief/source-code/`
   (or the latest `simple/chats/`) and the updated HTML.
2. Replace [public/register-flow.html](public/register-flow.html)
   wholesale — don't merge inline edits, since the design tool
   regenerates the whole file each round.
3. Re-wire the four production-only links (search for `gympass.apk`
   and `partner.gym-pass.net` to find them).
4. Smoke test: `npm run dev` then visit `http://localhost:3004/`.
5. Verify the dark/light toggle persists across reloads, the
   scrolly cycles through all three phone scenes, and the access
   stack auto-cycles + hover-locks correctly.

## Production-wired links

These are the only diff points between the design-bundle HTML and
what ships here. If you swap in a new design pass, re-apply them.

| Where | Original (design) | Wired-up |
| --- | --- | --- |
| Hero App Store / Play Store buttons | `#download` / `#` | `/downloads/gympass.apk` |
| Closer App Store / Play Store buttons | `#` | `/downloads/gympass.apk` |
| "Download APK directly" | `#` | `/downloads/gympass.apk` |
| Partner pill (nav + closer) | already `https://partner.gym-pass.net` | (no change) |

Once the App Store / Play Store listings are live, swap those four
APK hrefs to the real store URLs and update the inline labels.

## Dev

```bash
cd website
npm install
npm run dev      # http://localhost:3004
npm run build && npm start
```

## Prod

Built by the top-level deploy pipeline:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build website
```

Served behind nginx at `https://gym-pass.net` (see
`nginx/conf.d/website.conf`).
