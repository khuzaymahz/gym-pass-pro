import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing app preferences. Backed by [SharedPreferences] (not
/// secure_storage) — these aren't secrets, and SharedPreferences's
/// synchronous-after-init API lets us read locale + themeMode
/// **before the first frame paints** so the splash and the rest of
/// the app start in the user's chosen language + palette without
/// the ~50–800 ms flash from defaults that the previous
/// secure_storage-backed setup produced.
///
/// **`themeMode`**: defaults to `dark` — the brand's primary
/// surface. The settings page and the auth-screen toggle expose a
/// binary picker (Light / Dark only); auto-following the OS was
/// dropped because mid-session theme flips surprise members more
/// than they help. Both palettes are defined in `GpColors.dark` /
/// `GpColors.light` and built by `AppTheme`.
class AppPreferences {
  final Locale locale;
  final ThemeMode themeMode;
  final bool notifPlanReminders;
  final bool notifClubsNearby;
  final bool notifPromos;
  final double textScale;
  final double layoutScale;

  const AppPreferences({
    // EN is the constructor default — the "I have no information"
    // fallback. First-launch users get the device's system locale
    // via `_parseLocale` below; only callers that construct
    // `AppPreferences()` without going through `loadAppPreferences`
    // (tests, golden-state captures) hit this default. They used
    // to land on AR which silently shaped every test as the AR
    // path; English-first is the safer neutral.
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.dark,
    this.notifPlanReminders = true,
    this.notifClubsNearby = true,
    this.notifPromos = false,
    this.textScale = 1.0,
    this.layoutScale = 1.0,
  });

  AppPreferences copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    bool? notifPlanReminders,
    bool? notifClubsNearby,
    bool? notifPromos,
    double? textScale,
    double? layoutScale,
  }) {
    return AppPreferences(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      notifPlanReminders: notifPlanReminders ?? this.notifPlanReminders,
      notifClubsNearby: notifClubsNearby ?? this.notifClubsNearby,
      notifPromos: notifPromos ?? this.notifPromos,
      textScale: textScale ?? this.textScale,
      layoutScale: layoutScale ?? this.layoutScale,
    );
  }
}

/// Storage keys. Kept consistent with the legacy secure_storage
/// names so the migration step in `loadAppPreferences` can find
/// values written by previous app versions.
const _kLocale = 'pref.locale';
const _kTheme = 'pref.theme';
const _kNotifPlan = 'pref.notif.plan';
const _kNotifClubs = 'pref.notif.clubs';
const _kNotifPromos = 'pref.notif.promos';
const _kTextScale = 'pref.textScale';
const _kLayoutScale = 'pref.layoutScale';

/// Resolve the initial locale.
///
/// Order:
///   1. A previously-saved choice (`'en'` / `'ar'`) wins. Once a
///      member has picked a locale in Settings, that decision
///      sticks across reinstalls (within the same device) until
///      they change it.
///   2. Otherwise, mirror the device's system locale: AR-family
///      systems start the app in Arabic; everything else starts
///      in English. We MUST cover the broader AR-script locale
///      tags here — Android / iOS surface `ar`, `ar_SA`, `ar_JO`,
///      `ar_AE`, `ar_EG`, etc.; matching on `languageCode == 'ar'`
///      catches them all because that field strips the region.
///   3. If we can't read the system locale at all (extreme edge
///      case — should never happen on Android/iOS but the API
///      surface is non-null so we guard defensively), fall back
///      to EN as the safer neutral default. AR-default would
///      surprise the typical non-AR member who installs the app
///      cold without any prior preference.
Locale _parseLocale(String? v) {
  if (v == 'en') return const Locale('en');
  if (v == 'ar') return const Locale('ar');
  try {
    final system = ui.PlatformDispatcher.instance.locale;
    if (system.languageCode == 'ar') return const Locale('ar');
  } catch (_) {
    // PlatformDispatcher not available — fall through to EN.
  }
  return const Locale('en');
}

ThemeMode _parseThemeMode(String? v) {
  // Only `light` and `dark` are valid now. A previously-saved
  // `system` value (or anything else) falls through to the dark
  // default — first interaction with the picker overwrites it.
  if (v == 'light') return ThemeMode.light;
  return ThemeMode.dark;
}

String _serializeThemeMode(ThemeMode m) {
  return m == ThemeMode.light ? 'light' : 'dark';
}

bool _parseBool(String? v, {required bool defaultValue}) {
  if (v == null) return defaultValue;
  return v == '1' || v == 'true';
}

