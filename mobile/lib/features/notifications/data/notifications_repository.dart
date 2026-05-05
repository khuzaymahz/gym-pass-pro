import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/providers.dart';

/// Wire-shape for `GET /api/v1/notifications`. Bilingual fields are
/// kept side-by-side; the mobile picks the locale at render time so a
/// language switch doesn't require a re-fetch.
class BackendNotification {
  const BackendNotification({
    required this.id,
    required this.type,
    required this.titleEn,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyAr,
    required this.deepLink,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String titleEn;
  final String titleAr;
  final String bodyEn;
  final String bodyAr;
  final String? deepLink;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  factory BackendNotification.fromJson(Map<String, dynamic> j) {
    return BackendNotification(
      id: j['id'] as String,
      type: j['type'] as String? ?? 'system',
      titleEn: j['titleEn'] as String? ?? '',
      titleAr: j['titleAr'] as String? ?? '',
      bodyEn: j['bodyEn'] as String? ?? '',
      bodyAr: j['bodyAr'] as String? ?? '',
      deepLink: j['deepLink'] as String?,
      readAt: j['readAt'] == null
          ? null
          : DateTime.parse(j['readAt'] as String),
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<List<BackendNotification>> list({bool unreadOnly = false}) async {
    final response = await _api.get<List<dynamic>>(
      '/api/v1/notifications',
      query: {if (unreadOnly) 'unread': 'true'},
      authed: true,
    );
    final raw = response.data ?? const [];
    return raw
        .map(
          (e) =>
              BackendNotification.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<void> markRead(String id) async {
    await _api.post<void>('/api/v1/notifications/$id/read', authed: true);
  }

  Future<void> markAllRead() async {
    await _api.post<void>('/api/v1/notifications/read-all', authed: true);
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.read(apiClientProvider));
});

/// Number of unread notifications. Drives the dot badge on the home
/// page's bell icon — badge only renders when this is `> 0` instead
/// of always-on. Auto-disposes so the call doesn't outlive the
/// page that needs it; failures fall back to 0 (no badge) so a
/// hiccup never lights up a phantom indicator.
final unreadNotificationsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  try {
    final repo = ref.read(notificationsRepositoryProvider);
    final list = await repo.list(unreadOnly: true);
    return list.length;
  } catch (_) {
    return 0;
  }
});
