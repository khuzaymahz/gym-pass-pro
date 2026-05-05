import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _access = 'auth.access_token';
  static const _refresh = 'auth.refresh_token';

  /// "1" when the user ticked Remember me (default) and the session should
  /// survive cold starts; "0" when the session is ephemeral and the bootstrap
  /// should wipe it on next launch. Stored alongside the tokens so the
  /// backend-issued session can be re-hydrated or discarded atomically.
  static const _persistent = 'auth.persistent';

  Future<void> save({
    required String access,
    required String refresh,
    bool persistent = true,
  }) async {
    await _storage.write(key: _access, value: access);
    await _storage.write(key: _refresh, value: refresh);
    await _storage.write(key: _persistent, value: persistent ? '1' : '0');
  }

  Future<String?> readAccess() => _storage.read(key: _access);
  Future<String?> readRefresh() => _storage.read(key: _refresh);

  /// Defaults to true when the flag was never written — matches the previous
  /// (pre-remember-me) behavior for any session saved by an older build.
  Future<bool> isPersistent() async {
    final v = await _storage.read(key: _persistent);
    return v != '0';
  }

  Future<void> clear() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
    await _storage.delete(key: _persistent);
  }
}
