import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coarse network state. We deliberately don't expose the wire-level
/// `ConnectivityResult` (wifi / mobile / ethernet / etc.) — the app
/// only ever needs to know whether the next HTTP call has a chance
/// of succeeding. Mobile-data, WiFi, Ethernet are all "online" from
/// the app's perspective; the actual reachability of `api.gym-pass.net`
/// is decided by the HTTP layer when it tries.
enum NetworkStatus {
  /// The OS reports at least one connected interface. The next HTTP
  /// request will attempt the network. UI hides any offline banner.
  online,

  /// The OS reports no interfaces. We can short-circuit network calls
  /// and surface "you're offline" cards, the cached list, and a
  /// retry-on-reconnect.
  offline,

  /// We haven't asked yet (first frame of cold start). Treat as
  /// online optimistically — if a request fires while we're in this
  /// state and fails, the failure handler will reconcile.
  unknown,
}

/// Live network status. Listens to the OS's connectivity stream and
/// folds the granular `ConnectivityResult` into [NetworkStatus]. On
/// startup we kick off `Connectivity().checkConnectivity()` once so
/// the initial state isn't stuck on [NetworkStatus.unknown] longer
/// than the platform channel round trip (~100 ms).
///
/// Riverpod owns the subscription lifecycle — `ref.onDispose` tears
/// down the stream subscription when the provider is auto-disposed
/// (it isn't, in normal app use, but tests benefit).
final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, NetworkStatus>((ref) {
  final notifier = ConnectivityNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

class ConnectivityNotifier extends StateNotifier<NetworkStatus> {
  ConnectivityNotifier({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity(),
        super(NetworkStatus.unknown) {
    _bootstrap();
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> _bootstrap() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _apply(results);
    } catch (_) {
      // Platform channel hiccup — leave at `unknown` so we don't
      // falsely declare offline on startup; the stream listener
      // below will reconcile on the first event.
    }
    _sub = _connectivity.onConnectivityChanged.listen(
      _apply,
      onError: (Object _) {
        // Stream errors are uncommon; swallow so the listener keeps
        // delivering subsequent events.
      },
    );
  }

  void _apply(List<ConnectivityResult> results) {
    final hasInterface = results.any((r) => r != ConnectivityResult.none);
    final next = hasInterface ? NetworkStatus.online : NetworkStatus.offline;
    if (next != state) state = next;
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    super.dispose();
  }
}

/// Convenience selector: true when we should treat the device as
/// online for the purposes of skipping cache / showing fresh
/// content. `unknown` counts as online so first-frame requests
/// still attempt the network.
bool isOnline(NetworkStatus status) =>
    status == NetworkStatus.online || status == NetworkStatus.unknown;
