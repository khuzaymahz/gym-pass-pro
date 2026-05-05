import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/providers.dart';
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
  Future<List<GymSummary>> listAll() async {
    final response = await _client
        .get<Map<String, dynamic>>('/api/v1/gyms?pageSize=100');
    final data = response.data;
    if (data == null) return const [];
    final items = (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return items.map(GymSummary.fromJson).toList();
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

/// All active gyms, fetched once per session. Returns an empty list on any
/// failure (offline, backend not yet seeded) so the home page can fall back
/// to the local [GPGym.seed] for category counts without blowing up.
final gymsListProvider = FutureProvider<List<GymSummary>>((ref) async {
  try {
    final repo = ref.read(gymRepositoryProvider);
    return await repo.listAll();
  } catch (_) {
    return const [];
  }
});
