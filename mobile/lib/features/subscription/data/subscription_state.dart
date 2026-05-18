import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/gp_tokens.dart';
import 'pause_repository.dart';
import 'plan_catalog.dart';
import 'plan_pricing.dart';
import 'subscription_repository.dart';

/// Authoritative subscription snapshot for a single member.
///
/// **Backend-driven fields** (sourced from `GET /api/v1/me/subscription`):
/// `subscriptionId`, `tierKey`, `durationMonths`, `visitsUsed`, `renewIso`,
/// `expiresAt`. These are the truth about whether the member is subscribed
/// and how many visits they've burned.
///
/// **Local-only UX fields** (kept in secure storage for in-session feel):
/// `streakDays`, `lastCheckinGymSlug`, `lastCheckinAtIso`. These are
/// "have I scanned recently" / "consecutive days streak" pieces that don't
/// need to survive a device swap. They reset on every backend hydrate so
/// no stale value can lie about the authoritative state.
///
/// **Local-only stubs awaiting backend** (`pendingTierKey`, `pauseFromIso`,
/// `pauseUntilIso`, `pauseDaysUsed`, `pausesUsed`): pause and scheduled-
/// tier-change features are not yet supported on the server. Their fields
/// are kept here so existing UI compiles and behaves coherently in-session,
/// but every backend hydrate clears them — they don't survive a logout or
/// device swap. Wiring these to real backend tables is the planned follow-
/// up after the core subscription migration ships.
class SubscriptionState {
  const SubscriptionState({
    this.subscriptionId,
    this.tierKey,
    this.durationMonths,
    this.monthlyVisits,
    this.visitsUsed = 0,
    this.streakDays = 0,
    this.renewIso,
    this.lastCheckinGymSlug,
    this.lastCheckinAtIso,
    this.pendingTierKey,
    this.pendingDurationMonths,
    this.pauseFromIso,
    this.pauseUntilIso,
    this.pauseDaysUsed = 0,
    this.pausesUsed = 0,
    this.loaded = false,
  });

  /// True once the notifier has finished its first hydrate from
  /// backend + secure storage. UI uses this to distinguish "no
  /// active plan" (loaded == true && tier == null → show empty
  /// state) from "still loading" (loaded == false → show
  /// skeletons). Without this, a member with a real subscription
  /// briefly saw the empty-state CTA on cold start while the
  /// hydrate ran — confusing on slow networks.
  final bool loaded;

  /// Backend `subscription.id`. Null when no active plan.
  final String? subscriptionId;
  final String? tierKey;

  /// Commitment length in months. Derived from the matching plan row at
  /// hydrate time so the renewal countdown can be rendered without an
  /// extra round trip.
  final int? durationMonths;

  /// Plan's `monthly_visits`. Drives the "X / Y visits left" pill on
  /// home and the gates inside [hasVisitsRemaining]. Null when there's
  /// no subscription.
  final int? monthlyVisits;

  final int visitsUsed;
  final int streakDays;

  /// `YYYY-MM-DD` of the next renewal. Backend stores `expires_at` as a
  /// timestamptz; we render the date part only.
  final String? renewIso;

  /// Slug of the gym where the most recent successful check-in happened.
  /// Local UX scaffold so the gym-detail page can suppress the "Check in
  /// here" CTA after a recent scan — never affects backend state.
  final String? lastCheckinGymSlug;
  final String? lastCheckinAtIso;

  /// Tier scheduled to take effect at the next renewal. Local-only stub
  /// until backend support lands.
  final String? pendingTierKey;
  final int? pendingDurationMonths;

  /// Pause window in `YYYY-MM-DD`. Local-only stub until backend support
  /// lands — does not survive a hydrate.
  final String? pauseFromIso;
  final String? pauseUntilIso;
  final int pauseDaysUsed;
  final int pausesUsed;

  bool get hasSubscription => tierKey != null;

  GPTier? get tier => tierKey == null ? null : GPTier.byKey(tierKey!);

  GPTier? get pendingTier =>
      pendingTierKey == null ? null : GPTier.byKey(pendingTierKey!);

  /// Tier one rank above the active one. Used by the profile page to
  /// nudge upgrades. Returns null at the top of the ladder (Diamond).
  GPTier? get nextTier {
    final t = tier;
    if (t == null) return null;
    for (final candidate in GPTier.all) {
      if (candidate.rank == t.rank + 1) return candidate;
    }
    return null;
  }

