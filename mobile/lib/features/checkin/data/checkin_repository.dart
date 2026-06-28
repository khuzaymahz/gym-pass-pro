import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/gp_tokens.dart';

class CheckinResult {
  CheckinResult({
    required this.status,
    this.gymSlug,
    this.gymNameEn,
    this.gymArea,
    this.remainingVisits,
    this.reason,
  });

  final String status;
  final String? gymSlug;
  final String? gymNameEn;

  /// Neighborhood / district label as stored in [GPGym.area]. Rendered on
  /// the success screen next to the timestamp. Not localized — Jordan
  /// district names are the same in AR and EN displays.
  final String? gymArea;
  final int? remainingVisits;
  final String? reason;

  factory CheckinResult.fromJson(Map<String, dynamic> json) {
    return CheckinResult(
      status: json['status'] as String,
      gymSlug: json['gymSlug'] as String?,
      gymNameEn: json['gymNameEn'] as String?,
      gymArea: json['gymArea'] as String?,
      remainingVisits: json['remainingVisits'] as int?,
      reason: json['reason'] as String?,
    );
  }
}

class CheckinRepository {
  CheckinRepository(this._api);

  final ApiClient _api;

  /// Maps a raw QR payload to a seed gym when the payload matches a known
  /// slug. Used by [CheckinController] to redirect unsubscribed members
  /// to the gym-detail page without hitting `/checkins/scan`. Returns null
  /// for unknown payloads.
  GPGym? lookupGymByPayload(String qrPayload) {
    for (final g in GPGym.seed) {
      if (g.slug == qrPayload) return g;
    }
    return null;
  }

  Future<CheckinResult> scan(String qrPayload, {int? remainingAfter}) async {
    // Backend is authoritative for scan results — both dev and release
    // builds round-trip the API. (The earlier debug shortcut faked a
    // synthetic success for seed gyms, which masked real backend errors
    // like SUB_EXPIRED in dev.)
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/checkins/scan',
      body: {'qrPayload': qrPayload},
      authed: true,
    );
    return CheckinResult.fromJson(response.data!);
  }
}

final checkinRepositoryProvider = Provider<CheckinRepository>((ref) {
  return CheckinRepository(ref.read(apiClientProvider));
});
