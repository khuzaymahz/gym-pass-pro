import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/providers.dart';
import 'gym_photo.dart';

class GymPhotosRepository {
  GymPhotosRepository(this._client);
  final ApiClient _client;

  Future<List<GymPhoto>> listBySlug(String slug) async {
    final response =
        await _client.get<List<dynamic>>('/api/v1/gyms/by-slug/$slug/photos');
    final data = response.data ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(GymPhoto.fromJson)
        .toList(growable: false);
  }
}

final gymPhotosRepositoryProvider = Provider<GymPhotosRepository>((ref) {
  return GymPhotosRepository(ref.read(apiClientProvider));
});

final gymPhotosProvider =
    FutureProvider.family.autoDispose<List<GymPhoto>, String>((ref, slug) async {
  try {
    final repo = ref.read(gymPhotosRepositoryProvider);
    return await repo.listBySlug(slug);
  } catch (_) {
    return const <GymPhoto>[];
  }
});
