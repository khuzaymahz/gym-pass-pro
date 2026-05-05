import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/providers.dart';

/// Wire-shape for `GET / POST /me/subscription/pause` and the resume
/// endpoint. `endedAt` distinguishes finalised rows from open ones.
/// `daysConsumed` is set on finalisation and equals the number of days
/// the parent subscription's `expires_at` was shifted by.
class BackendPause {
  const BackendPause({
    required this.id,
    required this.subscriptionId,
    required this.startsOn,
    required this.endsOn,
    required this.endedAt,
    required this.daysConsumed,
    required this.createdAt,
  });

  final String id;
  final String subscriptionId;
  final DateTime startsOn;
  final DateTime endsOn;
  final DateTime? endedAt;
  final int daysConsumed;
  final DateTime createdAt;

  /// True when the pause is open (scheduled OR currently active). The
  /// member can manually resume an open pause; a finalised pause is
  /// historical and lives in audit only.
  bool get isOpen => endedAt == null;

  bool isActiveOn(DateTime today) {
    if (!isOpen) return false;
    final t = DateTime(today.year, today.month, today.day);
    return !t.isBefore(startsOn) && !t.isAfter(endsOn);
  }

  factory BackendPause.fromJson(Map<String, dynamic> j) {
    return BackendPause(
      id: j['id'] as String,
      subscriptionId: j['subscriptionId'] as String,
      startsOn: DateTime.parse(j['startsOn'] as String),
      endsOn: DateTime.parse(j['endsOn'] as String),
      endedAt: j['endedAt'] == null
          ? null
          : DateTime.parse(j['endedAt'] as String),
      daysConsumed: j['daysConsumed'] as int? ?? 0,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}

class PauseRepository {
  PauseRepository(this._api);

  final ApiClient _api;

  /// Returns the open pause for the active subscription, or null when
  /// nothing is scheduled. Backend uses null-body 200 (rather than 404)
  /// so the mobile UI can render a "no pause" state without catching
  /// a status-code branch.
  Future<BackendPause?> openPause() async {
    final response = await _api.get<dynamic>(
      '/api/v1/me/subscription/pause',
      authed: true,
    );
    final data = response.data;
    if (data == null) return null;
    return BackendPause.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Schedule a pause window. The backend validates the window against
  /// the per-plan allowance (days + max-pauses) and refuses with
  /// `SUB_PAUSE_NOT_ALLOWED` when it doesn't fit. Caller surfaces the
  /// error code so the UI can map it to a localised message.
  Future<BackendPause> schedule({
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/me/subscription/pause',
      body: {
        'startsOn': _isoDate(startsOn),
        'endsOn': _isoDate(endsOn),
      },
      authed: true,
    );
    return BackendPause.fromJson(response.data!);
  }

  /// Manual early resume. Returns the finalised pause row. Idempotent:
  /// calling on a subscription with no open pause returns null instead
  /// of erroring.
  Future<BackendPause?> resume() async {
    try {
      final response = await _api.post<dynamic>(
        '/api/v1/me/subscription/pause/resume',
        authed: true,
      );
      final data = response.data;
      if (data == null) return null;
      return BackendPause.fromJson((data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  String _isoDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

final pauseRepositoryProvider = Provider<PauseRepository>((ref) {
  return PauseRepository(ref.read(apiClientProvider));
});
