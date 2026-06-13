import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../billing/data/billing_state.dart';
import '../../referral/data/referral_state.dart';
import '../../subscription/data/subscription_state.dart';
import '../data/auth_repository.dart';
import '../data/biometric_vault.dart';
import '../data/user_profile.dart';

enum AuthPhase { anonymous, awaitingCode, authed }

class AuthState {
  const AuthState({
    this.phase = AuthPhase.anonymous,
    this.phone = '',
    this.loading = false,
    this.error,
    this.requiresPassword = false,
    this.rememberMe = true,
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
  AuthController(
    this._repo,
    this._profile,
    this._profileStore,
    this._subscription,
    this._billing,
    this._referral,
    this._vault,
  ) : super(const AuthState()) {
    _bootstrapFuture = _bootstrap();
  }

  final AuthRepository _repo;
  final ProfileController _profile;
  final ProfileStore _profileStore;
  final SubscriptionNotifier _subscription;
  final BillingNotifier _billing;
  final ReferralController _referral;
  final BiometricVault _vault;

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
        'phone-check failed (treating as new user; tap Continue to surface)',
        name: 'auth.checkPhone',
        error: err,
        stackTrace: st,
      );
      state = state.copyWith(loading: false, requiresPassword: false);
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
      await _hydrateMemberStores();
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
      state = state.copyWith(loading: false, phase: AuthPhase.authed);
      return true;
    } catch (e) {
      // Most likely cause: server-side password change invalidated the
      // saved credential. Wipe the vault so the user is prompted for the
      // new password instead of being stuck on a failing biometric.
      await _vault.clear();
      state = state.copyWith(loading: false, error: e.toString());
      return false;
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

  /// Reset auth state *before* clearing downstream stores. GoRouter's refresh
  /// listener fires on every state change; if the profile is wiped while the
  /// auth phase is still `authed`, the "authed but no profile" branch of the
  /// redirect briefly matches and sends the user to /register instead of
  /// /sign-in.
  Future<void> logout() async {
    state = const AuthState();
    await _repo.logout();
    await _profile.clear();
    await _subscription.clear();
    await _billing.clear();
    await _referral.clear();
    await _vault.clear();
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
  );
});
