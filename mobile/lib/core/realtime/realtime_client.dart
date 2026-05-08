import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/token_store.dart';
import '../config/env.dart';
import '../di/providers.dart';

/// Connect-once WebSocket client that maintains a live subscription
/// to a server-driven set of channels and emits decoded JSON events
/// for each. Implements:
///
/// - Auto-reconnect with exponential backoff (1s → 30s cap),
///   reset to 1s on a successful connect.
/// - Token-based auth via the existing access token (sent as the
///   first `auth` frame, matching `app/api/v1/realtime.py`).
/// - Per-channel re-subscribe on reconnect — the server forgets
///   our channel set when the socket dies, so we replay it.
/// - Idle ping every 25s so a stuck proxy / NAT mid-box doesn't
///   silently kill the connection.
///
/// The client deliberately does NOT do any state-management of its
/// own — callers (typically a `ref.listen` in a page) listen on
/// `events` and decide what to invalidate. Keeping the client
/// dumb keeps the failure surface small: if Riverpod crashes a
/// listener, the WS pump survives, and vice versa.
class RealtimeClient {
  RealtimeClient(this._tokens, this._env);

  final TokenStore _tokens;
  final AppEnv _env;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  /// Channels the caller wants subscribed. Read on every connect
  /// so a reconnect re-subscribes without the caller doing
  /// anything. Updated via [setChannels].
  final Set<String> _desired = <String>{};

  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();

  /// Decoded events from the server. One stream serves all
  /// listeners; multiple pages can subscribe without pumping
  /// duplicate connections.
  Stream<RealtimeEvent> get events => _events.stream;

  /// Replace the subscribed channel set. Triggers a re-subscribe
  /// on the live connection (or schedules one for the next
  /// connect). Idempotent — passing the same set twice is a no-op.
  void setChannels(Iterable<String> channels) {
    final next = channels.toSet();
    if (next.length == _desired.length && next.containsAll(_desired)) {
      return;
    }
    _desired
      ..clear()
      ..addAll(next);
    _sendSubscribe();
  }

  /// Open the connection (idempotent — calling twice is harmless).
  /// Most callers don't invoke this directly; the `realtimeClientProvider`
  /// kicks it off when the first subscriber registers.
  Future<void> start() async {
    if (_channel != null) return;
    await _connect();
  }

  Future<void> _connect() async {
    final token = await _tokens.readAccess();
    if (token == null || token.isEmpty) {
      // No session yet — bail. Caller will retry once the auth
      // controller mints a token (typically via [setChannels] or
      // [start] called from a route guard after sign-in).
      _scheduleReconnect();
      return;
    }
    final uri = _wsUriFromBase(_env.apiBaseUrl);
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _socketSub = channel.stream.listen(
        _onMessage,
        onError: (Object _) => _onClosed(),
        onDone: _onClosed,
        cancelOnError: false,
      );
      // Auth must be the first frame — server closes the socket
      // with 4401 if we send anything else.
      _send({'action': 'auth', 'token': token});
      // Subscribe to whatever the caller currently wants. The
      // server replies with `{"type":"subscribed", ...}` which we
      // ignore — events drive everything.
      _sendSubscribe();
      _startPing();
      _resetReconnectBackoff();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    if (data is! String) return;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) return;
      final map = decoded.cast<String, dynamic>();
      // Ignore handshake frames (`auth.ok`, `subscribed`, `pong`,
      // `error`). Real events always carry both `channel` and
      // `type`.
      final channel = map['channel'];
      final type = map['type'];
      if (channel is! String || type is! String) return;
      _events.add(RealtimeEvent(channel: channel, type: type, data: map));
    } catch (_) {
      // Malformed frame — drop silently rather than crash the
      // pump.
    }
  }

  void _onClosed() {
    _stopPing();
    _socketSub?.cancel();
    _socketSub = null;
    _channel = null;
    _scheduleReconnect();
  }

  void _send(Map<String, Object?> frame) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(frame));
    } catch (_) {
      // Sink may be closed mid-write; reconnect path handles it.
    }
  }

  void _sendSubscribe() {
    if (_channel == null) return;
    _send({'action': 'subscribe', 'channels': _desired.toList()});
  }

  // ---------- Reconnect backoff ----------

  static const _baseBackoff = Duration(seconds: 1);
  static const _maxBackoff = Duration(seconds: 30);
  Duration _nextBackoff = _baseBackoff;

  void _resetReconnectBackoff() {
    _nextBackoff = _baseBackoff;
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = _nextBackoff;
    _nextBackoff = Duration(
      milliseconds: (_nextBackoff.inMilliseconds * 2)
          .clamp(_baseBackoff.inMilliseconds, _maxBackoff.inMilliseconds),
    );
    _reconnectTimer = Timer(delay, () => unawaited(_connect()));
  }

  // ---------- Idle ping ----------

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_channel == null) return;
      _send({'action': 'ping'});
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Tear everything down. Called on logout (auth controller's
  /// clear-everything sweep) so the next session starts fresh.
  Future<void> dispose() async {
    _stopPing();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    await _events.close();
  }

  /// Convert the configured `apiBaseUrl` (`http://...` /
  /// `https://...`) into a WebSocket URL pointing at the realtime
  /// endpoint. Falls back to `ws://` on local dev where the API
  /// is plain HTTP.
  static Uri _wsUriFromBase(String apiBaseUrl) {
    final base = Uri.parse(apiBaseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      pathSegments: [...base.pathSegments, 'api', 'v1', 'realtime', 'ws']
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }
}

/// Shape of an event the server pushed onto a subscribed channel.
/// Type names mirror what `app/api/v1/realtime.py` accepts; data
/// carries the original payload (`gymId`, `slug`, etc.) so the
/// caller can route based on either type or per-field filters.
class RealtimeEvent {
  const RealtimeEvent({
    required this.channel,
    required this.type,
    required this.data,
  });

  final String channel;
  final String type;
  final Map<String, dynamic> data;
}

/// One client per app instance. Lives as long as the auth session
/// — `clear()` on logout closes it. Riverpod auto-disposes the
/// provider on app shutdown.
final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final client = RealtimeClient(
    ref.read(tokenStoreProvider),
    ref.read(envProvider),
  );
  // Open as soon as anyone touches the provider — the client is
  // idle (no event traffic) until [setChannels] is called, so
  // there's no cost to having it live across the whole session.
  unawaited(client.start());
  ref.onDispose(() => unawaited(client.dispose()));
  return client;
});