/// Awaited once in `main()` before `runApp()` so the splash's
/// first frame paints the user's chosen locale + theme. Returns:
///   - the [SharedPreferences] handle, kept alive for the
///     [AppPreferencesNotifier] writers;
///   - the materialised initial [AppPreferences] (locale + theme
///     are real, notifications start at defaults and are
///     reconciled below).
///
/// If SharedPreferences is empty (first launch after upgrade from
/// the old secure_storage-only setup), falls back to a one-shot
/// secure_storage read so existing users don't lose their
/// settings. We pay the ~500–1500 ms Keystore init cost **once**
/// per device for migration; every subsequent launch is the fast
/// SharedPreferences path.
Future<({SharedPreferences shared, AppPreferences initial})>
    loadAppPreferences() async {
  final shared = await SharedPreferences.getInstance();

  // Migration: SharedPreferences is empty for our keys but
  // secure_storage might still hold a previous user's choice.
  // Copy across so the next read is fast.
  if (!shared.containsKey(_kLocale) && !shared.containsKey(_kTheme)) {
    try {
      const legacy = FlutterSecureStorage();
      final loc = await legacy.read(key: _kLocale);
      final theme = await legacy.read(key: _kTheme);
      final plan = await legacy.read(key: _kNotifPlan);
      final clubs = await legacy.read(key: _kNotifClubs);
      final promos = await legacy.read(key: _kNotifPromos);
      if (loc != null) await shared.setString(_kLocale, loc);
      if (theme != null) await shared.setString(_kTheme, theme);
      if (plan != null) await shared.setString(_kNotifPlan, plan);
      if (clubs != null) await shared.setString(_kNotifClubs, clubs);
      if (promos != null) await shared.setString(_kNotifPromos, promos);
    } catch (_) {
      // Keystore unavailable / fresh device / corrupted secure_storage —
      // fall through to defaults silently. This is the no-prior-
      // settings case anyway.
    }
  }

  final initial = AppPreferences(
    locale: _parseLocale(shared.getString(_kLocale)),
    themeMode: _parseThemeMode(shared.getString(_kTheme)),
    notifPlanReminders:
        _parseBool(shared.getString(_kNotifPlan), defaultValue: true),
    notifClubsNearby:
        _parseBool(shared.getString(_kNotifClubs), defaultValue: true),
    notifPromos:
        _parseBool(shared.getString(_kNotifPromos), defaultValue: false),
    textScale:
        double.tryParse(shared.getString(_kTextScale) ?? '') ?? 1.0,
    layoutScale:
        double.tryParse(shared.getString(_kLayoutScale) ?? '') ?? 1.0,
  );
  return (shared: shared, initial: initial);
}

class AppPreferencesNotifier extends StateNotifier<AppPreferences> {
  AppPreferencesNotifier(this._shared, AppPreferences initial) : super(initial);

  final SharedPreferences _shared;

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _shared.setString(_kLocale, locale.languageCode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _shared.setString(_kTheme, _serializeThemeMode(mode));
  }

  Future<void> setNotifPlanReminders(bool value) async {
    state = state.copyWith(notifPlanReminders: value);
    await _shared.setString(_kNotifPlan, value ? '1' : '0');
  }

  Future<void> setNotifClubsNearby(bool value) async {
    state = state.copyWith(notifClubsNearby: value);
    await _shared.setString(_kNotifClubs, value ? '1' : '0');
  }

  Future<void> setNotifPromos(bool value) async {
    state = state.copyWith(notifPromos: value);
    await _shared.setString(_kNotifPromos, value ? '1' : '0');
  }

  Future<void> setTextScale(double value) async {
    state = state.copyWith(textScale: value);
    await _shared.setString(_kTextScale, value.toString());
  }

  Future<void> setLayoutScale(double value) async {
    state = state.copyWith(layoutScale: value);
    await _shared.setString(_kLayoutScale, value.toString());
  }
}

/// Provider declaration without an initial state — `main()` must
/// override this with the synchronously-loaded prefs from
/// [loadAppPreferences] before `runApp`. Reading it without the
/// override throws a clear error rather than silently using
/// defaults that would re-introduce the cold-start flash.
final appPreferencesProvider =
    StateNotifierProvider<AppPreferencesNotifier, AppPreferences>((ref) {
  throw StateError(
    'appPreferencesProvider was read before main() injected the '
    'sync-loaded prefs. Make sure runApp() wraps the app in a '
    'ProviderScope with an override built from loadAppPreferences().',
  );
});

/// Raw SharedPreferences handle so other features (favourites,
/// recently-viewed, etc.) can read/write durable, non-secret state
/// without re-paying the `getInstance()` cost. `main()` overrides
/// this with the instance produced by [loadAppPreferences]. Reading
/// the provider without that override throws so we don't silently
/// fall back to in-memory state that resets on cold start.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'sharedPreferencesProvider was read before main() injected the '
    'sync-loaded SharedPreferences handle.',
  );
});
