import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart' show shellNavigatorKey;
import '../../../core/widgets/gp_tab_bar.dart';
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <String>['home', 'explore', 'scan', 'profile'];

  static String _currentKey(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    // `/explore` is the map view (formerly `/gyms` list). The
    // `/gyms/<slug>` profile route is *not* part of the explore tab —
    // it pushes on top of any tab — so we don't match the prefix
    // here. Members landing on a profile page see the tab they came
    // from highlighted, not Explore.
    if (location.startsWith('/explore')) return 'explore';
    if (location.startsWith('/profile')) return 'profile';
    if (location.startsWith('/checkin')) return 'scan';
    return 'home';
  }

  static String _routeFor(String key) {
    switch (key) {
      case 'explore':
        return '/explore';
      case 'scan':
        return '/checkin';
      case 'profile':
        return '/profile';
      case 'home':
      default:
        return '/home';
    }
  }

  /// Moves one tab forward (+1) or backward (-1). Exposed so individual
  /// shell pages can claim the horizontal-drag arena inside regions where
  /// a platform view (e.g. MobileScanner's camera preview on CheckinPage)
  /// would otherwise swallow the gesture before it bubbles up here.
  static void swipeToAdjacentTab(BuildContext context, int direction) {
    final current = _currentKey(context);
    final idx = _tabs.indexOf(current);
    if (idx == -1) return;
    final target = idx + direction;
    if (target < 0 || target >= _tabs.length) return;
    // Belt-and-suspenders: if anything else triggers a swipe (deep
    // link, programmatic), close any popup first so it doesn't leak
    // onto the next tab. The primary guard is in
    // `handleHorizontalDragEndVelocity` below.
    _dismissOpenPopups(context);
    context.go(_routeFor(_tabs[target]));
  }

  /// True when a modal popup (e.g. filters sheet, dialog) is sitting
  /// on top of the current tab page. Used to suppress tab-swipe —
  /// when the member is interacting with a popup, a horizontal drag
  /// should be theirs to dismiss the sheet (or pan a child scroller),
  /// not the shell's to swap tabs.
  static bool _hasPopupOnTop() {
    final navState = shellNavigatorKey.currentState;
    if (navState == null) return false;
    var found = false;
    // `popUntil` walks the stack top-down. Returning `true` short-
    // circuits without popping, so we use it as a read-only inspect.
    navState.popUntil((route) {
      if (route is PopupRoute) found = true;
      return true;
    });
    return found;
  }

  /// Interprets a horizontal-drag primary velocity in the caller's locale
  /// and navigates to the adjacent tab. Centralized here so the shell and
  /// individual pages apply the exact same threshold + RTL handling.
  ///
  /// Suppressed when a modal popup (filters sheet, dialog) sits on top
  /// of the current tab — see [_hasPopupOnTop].
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: GestureDetector(
        // HorizontalDragEnd fires only when no child (e.g. a horizontally
        // scrollable ListView) claimed the gesture via the arena — so this
        // won't interfere with inner horizontal scrollers.
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          handleHorizontalDragEndVelocity(
            context,
            ref,
            details.primaryVelocity ?? 0,
          );
        },
        child: child,
      ),
      // Bottom nav is locked to LTR in every locale — the tab order
      // (home · gyms · scan · profile) is a fixed product shape, not
      // directional content. Mirroring it in Arabic made the familiar
      // layout feel upside-down without adding any reading benefit.
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.ltr,
        child: GpTabBar(
          active: _currentKey(context),
          onTab: (k) {
            // Dismiss any open modal popup (gym profile sheet, filters
            // sheet, dialog) BEFORE the tab swap. go_router's shell
            // navigator doesn't know about PopupRoutes, so without this
            // a sheet would keep painting over the new tab's content.
            // PageRoutes (e.g. /gyms/<slug> pushed on top of explore)
            // are left alone — go_router's own pop handles those.
            _dismissOpenPopups(context);
            switch (k) {
              case 'home':
                context.go('/home');
                break;
              case 'explore':
                context.go('/explore');
                break;
              case 'profile':
                context.go('/profile');
                break;
            }
          },
          onScan: () {
            _dismissOpenPopups(context);
            context.go('/checkin');
          },
        ),
      ),
    );
  }
}

/// Pop every `PopupRoute` (modal bottom sheets, dialogs, route-level
/// menus) on the shell's navigator stack while leaving `PageRoute`s
/// untouched — those are owned by go_router and the tab swap will
/// replace them automatically.
///
/// Why this lives here: the bottom-nav handler is the single point
/// where every cross-tab navigation happens, so wiring the dismiss
/// here covers gym profile sheets opened from /explore, the filters
/// sheet, and any future bottom-sheet without each caller having to
/// know about it.
///
/// Uses [shellNavigatorKey] rather than `Navigator.of(context)` —
/// HomeShell sits *above* the shell's navigator in the widget tree
/// (it's built by ShellRoute and wraps the child navigator), so a
/// context lookup from here resolves to the root navigator, not the
/// shell's. Modals pushed from /explore live one level deeper, so a
/// root-level popUntil never sees them.
void _dismissOpenPopups(BuildContext context) {
  final shellNav = shellNavigatorKey.currentState;
  if (shellNav != null) {
    shellNav.popUntil((route) => route is! PopupRoute);
  }
}
