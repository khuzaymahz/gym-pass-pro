import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/providers.dart';
import 'day_pass.dart';

/// Wraps the day-pass HTTP surface. Three callable shapes:
///
///   * `offeringFor(slug)`         — public, unauth'd
///   * `purchase(slug, payment…)`  — authed, creates a new pass
///   * `listActive()`              — authed, member's pass list
///
/// Authentication is handled by the `ApiClient` — the `authed: true`
/// flag injects the bearer token from the token store.
class DayPassRepository {
  DayPassRepository(this._api);

  final ApiClient _api;

  /// Public read of a gym's offering. The backend always returns a
  /// body (synthesizing `isEnabled: false` for gyms without a row),
  /// so this method never returns null on a successful call — it
  /// only throws on transport/auth errors.
  Future<DayPassOffering> offeringFor(String gymSlug) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/gyms/$gymSlug/day-pass-offering',
    );
    return DayPassOffering.fromJson(response.data!);
  }

  /// Buy a pass for the given gym. `paymentMethodKind` mirrors the
  /// subscription purchase flow — same enum, same mock-now-real-later
  /// adapter on the backend. Returns the freshly-activated pass on
  /// success; throws on payment-decline / audience-locked / already-
  /// subscribed and the other denied paths the service enforces.
  Future<DayPass> purchase({
    required String gymSlug,
    required String paymentMethodKind,
    String? paymentMethodId,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/day-passes',
      body: {
        'gymSlug': gymSlug,
        'paymentMethod': paymentMethodKind,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
      },
      authed: true,
    );
    return DayPass.fromJson(response.data!);
  }

  /// All non-expired passes the caller owns — active first. The
  /// Profile screen's "Active passes" card reads this; the gym-
  /// detail page reads it to decide whether the day-pass holder
  /// sees "Check in here" (already paid) or "Try today" (needs to
  /// buy).
  Future<List<DayPass>> listActive() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/day-passes',
      authed: true,
    );
    final items = (response.data?['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((m) => DayPass.fromJson(m.cast<String, dynamic>()))
        .toList();
  }
}

final dayPassRepositoryProvider = Provider<DayPassRepository>((ref) {
  return DayPassRepository(ref.read(apiClientProvider));
});

/// Per-gym offering. Family provider keyed on the gym slug so each
/// gym detail page caches its own offering independently. Auto-
/// disposes when no listener remains. Cheap to refetch on cold
/// remount — the backend serves this without auth.
final dayPassOfferingProvider =
    FutureProvider.family.autoDispose<DayPassOffering, String>((ref, slug) {
  return ref.read(dayPassRepositoryProvider).offeringFor(slug);
});

/// Caller's own active day passes. Watched by the Profile "Active
/// passes" card AND the gym-detail page (to skip the "Try today"
/// CTA when a pass for *this* gym already exists). Auto-refresh
/// on pull-to-refresh of either surface.
final myDayPassesProvider =
    FutureProvider.autoDispose<List<DayPass>>((ref) {
  return ref.read(dayPassRepositoryProvider).listActive();
});
