import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/providers.dart';

/// Wire-shape for `GET /me/tickets/` and the create response. The mobile
/// list view only needs subject + status + ref + created date; the
/// detail view fetches messages separately.
class BackendTicket {
  const BackendTicket({
    required this.id,
    required this.category,
    required this.priority,
    required this.status,
    required this.subject,
    required this.createdAt,
  });

  final String id;
  final String category;
  final String priority;
  final String status;
  final String subject;
  final DateTime createdAt;

  factory BackendTicket.fromJson(Map<String, dynamic> j) {
    return BackendTicket(
      id: j['id'] as String,
      category: j['category'] as String,
      priority: j['priority'] as String,
      status: j['status'] as String,
      subject: j['subject'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}

class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  Future<List<BackendTicket>> list() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/me/tickets',
      authed: true,
    );
    final items = (response.data?['items'] as List?) ?? const [];
    return items
        .map((e) => BackendTicket.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Submit a new ticket. The backend persists it, attributes it to the
  /// authenticated member, and returns the saved row. Mobile tracks the
  /// short reference (last 8 of UUID) as the "ticket ref" the user sees
  /// in the confirmation dialog.
  Future<BackendTicket> create({
    required String category,
    required String priority,
    required String subject,
    required String body,
    Map<String, dynamic>? meta,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/me/tickets',
      body: {
        'category': category,
        'priority': priority,
        'subject': subject,
        'body': body,
        if (meta != null) 'meta': meta,
      },
      authed: true,
    );
    return BackendTicket.fromJson(response.data!);
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.read(apiClientProvider));
});
