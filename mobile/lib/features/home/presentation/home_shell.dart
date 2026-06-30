import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/connectivity_banner.dart';
import '../../../core/router/app_router.dart' show branchNavigatorKeys;
import '../../../core/widgets/gp_tab_bar.dart';
import '../../checkin/presentation/checkin_controller.dart'
    show checkinReturnRouteProvider;

/// Bottom-nav scaffold for the four tab branches.
///
/// ## Swipe-to-navigate
///
/// Tab switching uses a [GestureDetector] with [onHorizontalDragEnd], NOT
/// a raw [Listener]. This is intentional: by participating in the gesture
/// arena the detector naturally loses to any child widget that claims a
/// horizontal drag (Sliders, flutter_map, horizontal ListViews, etc.) so
/// those widgets always work correctly. Only free-area swipes with no
/// competing child reach the tab-switch handler.
///
/// The camera preview on CheckinPage is a native AndroidView and is handled
/// separately via [handleHorizontalDragEndVelocity].
///
/// The bottom nav bar has its own [GestureDetector] so swipes that START on
/// the tab bar also switch tabs.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const int _homeIndex = 0;
  static const int _exploreIndex = 1;
  static const int _scanIndex = 2;
  static const int _profileIndex = 3;

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

  // Debounce shared across all call sites (body drag + nav bar drag + CheckinPage).
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

  static bool _hasPopupOnTop() {
    for (final key in branchNavigatorKeys) {
      final navState = key.currentState;
      if (navState == null) continue;
      var found = false;
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
  /// Velocity threshold (logical px/s) for a swipe to trigger a tab switch.
  /// High enough to ignore accidental micro-swipes on content areas.
  static const double _velocityThreshold = 350;

  void _onHorizontalDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity;
    if (v == null || v.abs() < _velocityThreshold) return;
    if (HomeShell._hasPopupOnTop()) return;

    // right-swipe (v > 0) → go to previous tab (–1) in LTR;
    // flipped in RTL because "right" means previous logical item.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final direction = isRtl ? (v > 0 ? 1 : -1) : (v > 0 ? -1 : 1);

    final target = widget.navigationShell.currentIndex + direction;
    if (target < 0 || target >= 4) return;

    final now = DateTime.now();
    if (HomeShell._lastSwitchAt != null &&
        now.difference(HomeShell._lastSwitchAt!) <
            const Duration(milliseconds: 500)) {
      return;
    }

    _dismissOpenPopups();
    HomeShell._lastSwitchAt = now;

    if (target == HomeShell._scanIndex) {
      ref.read(checkinReturnRouteProvider.notifier).state = null;
    }
    widget.navigationShell.goBranch(target);
  }

  void _switchTo(int branchIndex) {
    _dismissOpenPopups();
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
          // GestureDetector participates in the arena → child widgets
          // (Slider, flutter_map, horizontal ListView) claim horizontal
          // drags before this fires, so they always work correctly.
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _onHorizontalDragEnd,
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
      // Bottom nav is locked to LTR — tab order is a fixed product shape.
      // Wrapped in its own GestureDetector so swipes that start on the tab
      // bar also trigger tab switching.
      bottomNavigationBar: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: GpTabBar(
            active: HomeShell._keyForBranch(navigationShell.currentIndex),
            onTab: (k) => _switchTo(HomeShell._branchIndexFor(k)),
            onScan: () => _switchTo(HomeShell._scanIndex),
          ),
        ),
      ),
    );
  }
}

void _dismissOpenPopups() {
  for (final key in branchNavigatorKeys) {
    final nav = key.currentState;
    if (nav != null) {
      nav.popUntil((route) => route is! PopupRoute);
    }
  }
}
