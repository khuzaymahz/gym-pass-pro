import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/token_store.dart';
import '../../../core/di/providers.dart';
import 'user_profile.dart';

/// Snapshot of `/me` from the backend. Used by the controller to rehydrate
/// [UserProfile] after a fresh sign-in or token refresh.
class MeResponse {
  const MeResponse({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.gender,
    required this.hasPassword,
  });

  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final Gender? gender;
  final bool hasPassword;

  UserProfile toProfile({String? localPasswordHash}) {
    return UserProfile(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      gender: gender,
      // Backend stores an argon2id hash we never see — `localPasswordHash` is
      // the SHA-256 the mobile keeps as a marker so the local store knows
      // a password exists. If we just signed up we know the local hash;
      // otherwise fall back to a non-empty sentinel when the server says so.
      passwordHash: localPasswordHash ?? (hasPassword ? '__remote__' : null),
    );
  }
}

class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  Future<void> requestPhoneOtp(String phone) async {
    await _api.post<void>('/api/v1/auth/phone/start', body: {'phone': phone});
  }

  /// Server-side existence check used by the sign-in page to decide between
  /// OTP and password sign-in, and by the forgot-password page to know
  /// whether email-reset is available. The backend returns a masked email
  /// (e.g. `om**@x.com`) when one is on file — never the full address.
  Future<({bool exists, bool hasPassword, String? maskedEmail})> checkPhone(
    String phone,
  ) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/auth/phone/check',
      body: {'phone': phone},
    );
    final data = response.data!;
    return (
      exists: data['exists'] as bool,
      hasPassword: data['hasPassword'] as bool,
      maskedEmail: data['maskedEmail'] as String?,
    );
  }

  Future<void> verifyPhoneOtp({
    required String phone,
    required String code,
    bool persistent = true,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/auth/phone/verify',
      body: {'phone': phone, 'code': code},
    );
    final data = response.data!;
    await _tokens.save(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
      persistent: persistent,
    );
  }

  /// Google ID-token exchange. Backend stub today; the production path will
  /// verify the ID token server-side and mint the same token pair.
  Future<void> exchangeGoogle({
    required String idToken,
    bool persistent = true,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/auth/google/exchange',
      body: {'idToken': idToken},
    );
    final data = response.data!;
    await _tokens.save(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
      persistent: persistent,
    );
  }

  /// Phone+password sign-in. Mirrors the OTP-verify token shape so the
  /// session bootstrap path is identical for both entry points.
  Future<void> loginWithPassword({
    required String phone,
    required String password,
    bool persistent = true,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      body: {'phone': phone, 'password': password},
    );
    final data = response.data!;
    await _tokens.save(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
      persistent: persistent,
    );
  }

  /// PATCH /me with the registration payload. Sent right after the OTP-verify
  /// step has minted a session, so the brand-new member row gets the rest
  /// of its profile fields filled in.
  Future<MeResponse> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    Gender? gender,
    DateTime? birthdate,
    String? password,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (email != null) body['email'] = email;
    if (gender != null) body['gender'] = gender.name;
    if (birthdate != null) {
      body['birthdate'] =
          '${birthdate.year.toString().padLeft(4, '0')}-${birthdate.month.toString().padLeft(2, '0')}-${birthdate.day.toString().padLeft(2, '0')}';
    }
    if (password != null) body['password'] = password;
    final response = await _api.patch<Map<String, dynamic>>(
      '/api/v1/me',
      body: body,
      authed: true,
    );
    return _decodeMe(response.data!);
  }

  /// Authenticated phone-change OTP request. The backend sends an OTP to the
  /// new phone; verification mints no new tokens — it just swaps the field.
  Future<void> requestPhoneChange(String newPhone) async {
    await _api.post<void>(
      '/api/v1/me/phone/start',
      body: {'phone': newPhone},
      authed: true,
    );
  }

  Future<MeResponse> verifyPhoneChange({
    required String newPhone,
    required String code,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/me/phone/verify',
      body: {'phone': newPhone, 'code': code},
      authed: true,
    );
    return _decodeMe(response.data!);
  }

  Future<MeResponse> fetchMe() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/me',
      authed: true,
    );
    return _decodeMe(response.data!);
  }

  MeResponse _decodeMe(Map<String, dynamic> data) {
    return MeResponse(
      firstName: data['firstName'] as String?,
      lastName: data['lastName'] as String?,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      gender: Gender.fromName(data['gender'] as String?),
      hasPassword: data['hasPassword'] as bool? ?? false,
    );
  }

  /// Returns the authenticated user's full referral summary — the code
  /// (created server-side if missing), the canonical share URL, the
  /// status counts, and the list of invited friends with their conversion
  /// state. Mobile uses this on hydrate AND on the invite-page pull-to-
  /// refresh so the share/invited surfaces always reflect what the
  /// backend has, not a local snapshot. Replaces the older
  /// `fetchMyReferralCode` which read the same endpoint but threw away
  /// every field except `code`, leaving the invited list permanently
  /// stale on disk.
  Future<MyReferralSummary> fetchMyReferralSummary() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/me/referral',
      authed: true,
    );
    return MyReferralSummary.fromJson(response.data!);
  }

  /// Look up a friend's referral code on the backend. Returns the referrer's
  /// display name on success, null if the code doesn't exist or the caller is
  /// the owner. Authenticated to keep the mapping out of anonymous scrapers.
  Future<String?> resolveReferralCode(String code) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/referrals/resolve',
        query: {'code': code},
        authed: true,
      );
      return response.data!['name'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Submit the friend's referral code to the backend so a real
  /// `referrals` row is created. The backend handles idempotency
  /// (existing referral row returns the same referrer) and rejects
  /// self-referral / unknown codes — surface those as null so the UI
  /// maps to the existing "not found" branch.
  Future<({String referrerName, String code})?> claimReferralCode(
    String code,
  ) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/api/v1/referrals/claim',
        body: {'code': code},
        authed: true,
      );
      final data = response.data!;
      return (
        referrerName: (data['referrerName'] ?? '').toString(),
        code: (data['code'] ?? '').toString(),
      );
    } on DioException catch (e) {
      // 404 = unknown code, 422 = self-referral or validation; both map
      // to the same "not found" UI branch.
      if (e.response?.statusCode == 404 || e.response?.statusCode == 422) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    // Best-effort backend revocation BEFORE wiping local tokens —
    // once `_tokens.clear()` runs we lose the refresh token we'd
    // need to send. Network failures are swallowed so a logout in
    // an airplane-mode tunnel still wipes the local session; the
    // refresh token will eventually expire on its own. Backend
    // logout is idempotent so a re-tried offline logout is fine.
    try {
      final refresh = await _tokens.readRefresh();
      if (refresh != null) {
        await _api.post<void>(
          '/api/v1/auth/logout',
          body: {'refreshToken': refresh},
        );
      }
    } catch (_) {
      // Network / 4xx — local wipe still happens below.
    }
    await _tokens.clear();
  }

  Future<bool> hasSession() async => (await _tokens.readAccess()) != null;

  Future<bool> isSessionPersistent() => _tokens.isPersistent();
}

