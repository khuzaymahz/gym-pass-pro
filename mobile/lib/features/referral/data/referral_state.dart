import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/di/providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/user_profile.dart';

/// Mirror of the backend `referral_status_enum`. Kept in sync manually —
/// once the backend is wired, the API response will be the source of truth.
enum ReferralStatus { pending, converted, expired }

class InvitedFriend {
  const InvitedFriend({
    required this.id,
    required this.displayName,
    required this.status,
    required this.createdAt,
    this.convertedAt,
  });

  final String id;
  final String displayName;
  final ReferralStatus status;
  final DateTime createdAt;
  final DateTime? convertedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'convertedAt': convertedAt?.toIso8601String(),
      };

  static InvitedFriend fromJson(Map<String, dynamic> m) => InvitedFriend(
        id: m['id'] as String,
        displayName: m['displayName'] as String,
        status: ReferralStatus.values.firstWhere(
          (e) => e.name == m['status'],
          orElse: () => ReferralStatus.pending,
        ),
        createdAt: DateTime.parse(m['createdAt'] as String),
        convertedAt: m['convertedAt'] == null
            ? null
            : DateTime.parse(m['convertedAt'] as String),
      );
}

class ReferralState {
  const ReferralState({
    required this.code,
    required this.invited,
    this.invitedByName,
  });

  /// The member's permanent share code. Shape: `GP-XXXXXX`, mirroring the
  /// backend `ReferralService` alphabet (O/0/I/1 excluded for legibility).
  final String code;
  final List<InvitedFriend> invited;

  /// Display name of the person who referred the current member, or null
  /// if this member joined organically. Populated when they sign up with
  /// a friend's code.
  final String? invitedByName;

  int countOf(ReferralStatus s) =>
      invited.where((i) => i.status == s).length;

  /// Build the public share URL given the app's web base. The base
  /// is environment-driven (`WEB_BASE_URL` build define) — staging
  /// goes to staging.gym-pass.net, prod to gym-pass.net, and dev
  /// to whatever localhost surface the operator has.
  String shareUrlFor(String webBase) {
    final trimmed = webBase.endsWith('/')
        ? webBase.substring(0, webBase.length - 1)
        : webBase;
    return '$trimmed/invite/$code';
  }

  ReferralState copyWith({
    String? code,
    List<InvitedFriend>? invited,
    String? invitedByName,
    bool clearInvitedBy = false,
  }) {
    return ReferralState(
      code: code ?? this.code,
      invited: invited ?? this.invited,
      invitedByName:
          clearInvitedBy ? null : (invitedByName ?? this.invitedByName),
    );
  }

  static const empty = ReferralState(code: '', invited: []);
}

class _ReferralStore {
  _ReferralStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _kCode = 'referral.code';
  static const _kInvited = 'referral.invited';
  static const _kInvitedByName = 'referral.invitedByName';

  Future<String?> readCode() => _storage.read(key: _kCode);

  Future<void> writeCode(String code) =>
      _storage.write(key: _kCode, value: code);

  Future<String?> readInvitedByName() =>
      _storage.read(key: _kInvitedByName);

  Future<void> writeInvitedByName(String name) =>
      _storage.write(key: _kInvitedByName, value: name);

  Future<List<InvitedFriend>> readInvited() async {
    final raw = await _storage.read(key: _kInvited);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(InvitedFriend.fromJson)
        .toList();
  }

  Future<void> writeInvited(List<InvitedFriend> invited) async {
    final encoded = jsonEncode(invited.map((i) => i.toJson()).toList());
    await _storage.write(key: _kInvited, value: encoded);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kCode);
    await _storage.delete(key: _kInvited);
    await _storage.delete(key: _kInvitedByName);
  }
}

final _referralStoreProvider = Provider<_ReferralStore>((ref) {
  return _ReferralStore(ref.read(secureStorageProvider));
});

/// Outcome of [ReferralController.claimFriendCode]. UI maps each case to a
/// localised snack/banner; keeping it as an enum lets callers stay decoupled
/// from network errors.
enum ClaimCodeResult { ok, invalidShape, notFound, ownCode, alreadyClaimed }

class ReferralController extends StateNotifier<ReferralState> {
  // Private ctor because [_store]'s type is library-private — callers must go
  // through [referralProvider], which is the only permitted construction path.
  ReferralController._(this._store, this._repo, this._ref)
      : super(ReferralState.empty) {
    _ready = _hydrate();
    _ref.listen<UserProfile>(
      profileProvider,
      (_, next) => _ensureSummaryFor(next),
      fireImmediately: true,
    );
  }

  final _ReferralStore _store;
  final AuthRepository _repo;
  final Ref _ref;

  /// Completes once the first read from secure storage finishes. Guards
  /// [_ensureCodeFor] against the cold-start race where the profile listener
  /// fires before hydration can tell us whether a code is already on disk.
  late final Future<void> _ready;

