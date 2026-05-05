import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/di/providers.dart';

class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.device,
    required this.location,
    required this.lastActiveIso,
    required this.isCurrent,
  });

  final String id;
  final String device;
  final String location;
  final String lastActiveIso;
  final bool isCurrent;

  Map<String, dynamic> toJson() => {
        'id': id,
        'device': device,
        'location': location,
        'lastActive': lastActiveIso,
        'current': isCurrent,
      };

  static ActiveSession fromJson(Map<String, dynamic> j) => ActiveSession(
        id: j['id'] as String,
        device: j['device'] as String,
        location: j['location'] as String,
        lastActiveIso: j['lastActive'] as String,
        isCurrent: j['current'] as bool? ?? false,
      );
}

class SecurityState {
  const SecurityState({
    this.sessions = const [],
    this.loaded = false,
  });

  final List<ActiveSession> sessions;
  final bool loaded;

  SecurityState copyWith({
    List<ActiveSession>? sessions,
    bool? loaded,
  }) =>
      SecurityState(
        sessions: sessions ?? this.sessions,
        loaded: loaded ?? this.loaded,
      );
}

class SecurityNotifier extends StateNotifier<SecurityState> {
  SecurityNotifier(this._storage) : super(const SecurityState()) {
    _load();
  }

  final FlutterSecureStorage _storage;
  static const _sessionsKey = 'security.sessions';

  Future<void> _load() async {
    final sessionsRaw = await _storage.read(key: _sessionsKey);
    // Active sessions come from the backend — this notifier just mirrors
    // whatever has been persisted. No seeded demo rows; an unauthenticated
    // device sees an empty list (CLAUDE.md §9).
    final sessions = sessionsRaw == null
        ? const <ActiveSession>[]
        : (jsonDecode(sessionsRaw) as List)
            .map((e) => ActiveSession.fromJson(e as Map<String, dynamic>))
            .toList();
    state = SecurityState(
      sessions: sessions,
      loaded: true,
    );
  }

  Future<void> revokeSession(String id) async {
    final next = state.sessions.where((s) => s.id != id).toList();
    state = state.copyWith(sessions: next);
    await _storage.write(
      key: _sessionsKey,
      value: jsonEncode(next.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> revokeAllOthers() async {
    final next = state.sessions.where((s) => s.isCurrent).toList();
    state = state.copyWith(sessions: next);
    await _storage.write(
      key: _sessionsKey,
      value: jsonEncode(next.map((s) => s.toJson()).toList()),
    );
  }
}

final securityProvider =
    StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  return SecurityNotifier(ref.read(secureStorageProvider));
});
