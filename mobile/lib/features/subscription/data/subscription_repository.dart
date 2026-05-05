import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/providers.dart';

/// Authoritative snapshot of the member's current subscription. Mirrors
/// `GET /api/v1/me/subscription`. When `subscription` is null, the member
/// has no active plan; the mobile UI uses that as the gate for any
/// subscription-required surface.
///
/// `currentPeriodVisits` is the count of successful check-ins in the
/// active 30-day period anchored to `subscription.starts_at` — backend
/// derives it from indexed check-in rows so it never drifts. Diamond
/// returns null since its budget is unlimited.
class CurrentSubscriptionResponse {
  const CurrentSubscriptionResponse({
    required this.subscription,
    required this.currentPeriodVisits,
    required this.remainingVisits,
  });

  final BackendSubscription? subscription;
  final int? currentPeriodVisits;
  final int? remainingVisits;

  factory CurrentSubscriptionResponse.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'];
    return CurrentSubscriptionResponse(
      subscription: sub == null
          ? null
          : BackendSubscription.fromJson((sub as Map).cast<String, dynamic>()),
      currentPeriodVisits: json['currentPeriodVisits'] as int?,
      remainingVisits: json['remainingVisits'] as int?,
    );
  }
}

class BackendSubscription {
  const BackendSubscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.tier,
    required this.status,
    required this.startsAt,
    required this.expiresAt,
    required this.visitsUsed,
    required this.autoRenew,
    required this.cancelledAt,
  });

  final String id;
  final String userId;
  final String planId;
  final String tier;
  final String status;
  final DateTime startsAt;
  final DateTime expiresAt;
  final int visitsUsed;
  final bool autoRenew;
  final DateTime? cancelledAt;

  factory BackendSubscription.fromJson(Map<String, dynamic> j) {
    return BackendSubscription(
      id: j['id'] as String,
      userId: j['userId'] as String,
      planId: j['planId'] as String,
      tier: j['tier'] as String,
      status: j['status'] as String,
      startsAt: DateTime.parse(j['startsAt'] as String),
      expiresAt: DateTime.parse(j['expiresAt'] as String),
      visitsUsed: j['visitsUsed'] as int? ?? 0,
      autoRenew: j['autoRenew'] as bool? ?? false,
      cancelledAt: j['cancelledAt'] == null
          ? null
          : DateTime.parse(j['cancelledAt'] as String),
    );
  }

  bool get isActive => status == 'active';
}

class SubscriptionRepository {
  SubscriptionRepository(this._api);

  final ApiClient _api;

  /// Fetch the authoritative current subscription. Used on cold-start
  /// hydrate, after a checkout, after a successful check-in (visits_used
  /// incremented server-side), and on pull-to-refresh from My Subscription.
  Future<CurrentSubscriptionResponse> current() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/me/subscription',
      authed: true,
    );
    return CurrentSubscriptionResponse.fromJson(response.data!);
  }

  /// Buy a plan. `paymentMethodKind` matches the backend enum
  /// (`card | cliq | apple_pay | mock`). `paymentMethodId` is the saved
  /// stored-method id when the user picked one of their saved methods —
  /// the backend verifies ownership and stamps it into the audit trail.
  Future<BackendSubscription> purchase({
    required String planId,
    required String paymentMethodKind,
    String? paymentMethodId,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/subscriptions',
      body: {
        'planId': planId,
        'paymentMethod': paymentMethodKind,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
      },
      authed: true,
    );
    return BackendSubscription.fromJson(response.data!);
  }

  Future<BackendSubscription> cancel(String subscriptionId) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/subscriptions/$subscriptionId/cancel',
      authed: true,
    );
    return BackendSubscription.fromJson(response.data!);
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.read(apiClientProvider));
});
