import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/connectivity_banner.dart';
import '../../../core/router/app_router.dart' show branchNavigatorKeys;
import '../../../core/widgets/gp_tab_bar.dart';
import '../../checkin/presentation/checkin_controller.dart'
    show checkinReturnRouteProvider;

/// Bottom-nav scaffold for the four tab branches. Receives a
/// [StatefulNavigationShell] from `StatefulShellRoute.indexedStack` —
/// the shell IS the body widget (it renders an `IndexedStack` of all
/// branch navigators internally), so each tab keeps its State alive
/// when the member switches tabs. That preserves:
///
///   - the QR scanner's Camera2 + MLKit barcode + TFLite XNNPACK
///     state (re-init takes ~200 ms + ~3 MB GC churn each time);
///   - the explore-map's camera position, tile cache, and selected
///     pin;
///   - per-tab scroll offsets.
///
/// Pages that are inside the shell but visibility-sensitive (camera
/// preview, GPS) should still pause work when their branch isn't
/// active — the State is alive but the user isn't looking at it. See
/// `CheckinPage` for the visibility-driven start/stop hookup.
///
/// ## Swipe-to-navigate
///
/// Tab switching on horizontal swipe is handled by a [Listener] in
/// [_HomeShellState], not a GestureDetector. A Listener receives raw
/// pointer events outside the gesture arena, so it fires regardless of
/// whether an inner widget (flutter_map, horizontal ListView, etc.) has
/// claimed the gesture. The trade-off: the Listener is not aware of
/// gesture cancellations, so it applies displacement + angle thresholds
/// instead of velocity:
///
///   • horizontal displacement ≥ 70 px
///   • total vertical drift < total horizontal drift × 0.7
///     (catches diagonal map pans and rejects them)
///
/// The camera preview on CheckinPage is a native AndroidView that
/// consumes touches before Flutter's pointer routing sees them, so the
/// Listener never fires there. [CheckinPage] keeps its own
/// [Positioned.fill] overlay to claim horizontal drags above the native
/// surface and routes them via [handleHorizontalDragEndVelocity].
/// A 500 ms debounce on [swipeToAdjacentTab] prevents double-fire on
/// the (unlikely) case where both paths fire for the same gesture.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Branch indexes in tab order. Mirrors the order in
  /// `appRouterProvider`'s `StatefulShellRoute.branches` list.
  static const int _homeIndex = 0;
  static const int _exploreIndex = 1;
  static const int _scanIndex = 2;
  static const int _profileIndex = 3;

  /// Tab-key to branch-index mapping. Kept in one place so the bottom
  /// bar callbacks and the swipe handler agree.
  static int _branchIndexFor(String key) {
    switch (key) {
      case 'explore':
        return _exploreIndex;
      case 'scan':
        return _scanIndex;
      case 'profile':
        return _profileIndex;
      case 'home':
      default:
        return _homeIndex;
    }
  }

  static String _keyForBranch(int idx) {
    switch (idx) {
      case _exploreIndex:
        return 'explore';
      case _scanIndex:
        return 'scan';
      case _profileIndex:
        return 'profile';
      case _homeIndex:
      default:
        return 'home';
    }
  }

  // Debounce timestamp — shared across all call sites (Listener +
  // CheckinPage) so a double-fire within the same gesture is dropped.
  static DateTime? _lastSwitchAt;

  /// Moves one tab forward (+1) or backward (-1). Exposed so
  /// CheckinPage can route swipes that originate above the camera
  /// native surface directly to the shell.
  static void swipeToAdjacentTab(BuildContext context, int direction) {
    final now = DateTime.now();
    if (_lastSwitchAt != null &&
        now.difference(_lastSwitchAt!) < const Duration(milliseconds: 500)) {
      return;
    }
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell == null) return;
    final target = shell.currentIndex + direction;
    if (target < 0 || target >= 4) return;
    _dismissOpenPopups();
    _lastSwitchAt = now;
    shell.goBranch(target);
  }

  /// True when a modal popup (e.g. filters sheet, dialog) is sitting
  /// on top of any branch — used to suppress tab-swipe so the
  /// gesture is the user's to dismiss the sheet, not the shell's
  /// to swap tabs.
  static bool _hasPopupOnTop() {
    for (final key in branchNavigatorKeys) {
      final navState = key.currentState;
      if (navState == null) continue;
      var found = false;
      // popUntil walks top-down. Returning `true` short-circuits
      // without popping anything; we use it as a read-only inspect.
      navState.popUntil((route) {
        if (route is PopupRoute) found = true;
        return true;
      });
      if (found) return true;
    }
    return false;
  }

  /// Velocity-based variant used by CheckinPage's camera overlay.
  static void handleHorizontalDragEndVelocity(
    BuildContext context,
    WidgetRef ref,
    double velocity,
  ) {
    if (velocity.abs() < 260) return;
    if (_hasPopupOnTop()) return;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final goPrev = isRtl ? velocity < 0 : velocity > 0;
    swipeToAdjacentTab(context, goPrev ? -1 : 1);
  }

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // Raw pointer tracking for Listener-based swipe detection.
  Offset? _dragStart;
  Offset? _prevPos;
  double _totalDxAbs = 0;
  double _totalDyAbs = 0;

  void _onPointerDown(PointerDownEvent e) {
    _dragStart = e.localPosition;
    _prevPos = e.localPosition;
    _totalDxAbs = 0;
    _totalDyAbs = 0;
  }

  void _onPointerMove(PointerMoveEvent e) {
    final prev = _prevPos;
    if (prev == null) return;
    final delta = e.localPosition - prev;
    _totalDxAbs += delta.dx.abs();
    _totalDyAbs += delta.dy.abs();
    _prevPos = e.localPosition;
  }

  void _onPointerUp(PointerUpEvent e) {
    final start = _dragStart;
    if (start == null) return;
    final cumulativeDx = e.localPosition.dx - start.dx;

    // Require at least 70 px of net horizontal travel.
    if (cumulativeDx.abs() < 70) return;

    // Reject diagonal gestures (e.g. map panning).
    // Total vertical drift must be less than 70 % of total horizontal.
    if (_totalDyAbs > _totalDxAbs * 0.7) return;

    if (HomeShell._hasPopupOnTop()) return;

    // Debounce: skip if a tab switch just happened (e.g. CheckinPage
    // overlay also fired for the same gesture).
    final now = DateTime.now();
    if (HomeShell._lastSwitchAt != null &&
        now.difference(HomeShell._lastSwitchAt!) <
            const Duration(milliseconds: 500)) {
      return;
    }

    // right-drag (dx > 0) → go to previous tab (–1).
    // left-drag  (dx < 0) → go to next tab     (+1).
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final direction = isRtl
        ? (cumulativeDx > 0 ? 1 : -1)
        : (cumulativeDx > 0 ? -1 : 1);

    // NOTE: Do NOT use StatefulNavigationShell.maybeOf(context) here.
    // maybeOf() searches ancestors; the shell is a *descendant* of this
    // state's build context, so it returns null. Use widget.navigationShell
    // directly (the field is the actual shell instance).
    final target = widget.navigationShell.currentIndex + direction;
    if (target < 0 || target >= 4) return;

    _dismissOpenPopups();
    HomeShell._lastSwitchAt = now;

    // Swiping directly to the scan tab clears any pending return route
    // so the scanner doesn't show a stale "go back" affordance.
    if (target == HomeShell._scanIndex) {
      ref.read(checkinReturnRouteProvider.notifier).state = null;
    }

    widget.navigationShell.goBranch(target);
  }

  void _switchTo(int branchIndex) {
    _dismissOpenPopups();
    // When the user taps the scan tab from the bottom bar, clear any pending
    // return route so the scanner doesn't show a stale "go back" button.
    if (branchIndex == HomeShell._scanIndex) {
      ref.read(checkinReturnRouteProvider.notifier).state = null;
    }
    widget.navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    return Scaffold(
      body: Stack(
        children: [
          // Listener receives raw pointer events outside the gesture
          // arena — fires even when an inner widget (map, PageView)
          // claims the gesture. See class doc for threshold rationale.
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            child: navigationShell,
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ConnectivityBanner(),
          ),
        ],
      ),
      // Bottom nav is locked to LTR in every locale — the tab order
      // (home · gyms · scan · profile) is a fixed product shape,
      // not directional content.
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.ltr,
        child: GpTabBar(
          active: HomeShell._keyForBranch(navigationShell.currentIndex),
          onTab: (k) => _switchTo(HomeShell._branchIndexFor(k)),
          onScan: () => _switchTo(HomeShell._scanIndex),
        ),
      ),
    );
  }
}

/// Pop every `PopupRoute` (modal bottom sheets, dialogs, route-level
/// menus) on every branch navigator. PageRoutes (e.g. /gyms/<slug>
/// pushed on top of explore) are left alone — those are owned by
/// go_router and survive tab swaps as expected.
void _dismissOpenPopups() {
  for (final key in branchNavigatorKeys) {
    final nav = key.currentState;
    if (nav != null) {
      nav.popUntil((route) => route is! PopupRoute);
    }
  }
}
