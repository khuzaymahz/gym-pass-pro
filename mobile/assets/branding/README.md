# App icons — source images

Two PNGs power every Android density bucket + every iOS size,
plus the iOS 18 light/dark appearance switch.

| File | Required size | Background | Notes |
|---|---|---|---|
| `app_icon_light.png` | 1024 × 1024 | White (`#FFFFFF`) | Default icon. Used on iOS pre-18 and as the light-mode variant on iOS 18+. Also the source for every Android density. |
| `app_icon_dark.png` | 1024 × 1024 | Black (`#000000`) | iOS 18+ dark-appearance variant. The system swaps automatically based on Settings → Display & Brightness. |

## Re-generate the icons

After replacing either PNG, run from `mobile/`:

```bash
dart run flutter_launcher_icons
```

This regenerates every PNG under:

- `mobile/android/app/src/main/res/mipmap-*/ic_launcher*.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/`

…and rewrites the iOS `Contents.json` with the right
`appearances` entries so iOS 18+ picks the dark variant in dark
mode automatically.

The generated files are committed alongside the source PNGs so
the `flutter build apk` / `flutter build ios` step doesn't need
the generator on PATH.

## Why not a single source + auto-recolor

You could ship a single transparent-background PNG and let the
build pipeline composite it onto white or black at generate-time.
Easier to maintain, but you give up control over per-mode logo
spacing and any per-mode color refinements. Two opaque sources is
~50 KB of extra assets in source control and zero ambiguity about
what the user sees.

## Android themed icons (Android 13+)

The pubspec config sets `adaptive_icon_monochrome` to the light
PNG, which Android 13's themed-icon feature uses to tint the
icon based on the user's wallpaper/theme. Older Android (8–12)
uses the foreground+background composition; pre-8 falls back to
the legacy `ic_launcher.png` files.