  /// Maximum contiguous pause days allowed on the current term. Local-only
  /// stub — resolves through `pauseAllowanceDaysFor` (the same matrix the
  /// plans page uses) so the in-session UI is at least self-consistent.
  int get pauseAllowanceDays {
    final t = tier;
    final months = durationMonths;
    if (t == null || months == null) return 0;
    return pauseAllowanceDaysFor(t.key, months);
  }

  int get maxPauses => maxPausesFor(durationMonths ?? 0);

  int get pauseDaysRemaining {
    final allowance = pauseAllowanceDays;
    if (allowance == 0) return 0;
    final left = allowance - pauseDaysUsed;
    return left < 0 ? 0 : left;
  }

  bool isOnPause({DateTime? now}) {
    final from = pauseFromIso;
    final until = pauseUntilIso;
    if (from == null || until == null) return false;
    final today = _isoDateOf(now ?? DateTime.now());
    return today.compareTo(from) >= 0 && today.compareTo(until) <= 0;
  }

  bool get hasScheduledPause =>
      pauseFromIso != null && pauseUntilIso != null;

  /// Projected renewal date if the current plan were extended to
  /// [newDurationMonths]. Returns null when there's nothing to extend or
  /// the target isn't longer than the current commitment.
  String? projectedRenewIso(int newDurationMonths) {
    final current = durationMonths;
    final renew = renewIso;
    if (current == null || renew == null) return null;
    final extra = newDurationMonths - current;
    if (extra <= 0) return renew;
    final parts = renew.split('-');
    if (parts.length != 3) return renew;
    final dt = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    return _isoDateOf(dt.add(Duration(days: 30 * extra)));
  }

  /// True when the member just completed a check-in at [slug] within the
  /// last four hours — covers a typical training session plus shower /
  /// post-workout coffee without leaking into the next visit.
  bool hasFreshCheckinAt(String slug, {DateTime? now}) {
    if (lastCheckinGymSlug != slug) return false;
    final iso = lastCheckinAtIso;
    if (iso == null) return false;
    final at = DateTime.tryParse(iso);
    if (at == null) return false;
    final age = (now ?? DateTime.now()).difference(at);
    return age.inHours < 4 && !age.isNegative;
  }

  /// Visits available in the current 30-day period. Backend resets the
  /// budget every 30 days from the subscription's `starts_at` anchor —
  /// `visitsUsed` is the count of successful check-ins inside that
  /// period (NOT lifetime), so subtraction gives the live remaining
  /// budget.
  ///
  /// Per business model: every tier (Silver / Gold / Platinum /
  /// Diamond) gets the same `monthly_visits = 30` allocation. Tier
  /// only gates which gyms a member can scan into — the entry-tier
  /// network for Silver, the full partner network for Diamond — not
  /// the number of visits. The earlier mobile-only `-1` "unlimited"
  /// sentinel for Diamond was a model bug; backend seeds all four
  /// tiers with 30 monthly visits.
  ///
  /// The historical name `termTotalVisits` predates the per-period
  /// model and is kept to avoid touching every call site; conceptually
  /// it is the per-period cap.
  int get termTotalVisits {
    if (!hasSubscription) return 0;
    return monthlyVisits ?? 0;
  }

  int get visitsRemaining {
    final total = termTotalVisits;
    if (total == 0) return 0;
    return total - visitsUsed < 0 ? 0 : total - visitsUsed;
  }

  bool get isTermVisitsExhausted {
    final total = termTotalVisits;
    return total > 0 && visitsUsed >= total;
  }

  // ----- Term + cycle math -----
  //
  // The backend issues a `monthly_visits` budget that resets every 30
  // days from `starts_at`. For multi-month commitments the member only
  // sees the renewal date — they have no way to know "which month am I
  // in" or "when does this cycle reset." These getters reconstruct
  // that from `renewIso` (term end) and `durationMonths` (length).
  // Returns null when there's no active plan or we're missing data.

