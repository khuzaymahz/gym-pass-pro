import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/app_preferences.dart';

/// Persisted favourite-gym slugs. Backed by [SharedPreferences] under
/// the `pref.favorited_gyms` key so the heart-tap survives app
/// restarts. Previously this was a plain in-memory `StateProvider`,
/// which is why members were tapping favourites, leaving the app,
/// and coming back to an empty list. The notifier reads the saved
/// CSV on construction (synchronous read off the cached prefs
/// handle) and writes back on every mutation; failures during the
/// write are swallowed because losing one tap to disk is preferable
/// to crashing the UI.
const _kFavoritedGymsKey = 'pref.favorited_gyms';

class FavoritedGymsNotifier extends StateNotifier<Set<String>> {
  FavoritedGymsNotifier(this._shared) : super(_hydrate(_shared));

  final SharedPreferences _shared;

  static Set<String> _hydrate(SharedPreferences shared) {
    final raw = shared.getStringList(_kFavoritedGymsKey);
    if (raw == null || raw.isEmpty) return <String>{};
    return raw.toSet();
  }

  void _persist() {
    _shared
        .setStringList(_kFavoritedGymsKey, state.toList(growable: false))
        .ignore();
  }

  /// Idempotent — adding an already-favourited slug is a no-op.
  /// Returns true when the slug was newly added (UI can show a
  /// confirmation snack), false when it was already present.
  bool add(String slug) {
    if (state.contains(slug)) return false;
    state = {...state, slug};
    _persist();
    return true;
  }

  bool remove(String slug) {
    if (!state.contains(slug)) return false;
    state = {...state}..remove(slug);
    _persist();
    return true;
  }

  /// Toggle and return the resulting membership ("did we just add it?").
  bool toggle(String slug) {
    if (state.contains(slug)) {
      remove(slug);
      return false;
    }
    add(slug);
    return true;
  }
}

final favoritedGymsProvider =
    StateNotifierProvider<FavoritedGymsNotifier, Set<String>>((ref) {
  return FavoritedGymsNotifier(ref.watch(sharedPreferencesProvider));
});
