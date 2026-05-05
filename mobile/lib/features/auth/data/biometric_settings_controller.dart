import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'biometric_vault.dart';
import 'user_profile.dart';

/// Snapshot of the biometric-sign-in toggle state, exposed to the settings
/// sheet. `available` reflects device capability; `enabled` reflects the
/// user's saved preference + a real credential pair on disk. The settings
/// toggle is only render-able when `available && hasPassword` (the latter
/// because OTP-only / Google-only members have nothing to vault).
class BiometricSettingsState {
  const BiometricSettingsState({
    this.available = false,
    this.enabled = false,
    this.hasPassword = false,
    this.loading = false,
  });

  final bool available;
  final bool enabled;
  final bool hasPassword;
  final bool loading;

  BiometricSettingsState copyWith({
    bool? available,
    bool? enabled,
    bool? hasPassword,
    bool? loading,
  }) =>
      BiometricSettingsState(
        available: available ?? this.available,
        enabled: enabled ?? this.enabled,
        hasPassword: hasPassword ?? this.hasPassword,
        loading: loading ?? this.loading,
      );
}

/// Outcome of an enable/disable attempt. The settings sheet maps each case
/// to a localized snack message.
enum BiometricToggleResult {
  ok,
  passwordWrong,
  biometricCancelled,
  biometricUnavailable,
  network,
}

/// Owns the settings-side biometric flow. Kept separate from
/// [BiometricVault] (the storage) so the vault stays a thin data class and
/// this controller owns the orchestration: prompt → verify → save / clear.
class BiometricSettingsController
    extends StateNotifier<BiometricSettingsState> {
  BiometricSettingsController(this._vault, this._repo, this._profile)
      : super(const BiometricSettingsState()) {
    _refresh();
  }

  final BiometricVault _vault;
  final AuthRepository _repo;
  final ProfileController _profile;

  Future<void> _refresh() async {
    final available = await _vault.canUseBiometrics();
    final enabled = await _vault.isEnabled();
    final hasPassword = (_profile.state.passwordHash ?? '').isNotEmpty;
    state = state.copyWith(
      available: available,
      enabled: enabled,
      hasPassword: hasPassword,
    );
  }

  /// Re-runs the snapshot read. Called by the settings sheet on open so the
  /// state matches reality after returning from a long-lived session (e.g.
  /// the user enrolled a new fingerprint via the OS, or signed up for a
  /// password since the last open).
  Future<void> refresh() => _refresh();

  /// Verifies the user's password against the backend, prompts biometric,
  /// and saves the credential pair on success. We re-check the password
  /// here (rather than trusting that the user is signed in) so an attacker
  /// who picks up an unlocked phone can't silently arm biometric with a
  /// password they don't know — the prompt is a real proof-of-knowledge.
  Future<BiometricToggleResult> enable({
    required String password,
    required String localizedReason,
  }) async {
    state = state.copyWith(loading: true);
    try {
      final phone = _profile.state.phone ?? '';
      if (phone.isEmpty) {
        return BiometricToggleResult.network;
      }
      try {
        await _repo.loginWithPassword(
          phone: phone,
          password: password,
          persistent: true,
        );
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('AUTH_PASSWORD_INVALID')) {
          return BiometricToggleResult.passwordWrong;
        }
        return BiometricToggleResult.network;
      }
      final result = await _vault.authenticate(localizedReason: localizedReason);
      if (result == BiometricResult.unavailable) {
        return BiometricToggleResult.biometricUnavailable;
      }
      if (result == BiometricResult.cancelled) {
        return BiometricToggleResult.biometricCancelled;
      }
      await _vault.save(phone: phone, password: password);
      state = state.copyWith(enabled: true);
      return BiometricToggleResult.ok;
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// Clears the vault. We don't re-prompt on disable: the user is already
  /// past the app lock screen, and forcing biometric here would be
  /// frustrating if their fingerprint sensor is dirty or face recognition
  /// is failing — the very situations they'd want to disable in.
  Future<void> disable() async {
    state = state.copyWith(loading: true);
    try {
      await _vault.clear();
      state = state.copyWith(enabled: false);
    } finally {
      state = state.copyWith(loading: false);
    }
  }
}

final biometricSettingsProvider = StateNotifierProvider<
    BiometricSettingsController, BiometricSettingsState>((ref) {
  return BiometricSettingsController(
    ref.read(biometricVaultProvider),
    ref.read(authRepositoryProvider),
    ref.read(profileProvider.notifier),
  );
});
