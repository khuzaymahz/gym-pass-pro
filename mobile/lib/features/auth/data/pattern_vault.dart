import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/di/providers.dart';
import 'user_profile.dart';

/// Minimum connected nodes for a valid pattern.
const kPatternMinNodes = 4;

/// Secure storage for the pattern sign-in vault.
///
/// The pattern (ordered list of node indices 0–8) is hashed with SHA-256
/// before being written to [FlutterSecureStorage] — the plaintext sequence
/// never persists on disk. The phone+password credential pair is stored
/// alongside so a successful pattern match can replay the same
/// loginWithPassword call path that normal sign-in uses.
class PatternVault {
  PatternVault(this._storage);

  final FlutterSecureStorage _storage;

  static const _kEnabled = 'pattern.enabled';
  static const _kPhone = 'pattern.phone';
  static const _kPassword = 'pattern.password';
  static const _kHash = 'pattern.hash';

  Future<bool> isEnabled() async {
    try {
      final enabled = await _storage.read(key: _kEnabled);
      if (enabled != 'true') return false;
      final hash = await _storage.read(key: _kHash);
      final phone = await _storage.read(key: _kPhone);
      final password = await _storage.read(key: _kPassword);
      return hash != null && phone != null && password != null;
    } catch (err, st) {
      developer.log(
        'pattern vault read failed — treating as disabled',
        name: 'auth.pattern',
        error: err,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<void> save({
    required List<int> pattern,
    required String phone,
    required String password,
  }) async {
    final hash = _hashPattern(pattern);
    await _storage.write(key: _kHash, value: hash);
    await _storage.write(key: _kPhone, value: phone);
    await _storage.write(key: _kPassword, value: password);
    await _storage.write(key: _kEnabled, value: 'true');
  }

  Future<bool> verify(List<int> pattern) async {
    try {
      final stored = await _storage.read(key: _kHash);
      if (stored == null) return false;
      return stored == _hashPattern(pattern);
    } catch (_) {
      return false;
    }
  }

  Future<({String phone, String password})?> readCredentials({
    required List<int> pattern,
  }) async {
    if (!await verify(pattern)) return null;
    final phone = await _storage.read(key: _kPhone);
    final password = await _storage.read(key: _kPassword);
    if (phone == null || password == null) return null;
    return (phone: phone, password: password);
  }

  /// Updates the stored phone+password without touching the pattern hash.
  /// Called after a successful password sign-in so the vault stays in sync
  /// if the user changed their password since the last time they set up pattern.
  Future<void> refreshCredentials({required String phone, required String password}) async {
    final enabled = await _storage.read(key: _kEnabled);
    if (enabled != 'true') return;
    await _storage.write(key: _kPhone, value: phone);
    await _storage.write(key: _kPassword, value: password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kEnabled);
    await _storage.delete(key: _kHash);
    await _storage.delete(key: _kPhone);
    await _storage.delete(key: _kPassword);
  }

  static String _hashPattern(List<int> pattern) {
    final bytes = utf8.encode(pattern.join(','));
    return sha256.convert(bytes).toString();
  }
}

final patternVaultProvider = Provider<PatternVault>((ref) {
  return PatternVault(ref.read(secureStorageProvider));
});

// ---------------------------------------------------------------------------
// Settings controller
// ---------------------------------------------------------------------------

class PatternSettingsState {
  const PatternSettingsState({
    this.enabled = false,
    this.hasPassword = false,
    this.loading = false,
  });

  final bool enabled;
  final bool hasPassword;
  final bool loading;

  PatternSettingsState copyWith({
    bool? enabled,
    bool? hasPassword,
    bool? loading,
  }) =>
      PatternSettingsState(
        enabled: enabled ?? this.enabled,
        hasPassword: hasPassword ?? this.hasPassword,
        loading: loading ?? this.loading,
      );
}

enum PatternEnableResult { ok, passwordWrong, network }

class PatternSettingsController
    extends StateNotifier<PatternSettingsState> {
  PatternSettingsController(this._vault, this._profile)
      : super(const PatternSettingsState()) {
    _refresh();
  }

  final PatternVault _vault;
  final ProfileController _profile;

  Future<void> _refresh() async {
    final enabled = await _vault.isEnabled();
    final hasPassword = (_profile.state.passwordHash ?? '').isNotEmpty;
    state = state.copyWith(enabled: enabled, hasPassword: hasPassword);
  }

  Future<void> refresh() => _refresh();

  Future<PatternEnableResult> enable({
    required String password,
    required List<int> pattern,
  }) async {
    state = state.copyWith(loading: true);
    try {
      final phone = _profile.state.phone ?? '';
      if (phone.isEmpty) return PatternEnableResult.network;
      try {
        await _vault.save(pattern: pattern, phone: phone, password: password);
        state = state.copyWith(enabled: true);
        return PatternEnableResult.ok;
      } catch (_) {
        return PatternEnableResult.network;
      }
    } finally {
      state = state.copyWith(loading: false);
    }
  }

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

final patternSettingsProvider = StateNotifierProvider<
    PatternSettingsController, PatternSettingsState>((ref) {
  return PatternSettingsController(
    ref.read(patternVaultProvider),
    ref.read(profileProvider.notifier),
  );
});
