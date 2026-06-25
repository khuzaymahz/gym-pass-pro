import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/realtime/realtime_client.dart';
import '../../data/gym_photos_repository.dart';
import '../../data/gym_repository.dart';

/// Subscribes the realtime client to this gym's channels for the
/// lifetime of the detail page, then invalidates the relevant
/// Riverpod providers each time the server pushes a matching event.
/// Result: a partner saving a profile / logo / photo change is
/// reflected on this page within a frame, no pull-to-refresh needed.
///
/// Stays a thin wrapper rather than refactoring the whole detail
/// page to ConsumerStatefulWidget — minimal blast radius, the
/// build tree above is unchanged.
class RealtimeBridge extends ConsumerStatefulWidget {
  const RealtimeBridge({
    super.key,
    required this.slug,
    required this.gymId,
    required this.child,
  });

  final String slug;

  /// Backend gym UUID. Null while `gymBySlugProvider` is still
  /// hydrating — the bridge defers subscribing until we know it,
  /// since the channel name is `gym/<id>`.
  final String? gymId;
  final Widget child;

  @override
  ConsumerState<RealtimeBridge> createState() => _RealtimeBridgeState();
}

class _RealtimeBridgeState extends ConsumerState<RealtimeBridge> {
  StreamSubscription<RealtimeEvent>? _sub;
  String? _activeGymId;
  // Cache the client at initState so dispose() doesn't have to touch
  // `ref` — Riverpod throws "Cannot use ref after the widget was
  // disposed" if a late-arriving stream event or our own dispose()
  // accesses ref after super.dispose has run. Holding the client
  // directly sidesteps that whole class of races.
  RealtimeClient? _client;

  @override
  void initState() {
    super.initState();
    _client = ref.read(realtimeClientProvider);
    _refreshSubscription();
  }

  @override
  void didUpdateWidget(covariant RealtimeBridge old) {
    super.didUpdateWidget(old);
    if (old.gymId != widget.gymId) {
      _refreshSubscription();
    }
  }

  void _refreshSubscription() {
    final id = widget.gymId;
    if (id == _activeGymId) return;
    _activeGymId = id;
    _sub?.cancel();
    _sub = null;
    if (id == null) return;

    final client = _client;
    if (client == null) return;
    client.setChannels(['gym/$id', 'gym/$id/photos']);
    _sub = client.events.listen((event) {
      // Stream events can land mid-teardown — the subscription
      // cancel is async, so an event already in flight will still
      // fire its listener. Without the `mounted` guard we'd hit
      // "Cannot use ref after the widget was disposed" the moment
      // a partner edited their gym while a member was navigating
      // away. Cheap check, eliminates the race entirely.
      if (!mounted) return;
      if (!event.channel.startsWith('gym/$id')) return;
      // Any of the published gym events (`gym.updated`,
      // `gym.logo.set`, `gym.logo.cleared`, `gym.photo.added`,
      // `gym.photo.removed`) means at least one of these two
      // providers is now stale — re-fetch them. Riverpod's
      // invalidate is cheap (just clears the cached value); the
      // page will rebuild and the page already handles the
      // "loading" branch.
      ref.invalidate(gymBySlugProvider(widget.slug));
      ref.invalidate(gymPhotosProvider(widget.slug));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    // Use the cached client instead of ref — see the field comment.
    // Keep the realtimeClient alive (other pages might subscribe
    // next), but clear its channel set so we're not paying for an
    // event stream we no longer consume.
    _client?.setChannels(const []);
    _client = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
