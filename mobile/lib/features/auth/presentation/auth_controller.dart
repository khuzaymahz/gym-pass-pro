import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/network_error.dart';

import '../../../core/prefs/app_preferences.dart';
import '../../../core/push/push_notification_service.dart';
import '../../billing/data/billing_state.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../referral/data/referral_state.dart';
import '../../subscription/data/subscription_state.dart';
import '../data/auth_repository.dart';
import '../data/biometric_vault.dart';
import '../data/pattern_vault.dart';
import '../data/user_profile.dart';

enum AuthPhase { anonymous, awaitingCode, authed }

/// Result of a pattern sign-in attempt, used by [_PatternEntrySheet] to
/// distinguish three outcomes without inspecting raw error strings in the UI.
enum PatternSignInResult {
  /// Hash matched and backend accepted the credentials — navigate to /home.
  success,
  /// Hash did not match the vault — flash error, reset grid, retry.
  wrongPattern,
  /// Hash matched but the backend rejected the login (e.g. password changed,
  /// user not in the local dev DB). Pop the sheet so the error message from
  /// [AuthState.error] becomes visible on the sign-in page.
  backendError,
}

class AuthState {
  const AuthState({
    this.phase = AuthPhase.anonymous,
    this.phone = '',
    this.loading = false,
    this.error,
    this.requiresPassword = false,
    this.rememberMe = false,
  });

  final AuthPhase phase;
  final String phone;
  final bool loading;
  final String? error;

  /// True once [AuthController.checkPhone] has confirmed the phone belongs to
  /// a member who set a password during registration. Drives the sign-in page
  /// to reveal the password field instead of triggering an OTP.
  final bool requiresPassword;

  /// UI preference toggled alongside the password field on sign-in. The app
  /// already persists the session locally; flipping this off is the hook for a
  /// future "ephemeral session" mode.
  final bool rememberMe;

