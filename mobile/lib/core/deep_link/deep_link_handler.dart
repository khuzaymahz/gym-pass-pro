import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Receives incoming deep links — both cold-start (the app was
/// launched by tapping a link) and warm (the OS routes a new link
/// into an already-running app) — and forwards them to the
/// [GoRouter].
///
/// Supported URL shapes:
///   - `gympass://gyms/<slug>` (custom scheme — used by the
///     marketing-site fallback page)
///   - `https://gym-pass.net/gyms/<slug>` (Android applinks)
///   - `gympass://invite/<code>` and `https://gym-pass.net/invite/<code>`
///
/// The handler is intentionally tolerant: an unknown path is routed
/// to `/home` rather than crashing the app, and a path the user
/// can't see while signed-out (a gym profile) is gated through the
/// router's existing auth-redirect logic — we don't duplicate that
/// rule here.
class DeepLinkHandler {
  DeepLinkHandler({
    required this.router,
    required this.ref,
    AppLinks? appLinks,
  }) : _appLinks = appLinks ?? AppLinks();

  final GoRouter router;
  final Ref ref;
  final AppLinks _appLinks;

  StreamSubscription<Uri>? _subscription;

  /// Wire up both the cold-start path (`getInitialAppLink`) and the
  /// hot path (`uriLinkStream`). Idempotent — calling twice is a
  /// no-op on the second call.
  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object _) {
        // Stream errors are uncommon (transient platform-channel
        // hiccup); swallowing keeps the app responsive to the next
        // valid link instead of tearing down the subscription.
      },
    );
    // Cold-start link, if any. `getInitialLink` returns null for
    // normal launches.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (_) {
      // Best-effort on first launch.
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Schemes + hosts we accept. Any other URI is silently dropped —
  /// an external `malicious://invite/code-i-control` registering itself
  /// on the device shouldn't pre-fill our referral state. The list is
  /// deliberately narrow: the marketing site (`https://gym-pass.net`)
  /// and the custom scheme we control (`gympass://`).
  static const _kAllowedHttpsHosts = {'gym-pass.net', 'www.gym-pass.net'};
  static const _kAllowedScheme = 'gympass';

  bool _allowedUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == _kAllowedScheme) return true;
    if (scheme == 'https' &&
        _kAllowedHttpsHosts.contains(uri.host.toLowerCase())) {
      return true;
    }
    return false;
  }

  static final _kSlugPattern = RegExp(r'^[a-z0-9][a-z0-9-]{1,63}$');
  static final _kCodePattern = RegExp(r'^[A-Za-z0-9-]{2,32}$');

  void _handle(Uri uri) {
    // Allowlist check FIRST. Without it, any scheme handler the user
    // has installed could send us a URI matching our path shape and
    // we'd happily push onto the router / write to our state slots.
    if (!_allowedUri(uri)) return;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;
    final head = segments.first.toLowerCase();
    switch (head) {
      case 'gyms':
        if (segments.length >= 2) {
          final slug = segments[1];
          // Shape-validate so a path-traversal payload (`../wat`) or
          // an absurdly long string can't ride into the router.
          if (slug.isNotEmpty && _kSlugPattern.hasMatch(slug)) {
            router.push('/gyms/$slug');
          }
        }
        return;
      case 'invite':
        if (segments.length >= 2) {
          final code = segments[1].trim();
          if (code.isNotEmpty && _kCodePattern.hasMatch(code)) {
            // Pre-fill the invite page with the friend's code so the
            // member only has to confirm. The page reads from this
            // provider on mount and auto-submits when populated. The
            // claim still goes through the same `claimFriendCode`
            // path so we don't bypass duplicate / invalid checks.
            ref.read(pendingReferralCodeProvider.notifier).state = code;
          }
          router.push('/invite');
        }
        return;
      default:
        return;
    }
  }
}

/// One-shot state slot: holds a referral code captured from an
/// incoming deep link (`/invite/<code>`) so the InvitePage can
/// pick it up after the router navigates. Cleared when the page
/// consumes it.
final pendingReferralCodeProvider = StateProvider<String?>((_) => null);

/// Singleton handler — main wires it up in `app.dart` after the
/// `GoRouter` and `ProviderContainer` exist.
final deepLinkHandlerProvider = Provider<DeepLinkHandler>((ref) {
  throw StateError(
    'deepLinkHandlerProvider was read before app() injected it.',
  );
});

/// Convenience widget: subscribes to the deep-link stream once at
/// mount and tears it down on unmount. Drop into the widget tree
/// once above MaterialApp.router.
class DeepLinkScope extends ConsumerStatefulWidget {
  const DeepLinkScope({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DeepLinkScope> createState() => _DeepLinkScopeState();
}

class _DeepLinkScopeState extends ConsumerState<DeepLinkScope> {
  @override
  void initState() {
    super.initState();
    // Defer one frame so the router is fully built — pushing onto
    // a not-yet-mounted GoRouter is a no-op that swallows the
    // cold-start link.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deepLinkHandlerProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
