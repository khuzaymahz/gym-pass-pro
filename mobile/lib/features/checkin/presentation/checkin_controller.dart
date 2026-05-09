import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gp_tokens.dart';
import '../../subscription/data/subscription_state.dart';
import '../data/checkin_repository.dart';

class CheckinUiState {
  const CheckinUiState({
    this.scanning = true,
    this.processing = false,
    this.result,
    this.errorCode,
    this.errorMessage,
    this.redirectGymSlug,
    this.pendingGym,
  });

  final bool scanning;
  final bool processing;
  final CheckinResult? result;
  final String? errorCode;
  final String? errorMessage;

  /// Set when the member scans a known gym QR while unsubscribed OR while on
  /// a tier that doesn't cover this gym. The page listens and navigates to
  /// `/gyms/<slug>`, where the unlock/upgrade CTA routes into /plans. Owned
  /// by the controller (not the page) so tier-gating stays in the business
  /// layer.
  final String? redirectGymSlug;

  /// Set when a subscribed member scans a QR their tier covers. The page
  /// swaps the scanner for a confirmation view — the member sees the gym
  /// name and taps `confirmCheckin` to commit. Acts as an explicit consent
  /// step so a rogue QR in the viewfinder can't silently burn a visit.
  final GPGym? pendingGym;

  CheckinUiState copyWith({
    bool? scanning,
    bool? processing,
    CheckinResult? result,
    String? errorCode,
    String? errorMessage,
    String? redirectGymSlug,
    GPGym? pendingGym,
    bool clearResult = false,
    bool clearError = false,
    bool clearRedirect = false,
    bool clearPending = false,
  }) {
    return CheckinUiState(
      scanning: scanning ?? this.scanning,
      processing: processing ?? this.processing,
      result: clearResult ? null : (result ?? this.result),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      redirectGymSlug:
          clearRedirect ? null : (redirectGymSlug ?? this.redirectGymSlug),
      pendingGym: clearPending ? null : (pendingGym ?? this.pendingGym),
    );
  }
}

class CheckinController extends StateNotifier<CheckinUiState> {
  CheckinController(this._repo, this._subscription)
      : super(const CheckinUiState());

  final CheckinRepository _repo;
  final SubscriptionNotifier _subscription;

  /// Raw payload that produced the pending confirmation. Kept outside the UI
  /// state because the page doesn't need it — only [confirmCheckin] does when
  /// it finally hits the repository.
  String? _pendingPayload;

  Future<void> onQrDetected(String payload) async {
    if (state.processing || !state.scanning) return;
    state = state.copyWith(
      scanning: false,
      processing: true,
      clearResult: true,
      clearError: true,
      clearRedirect: true,
      clearPending: true,
    );
    final sub = _subscription.state;
    final tier = sub.tier;
    final gym = _repo.lookupGymByPayload(payload);

    // No active subscription — don't attempt to check in. If the payload
    // maps to a known gym, route the member to that gym's profile where the
    // unlock CTA sits: they see exactly which gym they tried to enter and
    // which tier unlocks it. Unknown payloads fall back to a generic error
    // so a stray QR doesn't silently do nothing.
    if (tier == null) {
      if (gym != null) {
        state = state.copyWith(
          processing: false,
          redirectGymSlug: gym.slug,
        );
      } else {
        state = state.copyWith(
          processing: false,
          errorCode: 'CHECKIN_NO_SUBSCRIPTION',
        );
      }
      return;
    }

    // Term visit pool is empty — block the scan and let the page offer an
    // early renewal. The member forfeits any unused days by renewing now;
    // that trade is surfaced in the renewal confirmation dialog.
    if (sub.isTermVisitsExhausted) {
      state = state.copyWith(
        processing: false,
        errorCode: 'CHECKIN_VISITS_EXHAUSTED',
      );
      return;
    }

    // Subscribed but the gym's tier outranks the member's — send them to
    // the gym profile, which already renders the "Upgrade to <tier>" CTA.
    // Same destination as the unsubscribed path so the gym page owns the
    // upsell UI in one place.
    if (gym != null && gym.tierObj.rank > tier.rank) {
      state = state.copyWith(
        processing: false,
        redirectGymSlug: gym.slug,
      );
      return;
    }

    // Tier fits (or unknown gym — let the backend decide). Stage a pending
    // confirmation instead of committing immediately: the page flips to a
    // "Check in to <gym>?" view and only the explicit button press fires
    // [confirmCheckin]. This prevents a visit being burned the instant the
    // camera sweeps past a QR code.
    if (gym != null) {
      _pendingPayload = payload;
      state = state.copyWith(
        processing: false,
        pendingGym: gym,
      );
      return;
    }

    // Unknown payload but the member has a plan — defer to the backend, which
    // is authoritative on whether this QR is a live partner gym.
    _pendingPayload = payload;
    await _commitCheckin(payload, sub, tier);
  }

  /// Called from the confirmation view when the member taps "Check in".
  /// Hits the repository with the payload captured by [onQrDetected].
  Future<void> confirmCheckin() async {
    final payload = _pendingPayload;
    if (payload == null || state.processing) return;
    final sub = _subscription.state;
    final tier = sub.tier;
    if (tier == null) return;
    state = state.copyWith(processing: true, clearError: true);
    await _commitCheckin(payload, sub, tier);
  }

  /// Bails out of a pending confirmation without burning a visit. Restores
  /// the scanner so the member can aim at a different QR.
  void cancelPending() {
    _pendingPayload = null;
    state = const CheckinUiState();
  }

  Future<void> _commitCheckin(
    String payload,
    SubscriptionState sub,
    GPTier tier,
  ) async {
    try {
      // Optimistic post-scan visits-left for the success screen. Every
      // tier shares the same `monthly_visits = 30` allocation per the
      // backend seed — tier only gates the gym network, not the cap —
      // so we always have a finite number to compute against. Falls
      // back to the tier's nominal monthly count when the plan
      // catalog hasn't hydrated yet.
      final termTotal =
          sub.termTotalVisits > 0 ? sub.termTotalVisits : tier.visits;
      final remainingAfter =
          (termTotal - (sub.visitsUsed + 1)).clamp(0, termTotal);
      final result = await _repo.scan(payload, remainingAfter: remainingAfter);
      if (result.status == 'success') {
        await _subscription.recordVisit(gymSlug: result.gymSlug);
      }
      state = state.copyWith(
        processing: false,
        result: result,
        clearPending: true,
      );
    } catch (e) {
      final asApi = _asApi(e);
      state = state.copyWith(
        processing: false,
        errorCode: asApi?.code ?? 'UNKNOWN',
        errorMessage: asApi?.message ?? e.toString(),
        clearPending: true,
      );
    }
  }

  void reset() {
    _pendingPayload = null;
    state = const CheckinUiState();
  }

  dynamic _asApi(Object e) {
    try {
      if (e is DioException) {
        return e.error;
      }
      return e;
    } catch (_) {
      return null;
    }
  }
}

final checkinControllerProvider =
    StateNotifierProvider.autoDispose<CheckinController, CheckinUiState>((ref) {
  return CheckinController(
    ref.read(checkinRepositoryProvider),
    ref.read(subscriptionProvider.notifier),
  );
});
