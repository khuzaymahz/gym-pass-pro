import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/di/providers.dart';

/// Outcome of a biometric authentication attempt. UI maps each case to a
/// localized snack so callers stay decoupled from platform-specific errors.
enum BiometricResult {
  /// User authenticated successfully — caller may proceed to read saved
  /// credentials and call `loginWithPassword`.
  ok,

  /// Device has no enrolled biometrics or hardware is unavailable. The
  /// settings toggle should be disabled in this state.
  unavailable,

  /// User cancelled the prompt or failed too many times. Don't surface as an
  /// error — just no-op and let them tap the biometric pill again.
  cancelled,
}

/// Encapsulates the biometric "remember me" vault.
///
/// Two responsibilities, kept narrow on purpose:
///   1. Checking whether the device can prompt for biometrics at all
///      (`canUseBiometrics`) — drives whether the settings toggle is
///      enabled and whether the sign-in page shows the biometric pill.
///   2. Owning the encrypted store of saved phone+password credentials
///      (`save`, `read`, `clear`) — gated behind a successful biometric
///      prompt before any read.
///
/// We never store the plaintext password in app memory longer than the read
/// → loginWithPassword call chain. The on-disk copy lives in
/// flutter_secure_storage (Keychain on iOS, EncryptedSharedPreferences on
/// Android) so the bytes are encrypted at rest by the OS.
class BiometricVault {
  BiometricVault(this._auth, this._storage);

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  static const _kEnabled = 'biometric.enabled';
  static const _kPhone = 'biometric.phone';
  static const _kPassword = 'biometric.password';

  /// True when the device has hardware + at least one enrolled biometric or
  /// has device credentials (PIN/passcode) configured. We accept the latter
  /// because [LocalAuthentication.authenticate] is configured with
  /// `biometricOnly: false`, so it falls back to the device PIN when no
  /// fingerprint/face is enrolled — that's still a hardware-bound secret,
  /// not a plaintext.
  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      // canCheckBiometrics is true when the user has enrolled at least one
      // biometric. If they haven't, isDeviceSupported still gates the OS
      // PIN fallback, so we accept either path.
      return true;
    } catch (err, st) {
      // Older Android skus without a fingerprint reader can throw on the
      // platform channel call — treat as unavailable. Log so a member
      // reporting "biometric never appears" can be diagnosed.
      developer.log(
        'biometric capability probe failed — treating as unavailable',
        name: 'auth.biometric',
        error: err,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Whether the user has opted into biometric sign-in *and* has saved
  /// credentials on file. Both flags are required: a stale `enabled=true`
  /// after a logout would otherwise show the biometric pill on a sign-in
  /// page that has nothing to unlock.
  Future<bool> isEnabled() async {
    final enabled = await _storage.read(key: _kEnabled);
    if (enabled != 'true') return false;
    final phone = await _storage.read(key: _kPhone);
    final password = await _storage.read(key: _kPassword);
    return phone != null && password != null;
  }

  /// Prompts the user for biometric (or PIN fallback). Returns one of:
  ///   - [BiometricResult.ok]            — proceed to [readCredentials].
  ///   - [BiometricResult.cancelled]     — user dismissed; UI should no-op.
  ///   - [BiometricResult.unavailable]   — hardware/enrolment missing.
  ///
  /// `localizedReason` is the human-readable string shown inside the prompt
  /// dialog (iOS) / under the fingerprint icon (Android). We keep it as a
  /// caller-supplied string so the i18n layer owns the translation, not
  /// this data class.
  Future<BiometricResult> authenticate({required String localizedReason}) async {
    if (!await canUseBiometrics()) return BiometricResult.unavailable;
    try {
      final ok = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      return ok ? BiometricResult.ok : BiometricResult.cancelled;
    } catch (err, st) {
      // The platform-channel `authenticate` can throw on user-
      // cancel, hardware error, or transient OS issue. Treat any
      // throw as a cancel from the user's POV (we don't want to
      // surface a stack trace at sign-in), but log so a stuck
      // "biometric prompt does nothing" report can be triaged.
      developer.log(
        'biometric authenticate threw — treating as cancelled',
        name: 'auth.biometric',
        error: err,
        stackTrace: st,
      );
      return BiometricResult.cancelled;
    }
  }

  /// Persist the phone+password pair. Caller is responsible for having
  /// already confirmed the user just authenticated successfully (either via
  /// fresh password sign-in, or via a biometric prompt during the settings
  /// "turn on" flow) — the vault doesn't re-prompt here.
  Future<void> save({required String phone, required String password}) async {
    await _storage.write(key: _kPhone, value: phone);
    await _storage.write(key: _kPassword, value: password);
    await _storage.write(key: _kEnabled, value: 'true');
  }

  /// Read the saved credentials. Returns null if the vault is empty or
  /// disabled. Callers MUST gate this behind a successful
  /// [authenticate] call — the secure-storage entry itself isn't tied to
  /// the biometric prompt at the OS level (that requires
  /// platform-specific iOS access-control flags we deliberately don't
  /// configure to keep the Android/iOS code paths symmetric).
  Future<({String phone, String password})?> readCredentials() async {
    if (!await isEnabled()) return null;
    final phone = await _storage.read(key: _kPhone);
    final password = await _storage.read(key: _kPassword);
    if (phone == null || password == null) return null;
    return (phone: phone, password: password);
  }

  /// Wipe the vault. Called from logout and from the settings toggle when
  /// the user disables biometric sign-in.
  Future<void> clear() async {
    await _storage.delete(key: _kEnabled);
    await _storage.delete(key: _kPhone);
    await _storage.delete(key: _kPassword);
  }
}

final localAuthProvider = Provider<LocalAuthentication>((ref) {
  return LocalAuthentication();
});

final biometricVaultProvider = Provider<BiometricVault>((ref) {
  return BiometricVault(
    ref.read(localAuthProvider),
    ref.read(secureStorageProvider),
  );
});