  /// Local date today (no time component) — used so cycle / term math
  /// is timezone-stable and matches what the backend would derive at
  /// midnight rollover.
  static DateTime _todayLocal({DateTime? now}) {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime? _renewDate() {
    final iso = renewIso;
    if (iso == null) return null;
    final parts = iso.split('-');
    if (parts.length != 3) return null;
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// 1-based index of the current 30-day cycle within the term. e.g.
  /// for a 3-month plan, returns 1 in the first 30 days, 2 in days
  /// 31–60, 3 in days 61–90. Caps at [durationMonths] so a member
  /// who's slightly past the renewal anchor doesn't see "MONTH 4 OF 3".
  int? currentCycleNumber({DateTime? now}) {
    final months = durationMonths;
    final renew = _renewDate();
    if (months == null || months <= 0 || renew == null) return null;
    final termStart = renew.subtract(Duration(days: 30 * months));
    final today = _todayLocal(now: now);
    final daysIn = today.difference(termStart).inDays;
    if (daysIn < 0) return 1;
    final cycle = (daysIn ~/ 30) + 1;
    if (cycle < 1) return 1;
    if (cycle > months) return months;
    return cycle;
  }

  /// Whole days remaining before the current 30-day budget rolls
  /// over. Returns null when there's no active plan. 0 means the
  /// cycle resets at midnight.
  int? daysLeftInCycle({DateTime? now}) {
    final cycle = currentCycleNumber(now: now);
    final months = durationMonths;
    final renew = _renewDate();
    if (cycle == null || months == null || renew == null) return null;
    final termStart = renew.subtract(Duration(days: 30 * months));
    final cycleEnd = termStart.add(Duration(days: 30 * cycle));
    final today = _todayLocal(now: now);
    final left = cycleEnd.difference(today).inDays;
    return left < 0 ? 0 : left;
  }

  /// Whole days remaining before the term renews. Returns null when
  /// there's no active plan.
  int? daysLeftInTerm({DateTime? now}) {
    final renew = _renewDate();
    if (renew == null) return null;
    final today = _todayLocal(now: now);
    final left = renew.difference(today).inDays;
    return left < 0 ? 0 : left;
  }

  SubscriptionState copyWith({
    String? subscriptionId,
    String? tierKey,
    int? durationMonths,
    int? monthlyVisits,
    int? visitsUsed,
    int? streakDays,
    String? renewIso,
    String? lastCheckinGymSlug,
    String? lastCheckinAtIso,
    String? pendingTierKey,
    int? pendingDurationMonths,
    String? pauseFromIso,
    String? pauseUntilIso,
    int? pauseDaysUsed,
    int? pausesUsed,
    bool? loaded,
    bool clearAll = false,
    bool clearLastCheckin = false,
    bool clearPending = false,
    bool clearPause = false,
  }) {
    if (clearAll) return const SubscriptionState();
    return SubscriptionState(
      subscriptionId: subscriptionId ?? this.subscriptionId,
      tierKey: tierKey ?? this.tierKey,
      durationMonths: durationMonths ?? this.durationMonths,
      monthlyVisits: monthlyVisits ?? this.monthlyVisits,
      visitsUsed: visitsUsed ?? this.visitsUsed,
      streakDays: streakDays ?? this.streakDays,
      renewIso: renewIso ?? this.renewIso,
      lastCheckinGymSlug: clearLastCheckin
          ? null
          : (lastCheckinGymSlug ?? this.lastCheckinGymSlug),
      lastCheckinAtIso: clearLastCheckin
          ? null
          : (lastCheckinAtIso ?? this.lastCheckinAtIso),
      pendingTierKey:
          clearPending ? null : (pendingTierKey ?? this.pendingTierKey),
      pendingDurationMonths: clearPending
          ? null
          : (pendingDurationMonths ?? this.pendingDurationMonths),
      pauseFromIso:
          clearPause ? null : (pauseFromIso ?? this.pauseFromIso),
      pauseUntilIso:
          clearPause ? null : (pauseUntilIso ?? this.pauseUntilIso),
      pauseDaysUsed: pauseDaysUsed ?? this.pauseDaysUsed,
      pausesUsed: pausesUsed ?? this.pausesUsed,
      loaded: loaded ?? this.loaded,
    );
  }
}

String _isoDateOf(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier(
    this._storage,
    this._repo,
    this._catalog,
    this._pauses,
  ) : super(const SubscriptionState()) {
    _loadFuture = _hydrate();
  }

  final FlutterSecureStorage _storage;
  final SubscriptionRepository _repo;
  final PlanCatalog _catalog;
  final PauseRepository _pauses;

  late final Future<void> _loadFuture;

  /// Resolves once the first backend hydrate has either succeeded or
  /// surfaced a network error. The router's redirect logic awaits this
  /// to avoid bouncing the user through the wrong gate during cold start.
  Future<void> get ready => _loadFuture;

  // Local-only UX scaffold keys. The authoritative subscription fields
  // (tier, visits, renew) come from the backend on every hydrate, so we
  // don't persist them — a stale local copy would lie if the backend
  // state changed between sessions.
  static const _streakKey = 'sub.streak_days';
  static const _lastCheckinGymKey = 'sub.last_checkin_gym';
  static const _lastCheckinAtKey = 'sub.last_checkin_at';

  /// Cold-start: read the local-only UX bits, then refresh from backend.
  /// We push the local snapshot first so the UI doesn't flash empty
  /// before the network call returns.
  Future<void> _hydrate() async {
    final streak = await _storage.read(key: _streakKey);
    final lastGym = await _storage.read(key: _lastCheckinGymKey);
    final lastAt = await _storage.read(key: _lastCheckinAtKey);
    state = state.copyWith(
      streakDays: int.tryParse(streak ?? '') ?? 0,
      lastCheckinGymSlug: lastGym,
      lastCheckinAtIso: lastAt,
    );
    await refreshFromBackend();
  }

  /// Pull authoritative state from the backend and merge in the local
  /// UX scaffold. Called on cold-start, after a successful check-in,
  /// after a checkout / cancellation, and from My Subscription's pull-
  /// to-refresh. A network failure leaves the state untouched — better
  /// to keep the previous snapshot than wipe to a confusing empty.
  ///
  /// [throwOnError] — set to true from explicit user-initiated refreshes
  /// (pull-to-refresh on home / subscription / billing). The state still
  /// keeps its stale snapshot, but the error rethrows so the caller can
  /// surface a snackbar ("check your connection"). Cold-start hydrate
  /// passes false so a bad first-frame fetch doesn't crash the app
  /// before the UI has a chance to render the cached values.
  Future<void> refreshFromBackend({bool throwOnError = false}) async {
    final CurrentSubscriptionResponse response;
    try {
      response = await _repo.current();
    } catch (e) {
      // Offline / network blip — keep whatever we last knew. A stale tier
      // is less misleading than a sudden "no plan" state mid-session.
      state = state.copyWith(loaded: true);
      if (throwOnError) rethrow;
      return;
    }

    final sub = response.subscription;
    if (sub == null || !sub.isActive) {
      state = SubscriptionState(
        streakDays: state.streakDays,
        lastCheckinGymSlug: state.lastCheckinGymSlug,
        lastCheckinAtIso: state.lastCheckinAtIso,
        loaded: true,
      );
      return;
    }

    // Set the tier IMMEDIATELY from the authoritative /me/subscription
    // response. Catalog and pause are best-effort enrichments below — a
    // failure in either must NOT roll the tier back to null, or the
    // member sees the empty "Choose your pass" card when they actually
    // have an active plan.
    final renewDate = sub.expiresAt.toUtc();
    final renewIso =
        '${renewDate.year.toString().padLeft(4, '0')}-${renewDate.month.toString().padLeft(2, '0')}-${renewDate.day.toString().padLeft(2, '0')}';
    final periodVisits = response.currentPeriodVisits ?? 0;
    state = SubscriptionState(
      subscriptionId: sub.id,
      tierKey: sub.tier,
      visitsUsed: periodVisits,
      streakDays: state.streakDays,
      renewIso: renewIso,
      lastCheckinGymSlug: state.lastCheckinGymSlug,
      lastCheckinAtIso: state.lastCheckinAtIso,
      loaded: true,
    );

    int? duration;
    int? monthly;
    try {
      await _catalog.ensureLoaded();
      final planRow = _catalog.findById(sub.planId);
      duration = planRow?.durationMonths;
      monthly = planRow?.monthlyVisits;
    } catch (_) {
      // Catalog unreachable — UI shows tier without renewal countdown / cycle math.
    }

    BackendPause? pause;
    try {
      pause = await _pauses.openPause();
    } catch (_) {
      pause = null;
    }

    state = state.copyWith(
      durationMonths: duration,
      monthlyVisits: monthly,
      pauseFromIso: pause == null ? null : _dateToIso(pause.startsOn),
      pauseUntilIso: pause == null ? null : _dateToIso(pause.endsOn),
    );
  }

  static String _dateToIso(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// Buy a plan. The backend creates the subscription, charges via the
  /// (mock) gateway, and returns the active row. We refresh state from
  /// the response so the home shell unlocks immediately without waiting
  /// on a follow-up `current()` call.
  Future<BackendSubscription> purchase({
    required String tierKey,
    required int durationMonths,
    String? paymentMethodId,
    String paymentMethodKind = 'mock',
  }) async {
    await _catalog.ensureLoaded();
    final planId = _catalog.findPlanId(
      tierKey: tierKey,
      durationMonths: durationMonths,
    );
    if (planId == null) {
      throw StateError('No active plan for $tierKey/$durationMonths');
    }
    final sub = await _repo.purchase(
      planId: planId,
      paymentMethodKind: paymentMethodKind,
      paymentMethodId: paymentMethodId,
    );
    await refreshFromBackend();
    // Reset streak on a fresh activation so the home shell pill starts
    // clean — we can't infer pre-existing streaks from server data yet.
    state = state.copyWith(streakDays: 0);
    await _storage.write(key: _streakKey, value: '0');
    return sub;
  }

  /// Replace the active term with a new purchase. Used by upgrade,
  /// extend-duration, and renew-now flows: the previous sub is cancelled
  /// in the same call so the backend's "one active subscription per
  /// member" guard doesn't reject the follow-up purchase.
  Future<BackendSubscription> replaceWithPurchase({
    required String tierKey,
    required int durationMonths,
    String? paymentMethodId,
    String paymentMethodKind = 'mock',
  }) async {
    final currentId = state.subscriptionId;
    if (currentId != null) {
      try {
        await _repo.cancel(currentId);
      } catch (_) {
        // If the cancel call fails the purchase below will surface
        // SUB_DUPLICATE_ACTIVE; that's the right error to bubble up.
      }
    }
    return purchase(
      tierKey: tierKey,
      durationMonths: durationMonths,
      paymentMethodId: paymentMethodId,
      paymentMethodKind: paymentMethodKind,
    );
  }

  /// Cancel the current subscription. Backend writes `status=cancelled`
  /// and `cancelled_at`; we drop the state locally so the UI flips to
  /// the unsubscribed shell on the next render.
  Future<void> cancelCurrent() async {
    final id = state.subscriptionId;
    if (id == null) return;
    await _repo.cancel(id);
    await refreshFromBackend();
  }

  /// Record a successful check-in for in-session UX (streak + last-gym
  /// memory). The backend has already incremented `visits_used` server-
  /// side; refreshFromBackend pulls that authoritative value back.
  Future<void> recordVisit({String? gymSlug, DateTime? at}) async {
    if (!state.hasSubscription) return;
    final atIso = (at ?? DateTime.now()).toUtc().toIso8601String();
    state = state.copyWith(
      streakDays: state.streakDays + 1,
      lastCheckinGymSlug: gymSlug ?? state.lastCheckinGymSlug,
      lastCheckinAtIso: gymSlug == null ? state.lastCheckinAtIso : atIso,
    );
    await _storage.write(key: _streakKey, value: '${state.streakDays}');
    if (gymSlug != null) {
      await _storage.write(key: _lastCheckinGymKey, value: gymSlug);
      await _storage.write(key: _lastCheckinAtKey, value: atIso);
    }
    await refreshFromBackend();
  }

  /// Wipe local UX scaffold. Called from the auth controller's logout
  /// sweep so the next member to sign in on this device starts clean.
  Future<void> clear() async {
    state = const SubscriptionState();
    await _storage.delete(key: _streakKey);
    await _storage.delete(key: _lastCheckinGymKey);
    await _storage.delete(key: _lastCheckinAtKey);
    _catalog.clear();
  }

  // ---------------------------------------------------------------------
  // Local-only stubs awaiting backend support
  //
  // The methods below preserve the previous in-session UX for pause /
  // scheduled-change / extend / renew / immediate-upgrade flows. They
  // mutate local state only — every backend hydrate clears these
  // overlays. Wiring them to real backend tables is the planned follow-
  // up after the core subscription migration ships. UI surfaces should
  // remain functional in-session; nothing here survives a logout.
  // ---------------------------------------------------------------------

  /// Tier change for an existing subscriber. Routes through a real
  /// backend cancel + buy when there's an active subscription so the
  /// gym sees the new tier the next time the member scans.
  Future<void> upgradeTo(String newTierKey, {String? paymentMethodId}) async {
    final months = state.durationMonths ?? 1;
    await replaceWithPurchase(
      tierKey: newTierKey,
      durationMonths: months,
      paymentMethodId: paymentMethodId,
    );
  }

  /// Extend an existing term. Backend doesn't yet support in-place
  /// extensions, so we cancel + buy with the new duration; visits reset.
  Future<void> extendDuration({
    required int newDurationMonths,
    String? paymentMethodId,
  }) async {
    final tierKey = state.tierKey;
    if (tierKey == null) return;
    await replaceWithPurchase(
      tierKey: tierKey,
      durationMonths: newDurationMonths,
      paymentMethodId: paymentMethodId,
    );
  }

  /// Force a brand-new billing period starting now. Same backend story
  /// as extend: cancel + buy. The unused days on the old term are
  /// forfeit — that trade is surfaced in the renewal confirm dialog.
  Future<void> renewNow({String? paymentMethodId}) async {
    final tierKey = state.tierKey;
    final months = state.durationMonths ?? 1;
    if (tierKey == null) return;
    await replaceWithPurchase(
      tierKey: tierKey,
      durationMonths: months,
      paymentMethodId: paymentMethodId,
    );
  }

  /// Local-only: stage a pending tier/duration change for the next
  /// renewal. Will not survive a hydrate. Follow-up: persist server-side.
  Future<void> scheduleChange({
    String? newTierKey,
    int? newDurationMonths,
  }) async {
    if (!state.hasSubscription) return;
    final resolvedTier = newTierKey ?? state.tierKey;
    final resolvedDuration = newDurationMonths ?? state.durationMonths;
    final sameTier = resolvedTier == state.tierKey;
    final sameDuration = resolvedDuration == state.durationMonths;
    if (sameTier && sameDuration) {
      await cancelScheduledChange();
      return;
    }
    state = state.copyWith(
      pendingTierKey: sameTier ? null : resolvedTier,
      pendingDurationMonths: sameDuration ? null : resolvedDuration,
      clearPending: sameTier && sameDuration,
    );
  }

  Future<void> cancelScheduledChange() async {
    state = state.copyWith(clearPending: true);
  }

  /// Schedule a pause window. Hits `POST /me/subscription/pause`,
  /// which validates the request against the per-plan day allowance
  /// and the per-term max-pauses count and refuses with
  /// `SUB_PAUSE_NOT_ALLOWED` when it doesn't fit. On success, refresh
  /// state from the backend so the My Subscription card reflects the
  /// new pause-from / pause-until immediately.
  Future<void> startPause({
    required String fromIso,
    required String untilIso,
  }) async {
    if (!state.hasSubscription) return;
    final from = _parseIsoDate(fromIso);
    final until = _parseIsoDate(untilIso);
    await _pauses.schedule(startsOn: from, endsOn: until);
    await refreshFromBackend();
  }

  /// Manual early resume. Backend computes days actually consumed
  /// against today, finalises the pause row, and shifts the parent
  /// subscription's `expires_at` forward — the next hydrate pulls
  /// back the new renewal date and the cleared pause window.
  Future<void> endPause({DateTime? now}) async {
    if (state.pauseFromIso == null) return;
    await _pauses.resume();
    await refreshFromBackend();
  }

  static DateTime _parseIsoDate(String iso) {
    final parts = iso.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Dev-only stub kept for the QA shortcut on the check-in screen.
  /// Drains the local visits-remaining count so the early-renewal dialog
  /// can be exercised without scanning 30 times. Backend isn't notified;
  /// the next hydrate restores the real visit count.
  Future<void> devMaxOutVisits() async {
    if (!state.hasSubscription) return;
    final total = state.termTotalVisits;
    if (total <= 0) return;
    state = state.copyWith(visitsUsed: total);
  }

}

/// Helper used by checkout to derive the renewal date the UI shows in
/// the post-purchase summary. Backend recomputes the canonical
/// `expires_at` on the next refresh — this is purely cosmetic.
String projectedRenewIso({required int durationMonths, DateTime? from}) {
  final anchor = from ?? DateTime.now();
  final renew = anchor.add(Duration(days: 30 * durationMonths));
  final mm = renew.month.toString().padLeft(2, '0');
  final dd = renew.day.toString().padLeft(2, '0');
  return '${renew.year}-$mm-$dd';
}

/// Convenience to format the discount line on the totals card. Mirrors
/// `discountPercentForDuration` — exported here so callers don't have
/// to import two modules to render a checkout summary.
int discountPercentFor(int months) => discountPercentForDuration(months);

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier(
    ref.read(secureStorageProvider),
    ref.read(subscriptionRepositoryProvider),
    ref.read(planCatalogProvider),
    ref.read(pauseRepositoryProvider),
  );
});