  AuthState copyWith({
    AuthPhase? phase,
    String? phone,
    bool? loading,
    String? error,
    bool? requiresPassword,
    bool? rememberMe,
  }) {
    return AuthState(
      phase: phase ?? this.phase,
      phone: phone ?? this.phone,
      loading: loading ?? this.loading,
      error: error,
      requiresPassword: requiresPassword ?? this.requiresPassword,
      rememberMe: rememberMe ?? this.rememberMe,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  static const _kRememberMe = 'auth.remember_me';

  AuthController(
    this._repo,
    this._profile,
    this._profileStore,
    this._subscription,
    this._billing,
    this._referral,
    this._vault,
    this._patternVault,
    this._notifications,
    this._prefs,
  ) : super(AuthState(rememberMe: _prefs.getBool(_kRememberMe) ?? false)) {
    _bootstrapFuture = _bootstrap();
  }

  final AuthRepository _repo;
  final ProfileController _profile;
  final ProfileStore _profileStore;
  final SharedPreferences _prefs;
  final SubscriptionNotifier _subscription;
  final BillingNotifier _billing;
  final ReferralController _referral;
  final BiometricVault _vault;
  final PatternVault _patternVault;
  final NotificationsRepository _notifications;

  late final Future<void> _bootstrapFuture;

  /// Resolves once session-restore has finished — either because no session
  /// was stored, or because tokens + profile were validated and [state]
  /// flipped to [AuthPhase.authed]. The splash page awaits this before
  /// handing off to the router so returning members don't get bounced to
  /// `/sign-in` while bootstrap is still reading from secure_storage.
  Future<void> get ready => _bootstrapFuture;

  /// A valid session requires a complete profile. If the app was killed
  /// mid-registration (tokens saved but no name/email yet), wipe the session
  /// on next launch so the user lands on /sign-in, not on a stale /register.
  /// An ephemeral session (Remember me was unchecked) is also wiped here,
  /// so the user has to re-authenticate every cold start.
  Future<void> _bootstrap() async {
    // Wrap the whole bootstrap in a try/catch so a rare secure_storage
    // failure (corrupted Keystore, OS denial after a backup restore,
    // missing iOS Keychain entitlement) doesn't deadlock the splash.
    // On any failure we fall through to the unauth state — the router
    // sends the member to /sign-in and they re-authenticate fresh.
    try {
      if (!await _repo.hasSession()) return;
      final persistent = await _repo.isSessionPersistent();
      if (!persistent) {
        await _repo.logout();
        return;
      }
      final saved = await _profileStore.read();
      if (!saved.isComplete) {
        await _repo.logout();
        await _profile.clear();
        await _subscription.clear();
        await _billing.clear();
        await _referral.clear();
        return;
      }
      state = state.copyWith(phase: AuthPhase.authed);
    } catch (_) {
      // Best-effort cleanup — same idempotent surface a normal logout
      // hits. Swallowed so the splash always resolves. Log the
      // failure so a stuck "ghost session" symptom in the wild
      // has a breadcrumb in `flutter logs` / `adb logcat` (was
      // pure `catch (_) {}` before; ops had nothing to grep).
      try {
        await _repo.logout();
      } catch (err, st) {
        developer.log(
          'bootstrap logout cleanup failed',
          name: 'auth.bootstrap',
          error: err,
          stackTrace: st,
        );
      }
    }
  }

  /// Phone existence + has-password check against the backend. Triggered as
  /// the user finishes typing a valid phone number, so the UI can reveal the
  /// password field for returning members. The endpoint is a cheap lookup,
  /// not an OTP send — no rate-limit concern.
  ///
  /// On failure we still resolve to `requiresPassword: false` so the user can
  /// hit Continue — `_startOtp` will surface the real error if the backend
  /// is genuinely down. We log via `developer.log` so an `adb logcat` /
  /// `flutter logs` capture has the real exception (and a Sentry breadcrumb
  /// downstream, when that ships). Previously a bare `catch (_)` swallowed
  /// everything, which produced the "registered number treated as new"
  /// symptom whenever the API origin was 5xx or unreachable.
  Future<void> checkPhone(String phone) async {
    state = state.copyWith(
      loading: true,
      error: null,
      phone: phone,
      requiresPassword: false,
    );
    try {
      final result = await _repo.checkPhone(phone);
      state = state.copyWith(
        loading: false,
        requiresPassword: result.exists && result.hasPassword,
      );
    } catch (err, st) {
      developer.log(
        'phone-check failed — retrying once after 500ms',
        name: 'auth.checkPhone',
        error: err,
        stackTrace: st,
      );
      // One automatic retry: the first HTTP request on a freshly-installed
      // app can fail while the TCP connection to the backend is warming up.
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        if (state.phone != phone) return; // user changed number while we waited
        final retry = await _repo.checkPhone(phone);
        state = state.copyWith(loading: false, requiresPassword: retry.exists && retry.hasPassword);
      } catch (_) {
        state = state.copyWith(loading: false, requiresPassword: false);
      }
    }
  }

  Future<void> requestOtp(String phone) async {
    state = state.copyWith(
      loading: true,
      error: null,
      phone: phone,
      requiresPassword: false,
    );
    await _startOtp(phone);
  }

  Future<void> _startOtp(String phone) async {
    try {
      await _repo.requestPhoneOtp(phone);
      state = state.copyWith(loading: false, phase: AuthPhase.awaitingCode);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Sign in a returning member with their password via `POST /auth/login`,
  /// then rehydrate the local profile from `/me`. Passes the current
  /// [AuthState.rememberMe] to the repo so the session either persists
  /// across cold starts or is wiped on next launch.
  ///
  /// On success, refreshes the biometric vault if it's already armed —
  /// keeps the saved password in sync after the user changes it via
  /// forgot-password or settings, so the next biometric sign-in doesn't
  /// fail with a stale credential.
  Future<void> signInWithPassword(String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.loginWithPassword(
        phone: state.phone,
        password: password,
        persistent: state.rememberMe,
      );
      final me = await _repo.fetchMe();
      await _profile.restore(me.toProfile());
      // Server never returns the password hash; stamp it locally now that
      // the user just proved knowledge of it. BiometricSettingsState reads
      // this to gate the biometric toggle.
      await _profile.markPasswordKnown(password);
      if (await _vault.isEnabled()) {
        await _vault.save(phone: state.phone, password: password);
      }
      // Keep pattern vault credentials in sync in case the user changed
      // their password — avoids a stale-credential failure on next pattern login.
      await _patternVault.refreshCredentials(phone: state.phone, password: password);
      await _hydrateMemberStores();
      unawaited(_registerPushToken());
      state = state.copyWith(loading: false, phase: AuthPhase.authed);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Biometric sign-in. Reads the saved phone+password from the vault
  /// (caller has already prompted for biometric and unlocked it) and
  /// trades them for a session via the same `/auth/login` path. Same
  /// post-conditions as [signInWithPassword]: profile rehydrated,
  /// [AuthPhase.authed] on success.
  ///
  /// Returns false if the vault is empty (e.g. the user disabled
  /// biometric on another device and we haven't synced yet) — UI should
  /// fall back to the password field.
  Future<bool> signInWithBiometric() async {
    final creds = await _vault.readCredentials();
    if (creds == null) return false;
    state = state.copyWith(loading: true, error: null, phone: creds.phone);
    try {
      await _repo.loginWithPassword(
        phone: creds.phone,
        password: creds.password,
        persistent: true,
      );
      final me = await _repo.fetchMe();
      await _profile.restore(me.toProfile());
      await _profile.markPasswordKnown(creds.password);
      await _hydrateMemberStores();
      unawaited(_registerPushToken());
      state = state.copyWith(loading: false, phase: AuthPhase.authed);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      // Only wipe the vault when the server explicitly rejected the credential
      // (4xx auth error). Network failures and 5xx errors are transient —
      // clearing on those would force the user to re-enroll every time the
      // backend is briefly unreachable.
      final classified = classifyNetworkError(e);
      if (classified.kind == NetworkErrorKind.clientError) {
        await _vault.clear();
      }
      return false;
    }
  }

  /// Pattern sign-in. Verifies [pattern] against the hash in [PatternVault]
  /// and, on a match, replays the same loginWithPassword path as biometric
  /// sign-in. Returns a [PatternSignInResult] so the sheet can distinguish
  /// "wrong pattern" (retry) from "backend error" (pop + show error).
  Future<PatternSignInResult> signInWithPattern(List<int> pattern) async {
    final creds = await _patternVault.readCredentials(pattern: pattern);
    if (creds == null) return PatternSignInResult.wrongPattern;
    state = state.copyWith(loading: true, error: null, phone: creds.phone);
    try {
      await _repo.loginWithPassword(
        phone: creds.phone,
        password: creds.password,
        persistent: true,
      );
      final me = await _repo.fetchMe();
      await _profile.restore(me.toProfile());
      await _profile.markPasswordKnown(creds.password);
      await _hydrateMemberStores();
      unawaited(_registerPushToken());
      state = state.copyWith(loading: false, phase: AuthPhase.authed);
      return PatternSignInResult.success;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return PatternSignInResult.backendError;
    }
  }

  /// Overwrites the stored password for the member identified by [phone].
  /// Called by the forgot-password flow after the reset code has been
  /// verified. Returns true if PATCH /me succeeded.
  ///
  /// Assumes a valid session exists (the OTP-verify step that gates the
  /// forgot-password flow mints one). PATCH /me is auth-protected, so this
  /// only works for the currently signed-in user.
  Future<bool> updatePassword({
    required String phone,
    required String newPassword,
  }) async {
    try {
      await _repo.updateProfile(password: newPassword);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Called by the sign-in page when the user edits the phone field after a
  /// prior check succeeded, so the password prompt doesn't linger against a
  /// different number.
  void resetPhoneCheck() {
    if (!state.requiresPassword && state.error == null && state.phone.isEmpty) {
      return;
    }
    state = state.copyWith(
      phone: '',
      requiresPassword: false,
      error: null,
    );
  }

  void setRememberMe(bool value) {
    if (state.rememberMe == value) return;
    state = state.copyWith(rememberMe: value);
    _prefs.setBool(_kRememberMe, value);
  }

  Future<void> verifyOtp(String code) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.verifyPhoneOtp(
        phone: state.phone,
        code: code,
        persistent: state.rememberMe,
      );
      final me = await _repo.fetchMe();
      // Returning members already have a name/email/gender on the row;
      // brand-new members come back with only phone + role set, so the
      // router redirects them to /register to fill the rest in.
      if (me.firstName != null || me.lastName != null || me.email != null) {
        await _profile.restore(me.toProfile());
      } else {
        await _profile.setPhone(state.phone);
      }
      await _hydrateMemberStores();
      unawaited(_registerPushToken());
      state = state.copyWith(loading: false, phase: AuthPhase.authed);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Re-hydrate the member-scoped stores that get wiped by `logout()`. After
  /// a fresh sign-in the surviving notifier instances are at their initial
  /// empty state — without this, /home would render the "no plan" empty card
  /// until the user manually pulls to refresh, and /billing would render an
  /// empty payment-methods list. Profile is already restored by the caller
  /// from the `/me` payload, so it's not included here.
  Future<void> _hydrateMemberStores() async {
    await Future.wait([
      _subscription.refreshFromBackend(),
      _billing.refreshFromBackend(),
    ]);
  }

  /// Best-effort FCM token registration after sign-in. Never throws — a
  /// delivery failure must not abort the sign-in flow.
  Future<void> _registerPushToken() async {
    try {
      final token = await PushNotificationService.instance.getToken();
      if (token != null) {
        await _notifications.registerDeviceToken(token);
      }
    } catch (_) {
      // Swallowed — push registration is advisory, not load-bearing.
    }
  }

  /// Best-effort FCM token removal on logout. Prevents notifications from
  /// reaching a device that has since signed out.
  Future<void> _unregisterPushToken() async {
    try {
      final token = await PushNotificationService.instance.getToken();
      if (token != null) {
        await _notifications.deleteDeviceToken(token);
      }
    } catch (_) {
      // Swallowed — best-effort, doesn't affect session validity.
    }
  }

  /// Reset auth state *before* clearing downstream stores. GoRouter's refresh
  /// listener fires on every state change; if the profile is wiped while the
  /// auth phase is still `authed`, the "authed but no profile" branch of the
  /// redirect briefly matches and sends the user to /register instead of
  /// /sign-in.
  ///
  /// Pattern and biometric vaults are intentionally NOT cleared here — they
  /// survive logout so the user can sign back in by drawing their pattern or
  /// scanning their face/fingerprint without re-arming the vault every session.
  /// Vaults are only cleared when the user explicitly disables them in Settings
  /// or when the backend rejects the stored credentials.
  Future<void> logout() async {
    state = AuthState(rememberMe: _prefs.getBool(_kRememberMe) ?? false);
    // Unregister push token before clearing the session — the DELETE call
    // needs the auth token still in store.
    unawaited(_unregisterPushToken());
    await _repo.logout();
    await _profile.clear();
    await _subscription.clear();
    await _billing.clear();
    await _referral.clear();
  }

  /// Stub for Google sign-in. The backend `/auth/google/exchange` is a dev-only
  /// stub today — it accepts any id_token and pins the email to a dev-shared
  /// account. We pass [email] through so the eventual real ID-token-verify
  /// path keeps the same call shape; until then the parameter is unused
  /// server-side. Throws in production until real verification ships.
  Future<void> mockGoogleSignIn({required String email}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.exchangeGoogle(
        idToken: 'mobile-mock-${DateTime.now().millisecondsSinceEpoch}',
        persistent: state.rememberMe,
      );
      final me = await _repo.fetchMe();
      if (me.firstName != null || me.lastName != null || me.email != null) {
        await _profile.restore(me.toProfile());
      } else {
        await _profile.setEmail(me.email ?? email);
      }
      await _hydrateMemberStores();
      unawaited(_registerPushToken());
      state = state.copyWith(loading: false, phase: AuthPhase.authed);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.read(authRepositoryProvider),
    ref.read(profileProvider.notifier),
    ref.read(profileStoreProvider),
    ref.read(subscriptionProvider.notifier),
    ref.read(billingProvider.notifier),
    ref.read(referralProvider.notifier),
    ref.read(biometricVaultProvider),
    ref.read(patternVaultProvider),
    ref.read(notificationsRepositoryProvider),
    ref.read(sharedPreferencesProvider),
  );
});
