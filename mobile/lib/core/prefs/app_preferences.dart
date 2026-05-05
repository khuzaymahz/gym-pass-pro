import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../di/providers.dart';

/// User-facing app preferences. Persists across launches via secure
/// storage so the member's locale, notification toggles, and theme
/// choice survive a reboot.
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

  const AppPreferences({
    this.locale = const Locale('ar'),
    this.themeMode = ThemeMode.dark,
    this.notifPlanReminders = true,
    this.notifClubsNearby = true,
    this.notifPromos = false,
  });

  AppPreferences copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    bool? notifPlanReminders,
    bool? notifClubsNearby,
    bool? notifPromos,
  }) {
    return AppPreferences(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      notifPlanReminders: notifPlanReminders ?? this.notifPlanReminders,
      notifClubsNearby: notifClubsNearby ?? this.notifClubsNearby,
      notifPromos: notifPromos ?? this.notifPromos,
    );
  }
}

class AppPreferencesNotifier extends StateNotifier<AppPreferences> {
  final FlutterSecureStorage _storage;
  static const _localeKey = 'pref.locale';
  static const _themeKey = 'pref.theme';
  static const _notifPlanKey = 'pref.notif.plan';
  static const _notifClubsKey = 'pref.notif.clubs';
  static const _notifPromosKey = 'pref.notif.promos';

  /// Set true the moment any setter fires. _load() consults this so a
  /// setter that beat the hydrate (rare but real on cold-start: user
  /// taps the locale toggle on the splash screen before the secure_storage
  /// read returns) doesn't get clobbered by stale stored values. Without
  /// this guard the user's tap "doesn't take" — they re-tap, see it
  /// flicker, and lose trust in the toggle.
  bool _userInteracted = false;

  AppPreferencesNotifier(this._storage) : super(const AppPreferences()) {
    // Defer the secure_storage read past the first frame so Android's
    // Keystore init (500–1500ms cold) doesn't block initial paint. The app
    // defaults to AR + system theme; if the user previously chose EN or
    // pinned dark/light, the first frame paints with defaults and flips
    // once [_load] completes — acceptable tradeoff for faster startup.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final locale = await _storage.read(key: _localeKey);
    final theme = await _storage.read(key: _themeKey);
    final plan = await _storage.read(key: _notifPlanKey);
    final clubs = await _storage.read(key: _notifClubsKey);
    final promos = await _storage.read(key: _notifPromosKey);
    if (_userInteracted) {
      // User already touched a setter while we were waiting on
      // secure_storage; their state wins. The setter already wrote
      // through to storage, so the *next* cold-start will read the
      // correct value naturally.
      return;
    }
    state = AppPreferences(
      locale: _parseLocale(locale),
      themeMode: _parseThemeMode(theme),
      notifPlanReminders: _parseBool(plan, defaultValue: true),
      notifClubsNearby: _parseBool(clubs, defaultValue: true),
      notifPromos: _parseBool(promos, defaultValue: false),
    );
  }

  Locale _parseLocale(String? v) {
    if (v == 'en') return const Locale('en');
    return const Locale('ar');
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

  Future<void> setLocale(Locale locale) async {
    _userInteracted = true;
    state = state.copyWith(locale: locale);
    await _storage.write(key: _localeKey, value: locale.languageCode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _userInteracted = true;
    state = state.copyWith(themeMode: mode);
    await _storage.write(key: _themeKey, value: _serializeThemeMode(mode));
  }

  Future<void> setNotifPlanReminders(bool value) async {
    _userInteracted = true;
    state = state.copyWith(notifPlanReminders: value);
    await _storage.write(key: _notifPlanKey, value: value ? '1' : '0');
  }

  Future<void> setNotifClubsNearby(bool value) async {
    _userInteracted = true;
    state = state.copyWith(notifClubsNearby: value);
    await _storage.write(key: _notifClubsKey, value: value ? '1' : '0');
  }

  Future<void> setNotifPromos(bool value) async {
    _userInteracted = true;
    state = state.copyWith(notifPromos: value);
    await _storage.write(key: _notifPromosKey, value: value ? '1' : '0');
  }
}

final appPreferencesProvider =
    StateNotifierProvider<AppPreferencesNotifier, AppPreferences>((ref) {
  return AppPreferencesNotifier(ref.read(secureStorageProvider));
});