/// Wire shape of `GET /api/v1/me/referral`. Mirrors the backend's
/// `MyReferralSummary` Pydantic model 1:1 — `code`, the canonical
/// `shareUrl`, status counts, and the list of invited friends with
/// their conversion state. Kept dumb so the controller can decide
/// how to fold it into local state without this layer leaking
/// `ReferralStatus` from the controller's enum.
class MyReferralSummary {
  const MyReferralSummary({
    required this.code,
    required this.shareUrl,
    required this.counts,
    required this.invited,
  });

  final String code;
  final String shareUrl;
  final Map<String, int> counts;
  final List<MyReferralInvited> invited;

  factory MyReferralSummary.fromJson(Map<String, dynamic> j) {
    final rawCounts = (j['counts'] as Map?) ?? const {};
    return MyReferralSummary(
      code: j['code'] as String,
      shareUrl: (j['shareUrl'] ?? '') as String,
      counts: rawCounts.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      invited: ((j['invited'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(MyReferralInvited.fromJson)
          .toList(),
    );
  }
}

class MyReferralInvited {
  const MyReferralInvited({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    this.convertedAt,
  });

  final String id;
  final String? name;

  /// Always one of `pending`, `converted`, `expired` — mirrors the
  /// backend `referral_status_enum`. The controller maps this to its
  /// local Dart enum.
  final String status;
  final DateTime createdAt;
  final DateTime? convertedAt;

  factory MyReferralInvited.fromJson(Map<String, dynamic> j) {
    return MyReferralInvited(
      id: j['id'] as String,
      name: j['name'] as String?,
      status: j['status'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      convertedAt: j['convertedAt'] == null
          ? null
          : DateTime.parse(j['convertedAt'] as String),
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(apiClientProvider),
    ref.read(tokenStoreProvider),
  );
});
