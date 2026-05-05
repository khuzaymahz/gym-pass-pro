import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/providers.dart';

/// Single plan as the backend describes it. We keep numbers as `String` for
/// `priceJod` and `discountPercent` to mirror the wire shape and avoid float
/// drift; the UI parses to int once for display.
class BackendPlan {
  const BackendPlan({
    required this.id,
    required this.tierKey,
    required this.durationMonths,
    required this.priceJod,
    required this.monthlyVisits,
    required this.includedGymCount,
    required this.featuresEn,
    required this.featuresAr,
    required this.discountPercent,
    required this.isActive,
  });

  final String id;
  final String tierKey;
  final int durationMonths;
  final String priceJod;
  final int monthlyVisits;
  final int includedGymCount;
  final List<String> featuresEn;
  final List<String> featuresAr;
  final String discountPercent;
  final bool isActive;

  factory BackendPlan.fromJson(Map<String, dynamic> j) {
    return BackendPlan(
      id: j['id'] as String,
      tierKey: j['tier'] as String,
      durationMonths: j['durationMonths'] as int,
      priceJod: (j['priceJod'] ?? '0').toString(),
      monthlyVisits: j['monthlyVisits'] as int? ?? 0,
      includedGymCount: j['includedGymCount'] as int? ?? 0,
      featuresEn: ((j['featuresEn'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      featuresAr: ((j['featuresAr'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      discountPercent: (j['discountPercent'] ?? '0').toString(),
      isActive: j['isActive'] as bool? ?? true,
    );
  }
}

/// Repository for the read-only catalog of plans. Lives behind the same
/// API client as the rest of the app; all calls are authenticated so the
/// rate limit applies per-user even on the catalog read.
class PlanCatalogRepository {
  PlanCatalogRepository(this._api);

  final ApiClient _api;

  Future<List<BackendPlan>> list() async {
    final response = await _api.get<List<dynamic>>('/api/v1/plans');
    final raw = response.data ?? const [];
    return raw
        .map((e) => BackendPlan.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}

/// In-memory catalog cache. The list of plans changes rarely (admins
/// toggling rows) so a memo keyed off (tier, durationMonths) is fine for
/// the lifetime of an authenticated session. Cleared on logout via the
/// auth controller's clear-everything sweep.
class PlanCatalog {
  PlanCatalog(this._repo);

  final PlanCatalogRepository _repo;

  List<BackendPlan>? _cache;
  Future<List<BackendPlan>>? _inflight;

  Future<List<BackendPlan>> ensureLoaded() async {
    final existing = _cache;
    if (existing != null) return existing;
    final inflight = _inflight;
    if (inflight != null) return inflight;
    final fresh = _repo.list().then((rows) {
      _cache = rows;
      _inflight = null;
      return rows;
    }).catchError((Object e) {
      _inflight = null;
      throw e;
    });
    _inflight = fresh;
    return fresh;
  }

  /// Resolve `(tierKey, durationMonths)` to the backend plan id. Returns
  /// null when the catalog hasn't loaded yet OR when no active plan
  /// matches — both surface as "checkout unavailable" in the UI.
  String? findPlanId({required String tierKey, required int durationMonths}) {
    for (final plan in _cache ?? const []) {
      if (plan.tierKey == tierKey &&
          plan.durationMonths == durationMonths &&
          plan.isActive) {
        return plan.id;
      }
    }
    return null;
  }

  /// Reverse lookup: backend plan id → catalog row. Used to recover the
  /// duration / monthly_visits metadata for the active subscription so
  /// the UI can render renewal countdowns and visit caps without an
  /// extra round trip. Returns null if the catalog is empty or the id
  /// doesn't match a known plan (admin disabled it after the member
  /// bought, for example).
  BackendPlan? findById(String planId) {
    for (final plan in _cache ?? const []) {
      if (plan.id == planId) return plan;
    }
    return null;
  }

  void clear() {
    _cache = null;
    _inflight = null;
  }
}

final planCatalogRepositoryProvider = Provider<PlanCatalogRepository>((ref) {
  return PlanCatalogRepository(ref.read(apiClientProvider));
});

final planCatalogProvider = Provider<PlanCatalog>((ref) {
  return PlanCatalog(ref.read(planCatalogRepositoryProvider));
});
