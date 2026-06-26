---
name: l10n-sync
description: Add or change a mobile user-facing string across the lockstep i18n set (ARB en+ar AND the hand-maintained generated Dart) without running flutter gen-l10n. Use whenever a new label/sentence is needed in the Flutter app.
disable-model-invocation: true
---

# l10n-sync

Keep the mobile localization set **even and in lockstep**. In this repo the
three i18n files are the largest structures in the whole codebase, and the ARB
is **stale relative to the generated Dart** — so the normal `flutter gen-l10n`
flow is a trap: it regenerates from the stale ARB and silently deletes ~80
existing getters (and flips `of()` to nullable). We therefore hand-edit the
generated files. This skill does that safely.

## The five files that must stay in sync

| Role | Path |
|---|---|
| ARB — English (source of record) | `mobile/lib/l10n/app_en.arb` |
| ARB — Arabic | `mobile/lib/l10n/app_ar.arb` |
| Generated abstract (getter declarations) | `mobile/lib/l10n/app_localizations.dart` |
| Generated English impl | `mobile/lib/l10n/app_localizations_en.dart` |
| Generated Arabic impl | `mobile/lib/l10n/app_localizations_ar.dart` |

A key is only "done" when it exists in **all five**. EN and AR must always have
the **same set of keys**.

## Steps

1. **Confirm the key doesn't already exist.** Grep all five files for the
   proposed getter name. If it exists anywhere, you're editing, not adding —
   update every occurrence.
2. **Pick the name + decide if it's parameterized.**
   - Plain string → a getter: `String get gymLocationTitle;`
   - With a placeholder → a method: `String gymStatusClosesAt(String time);`
3. **Edit ARB (both):** add the key to `app_en.arb` and `app_ar.arb`. For
   placeholders include the `@key` metadata block with `placeholders`. Keep the
   two ARBs key-for-key identical; only the values differ.
4. **Edit the abstract** `app_localizations.dart`: add the matching
   `String get …;` / `String …(…);` declaration, placed near related keys.
5. **Edit both impls** `app_localizations_en.dart` and
   `app_localizations_ar.dart` with the concrete `@override` returning the
   localized value. Use the existing surrounding style (string interpolation
   for methods).
6. **Respect the i18n rules** from CLAUDE.md §10: Western digits `0–9` in both
   locales, currency/symbol *after* the number, phone `+962 7X XXX XXXX`.
7. **NEVER run `flutter gen-l10n`.** If something looks like it needs
   regeneration, stop and ask — regeneration would wipe getters.
8. **Verify:** `cd mobile && flutter analyze lib/l10n` (and the screen you used
   the key in). A missing override surfaces here as an unimplemented-getter
   error — that's the lockstep check doing its job.

## Quick parity check

```bash
cd mobile && flutter analyze lib/l10n
```

If analyze is clean and the key resolves in the calling screen, the set is even.
