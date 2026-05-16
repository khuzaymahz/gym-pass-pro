import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/connectivity.dart';
import '../../../core/prefs/app_preferences.dart';
import 'gym_summary.dart';

class GymRepository {
  GymRepository(this._client);
  final ApiClient _client;

  Future<GymSummary?> getBySlug(String slug) async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/v1/gyms/by-slug/$slug');
    final data = response.data;
    if (data == null) return null;
    return GymSummary.fromJson(data);
  }

  /// Fetches all active gyms in a single page. The home page uses this to
  /// derive accurate per-category counts and the gyms list reuses the same
  /// data so both surfaces agree on what's actually live in the network.
  ///
  /// `requireAuth: true` attaches the bearer token via the auth
  /// interceptor when the member is signed in — the backend uses the
  /// caller's profile gender to filter out single-sex gyms that don't
  /// match (a male member never receives `female_only` rows, and
  /// vice versa). The endpoint is also reachable anonymously: a
  /// signed-out caller gets the mixed-only subset.
  Future<List<Map<String, dynamic>>> listAllRaw() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/gyms?pageSize=100',
      authed: true,
    );
    final data = response.data;
    if (data == null) return const [];
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<GymSummary>> listAll() async {
    final raw = await listAllRaw();
    return raw.map(GymSummary.fromJson).toList();
  }
}

final gymRepositoryProvider = Provider<GymRepository>((ref) {
  return GymRepository(ref.read(apiClientProvider));
});

/// Fetches the backend gym record for a slug. Returns null on any failure
/// (offline, 404 before backend is seeded) so callers can degrade to their
/// local seed data without blowing up the UI.
final gymBySlugProvider =
    FutureProvider.family.autoDispose<GymSummary?, String>((ref, slug) async {
  try {
    final repo = ref.read(gymRepositoryProvider);
    return await repo.getBySlug(slug);
  } catch (_) {
    return null;
  }
});

/// Source of the data the UI is currently rendering. Drives the
/// thin "you're offline, showing your saved list" banner copy in
/// `ConnectivityBanner` and the empty-state distinction between
/// "the network has zero gyms" and "we couldn't reach the network."
enum GymsListSource {
  /// First-paint state, no network attempt has resolved yet.
  /// Cached items may have been hydrated synchronously already.
  loading,

  /// Backend returned a fresh list. The cache has been written.
  fresh,

  /// Network call failed (offline, DNS, timeout, 5xx). The list
  /// rendered is the most recently cached one — possibly empty if
  /// the user has never had a successful fetch on this device.
  cached,
}

/// Wire-shape exposed to the UI: items + freshness signal. The
/// items field is **always** populated (possibly empty), so widgets
/// don't need to special-case loading. The source field lets the
/// chrome render an honest offline indicator when appropriate.
class GymsListState {
  const GymsListState({
    required this.items,
    required this.source,
    this.error,
  });

  final List<GymSummary> items;
  final GymsListSource source;

  /// Human-ignorable error string from the last failed fetch. Not
  /// shown verbatim to users — the banner picks a friendly copy by
  /// `source == cached`. Kept here for log / debug surfaces only.
  final String? error;

  GymsListState copyWith({
    List<GymSummary>? items,
    GymsListSource? source,
    String? error,
  }) {
    return GymsListState(
      items: items ?? this.items,
      source: source ?? this.source,
      error: error,
    );
  }
}

const _kCacheKey = 'cache.gyms_list.v1';

/// SharedPreferences-backed cache for the gym list. Survives cold
/// starts so a member who lost connectivity mid-flight still sees
/// the list they had a moment ago, instead of an empty state that
/// reads as "the network has no gyms."
List<GymSummary> _readCache(SharedPreferences prefs) {
  final raw = prefs.getString(_kCacheKey);
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => GymSummary.fromJson(m.cast<String, dynamic>()))
        .toList();
  } catch (_) {
    // Cache version mismatch / corruption — drop silently. Fresh
    // fetch on next online cycle will overwrite.
    return const [];
  }
}

Future<void> _writeCache(
  SharedPreferences prefs,
  List<Map<String, dynamic>> rawItems,
) async {
  try {
    await prefs.setString(_kCacheKey, jsonEncode(rawItems));
  } catch (_) {
    // Cache write failure (disk full, etc.) — non-fatal.
  }
}

/// Cache-aware gyms list. UI surfaces should watch this instead of
/// the raw `gymsListProvider` so they get the cached-data fallback
/// and freshness signal for free.
///
/// Lifecycle:
///   1. On first read: synchronously read the SharedPreferences cache
///      and seed state. UI paints immediately if a cache exists.
///   2. Kick off the network fetch.
///   3. On success: persist + flip source to `fresh`.
///   4. On failure: keep the cached items, flip source to `cached`,
///      attach a sanitized error message for logs.
///   5. When `connectivityProvider` transitions back to online,
///      auto-retry via `ref.listen`.
final gymsListStateProvider =
    StateNotifierProvider<GymsListNotifier, GymsListState>((ref) {
  final notifier = GymsListNotifier(
    repo: ref.watch(gymRepositoryProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
  // Auto-retry when connectivity is restored. A stale cache is
  // valuable but transient — the moment the OS reports an interface,
  // refresh so the user gets fresh data without a manual pull.
  ref.listen<NetworkStatus>(connectivityProvider, (prev, next) {
    if (next == NetworkStatus.online &&
        prev == NetworkStatus.offline &&
        notifier.mounted) {
      notifier.refresh();
    }
  });
  // First fetch — fire and forget; the notifier's initial state
  // already shows the cached items so the UI doesn't wait on this.
  // ignore: discarded_futures
  notifier.refresh();
  return notifier;
});

class GymsListNotifier extends StateNotifier<GymsListState> {
  GymsListNotifier({required this.repo, required this.prefs})
      : super(
          GymsListState(
            items: _readCache(prefs),
            source: GymsListSource.loading,
          ),
        );

  final GymRepository repo;
  final SharedPreferences prefs;

  Future<void> refresh() async {
    try {
      final raw = await repo.listAllRaw();
      final items = raw.map(GymSummary.fromJson).toList();
      await _writeCache(prefs, raw);
      if (!mounted) return;
      state = GymsListState(items: items, source: GymsListSource.fresh);
    } catch (e) {
      if (!mounted) return;
      // Preserve the items we already have (from cache or a prior
      // fresh fetch this session). Only the freshness signal +
      // error string change.
      state = state.copyWith(
        source: GymsListSource.cached,
        error: e.toString(),
      );
    }
  }
}

/// Back-compat shim — existing callers `ref.watch(gymsListProvider)`
/// against an `AsyncValue<List<GymSummary>>`. Build that view on top
/// of the new cache-aware state so we don't have to rewrite every
/// consumer in one go. Loading state is reported only when we have
/// no cached items to show; once a cache exists we always have data
/// and the `cached` vs `fresh` distinction lives in the parallel
/// `gymsListStateProvider`.
final gymsListProvider = Provider<AsyncValue<List<GymSummary>>>((ref) {
  final state = ref.watch(gymsListStateProvider);
  switch (state.source) {
    case GymsListSource.loading:
      if (state.items.isEmpty) return const AsyncValue.loading();
      return AsyncValue.data(state.items);
    case GymsListSource.fresh:
    case GymsListSource.cached:
      return AsyncValue.data(state.items);
  }
});

/// Backwards-compatible `.future` accessor for pull-to-refresh
/// callers. Forces a fresh fetch and resolves when it completes
/// (whether successfully or via the cached-fallback path).
final gymsListRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(gymsListStateProvider.notifier).refresh();
});