  Future<void> _hydrate() async {
    final code = await _store.readCode() ?? '';
    final invited = await _store.readInvited();
    final invitedByName = await _store.readInvitedByName();
    state = ReferralState(
      code: code,
      invited: invited,
      invitedByName: invitedByName,
    );
  }

  /// Pulls the full referral summary from the backend (code +
  /// invited list + counts) and merges it into local state. Network
  /// failures keep the cached values; the share button surfaces
  /// empty-state if there's nothing to show. Was previously called
  /// `_ensureCodeFor` and only fetched the code — every call site
  /// has been updated to expect full hydration.
  Future<void> _ensureSummaryFor(UserProfile profile) async {
    await _ready;
    final hasIdentity = (profile.phone ?? profile.email ?? '').isNotEmpty;
    if (!hasIdentity) return;
    // Skip if we already have a code AND a synced invited list. The
    // invited list is the strong signal — an empty `invited` could
    // mean "no invites" or "stale local copy"; the code being
    // present + invited being empty keeps us from refetching forever
    // for a member who's never invited anyone. Force-refresh paths
    // (page pull) call `refreshFromBackend` directly.
    if (state.code.isNotEmpty && state.invited.isNotEmpty) return;
    await _hydrateFromBackend();
  }

  /// Fetch the latest referral summary and persist it. Called from
  /// `_ensureSummaryFor` (cold-start hydrate) and from
  /// `refreshFromBackend` (page pull-to-refresh). Errors are
  /// swallowed — the cached state stays accurate even when the
  /// backend hiccups.
  Future<void> _hydrateFromBackend() async {
    try {
      final summary = await _repo.fetchMyReferralSummary();
      final invited = summary.invited
          .map(
            (i) => InvitedFriend(
              id: i.id,
              displayName: i.name?.trim().isNotEmpty == true
                  ? i.name!
                  : 'Member',
              status: ReferralStatus.values.firstWhere(
                (e) => e.name == i.status,
                orElse: () => ReferralStatus.pending,
              ),
              createdAt: i.createdAt,
              convertedAt: i.convertedAt,
            ),
          )
          .toList();
      state = state.copyWith(code: summary.code, invited: invited);
      await _store.writeCode(summary.code);
      await _store.writeInvited(invited);
    } catch (_) {
      // Offline / not-yet-authenticated: leave whatever we last had.
      // The next call (listener fire, page pull, or app restart) will
      // retry — surfacing a transient failure here only adds noise.
    }
  }

  /// Force-refresh path used by the invite page's pull-to-refresh.
  /// Bypasses the "already have code + invited" short-circuit so the
  /// member can always hammer the gesture to recheck their list.
  Future<void> refreshFromBackend() => _hydrateFromBackend();

  /// Call when signing up with a friend's code. Validates shape only —
  /// the real validation runs on the backend.
  Future<void> recordInvitedBy(String referrerName) async {
    state = state.copyWith(invitedByName: referrerName);
    await _store.writeInvitedByName(referrerName);
  }

  /// Claim a referrer's code post-signup. Calls the backend `POST
  /// /api/v1/referrals/claim` — that's what creates the real
  /// `referrals` row server-side, so the conversion-on-purchase logic
  /// can fire once the member's first paid subscription lands. Local
  /// state mirrors the backend's response so the invite page's "you
  /// were invited by …" badge is accurate immediately.
  Future<ClaimCodeResult> claimFriendCode(String rawCode) async {
    final normalised = _normaliseCode(rawCode);
    if (!_isValidCodeShape(normalised)) return ClaimCodeResult.invalidShape;
    if (state.code.isNotEmpty && normalised == state.code) {
      return ClaimCodeResult.ownCode;
    }
    if (state.invitedByName != null) return ClaimCodeResult.alreadyClaimed;
    try {
      final result = await _repo.claimReferralCode(normalised);
      if (result == null) return ClaimCodeResult.notFound;
      final name = result.referrerName;
      if (name.isEmpty) return ClaimCodeResult.notFound;
      state = state.copyWith(invitedByName: name);
      await _store.writeInvitedByName(name);
      return ClaimCodeResult.ok;
    } catch (_) {
      // Network failure — surface as not-found so the user can retry.
      return ClaimCodeResult.notFound;
    }
  }

  /// Reset on logout. The code is tied to the identity so a fresh session
  /// regenerates it from the next profile.
  Future<void> clear() async {
    state = ReferralState.empty;
    await _store.clear();
  }
}

String _normaliseCode(String raw) {
  return raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
}

final _codeShape = RegExp(r'^GP-[A-Z0-9]{6}$');
bool _isValidCodeShape(String code) => _codeShape.hasMatch(code);

final referralProvider =
    StateNotifierProvider<ReferralController, ReferralState>((ref) {
  return ReferralController._(
    ref.read(_referralStoreProvider),
    ref.read(authRepositoryProvider),
    ref,
  );
});
