import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/connectivity_banner.dart';
import '../../../core/router/app_router.dart' show branchNavigatorKeys;
import '../../../core/widgets/gp_tab_bar.dart';

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
class HomeShell extends ConsumerWidget {
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

  /// Moves one tab forward (+1) or backward (-1). Exposed so
  /// individual shell pages (notably CheckinPage, where the
  /// MobileScanner camera preview otherwise swallows horizontal
  /// drags before the shell sees them) can claim the gesture and
  /// route the swipe back through here for consistent thresholding.
  static void swipeToAdjacentTab(BuildContext context, int direction) {
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell == null) return;
    final target = shell.currentIndex + direction;
    if (target < 0 || target >= 4) return;
    _dismissOpenPopups();
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

  /// Interprets a horizontal-drag primary velocity and navigates to
  /// the adjacent tab. Suppressed when a modal popup is open (the
  /// drag belongs to the popup, not the shell).
  static void handleHorizontalDragEndVelocity(
    BuildContext context,
    WidgetRef ref,
    double velocity,
  ) {
    if (velocity.abs() < 260) return;
    if (_hasPopupOnTop()) return;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    // velocity > 0 = drag moved rightward. In LTR that's a back-swipe → prev.
    // Flip for RTL so the gesture mirrors the visual tab order.
    final goPrev = isRtl ? velocity < 0 : velocity > 0;
    swipeToAdjacentTab(context, goPrev ? -1 : 1);
  }

  void _switchTo(int branchIndex) {
    _dismissOpenPopups();
    // `initialLocation: true` resets the branch to its root route
    // when re-tapping the active tab — matches the iOS bottom-bar
    // convention where re-tapping pops a tab to its base. For
    // *different* tab indexes it's a no-op; the branch already
    // shows whatever route it last had.
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Connectivity banner floats *over* the navigation stack so it
    // never reserves space when online. Earlier we wrapped it in a
    // SafeArea + Column row, which permanently claimed the top
    // safe-area inset (~50 px on most phones) — every tab rendered
    // with a phantom band between status bar and content. The banner
    // is now Positioned above the stack and only consumes pixels
    // when ConnectivityBanner returns its non-zero state; when
    // online, its `SizedBox.shrink()` paints nothing and the page
    // below paints right up to the status bar like before.
    //
    // Banner is responsible for its own SafeArea internally — it
    // adds the top inset only when it's actually rendering content.
    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            // HorizontalDragEnd fires only when no child claimed the
            // gesture via the arena, so this won't interfere with inner
            // horizontal scrollers.
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              handleHorizontalDragEndVelocity(
                context,
                ref,
                details.primaryVelocity ?? 0,
              );
            },
            // The `StatefulNavigationShell` widget renders the
            // IndexedStack of branch navigators directly, so it IS
            // our body — no `child` indirection.
            child: navigationShell,
          ),
          // Floating overlay — only takes layout space when offline.
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
      // not directional content. Mirroring it in Arabic made the
      // familiar layout feel upside-down without adding any
      // reading benefit.
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.ltr,
        child: GpTabBar(
          active: _keyForBranch(navigationShell.currentIndex),
          onTab: (k) => _switchTo(_branchIndexFor(k)),
          onScan: () => _switchTo(_scanIndex),
        ),
      ),
    );
  }
}

/// Pop every `PopupRoute` (modal bottom sheets, dialogs, route-level
/// menus) on every branch navigator. PageRoutes (e.g. /gyms/<slug>
/// pushed on top of explore) are left alone — those are owned by
/// go_router and survive tab swaps as expected.
///
/// Walks all four branch keys because, with `IndexedStack`, a sheet
/// pushed on /explore stays alive while the user is on /home (the
/// /explore branch is just hidden, not torn down). When the user
/// swaps back to /explore the sheet would still be there. The
/// bottom-nav handler runs this on every tap so any tab swap leaves
/// the shell sheet-free.
void _dismissOpenPopups() {
  for (final key in branchNavigatorKeys) {
    final nav = key.currentState;
    if (nav != null) {
      nav.popUntil((route) => route is! PopupRoute);
    }
  }
}
