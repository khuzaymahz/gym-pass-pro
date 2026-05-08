import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/gp_tokens.dart';
import 'gym_loader.dart';

/// Pull-to-refresh wrapper that swaps the platform spinner for a
/// gym-themed dumbbell.
///
/// **Why this hybrid**: Flutter's [RefreshIndicator] has rock-solid
/// gesture mechanics (works on every scroll physics, manages the
/// held-open gap, handles the close animation) but its visible
/// indicator is a hardcoded circular spinner with no slot for a
/// custom shape. Hand-rolling the gestures broke on certain scroll
/// views (overscroll notifications didn't fire reliably) and you
/// saw nothing on pull. So:
///
///   - **Mechanics** — `RefreshIndicator` handles them. Its
///     spinner is rendered with transparent foreground and
///     background so the platform widget is functionally there
///     but visually invisible.
///   - **Visuals** — a custom dumbbell overlay at the same screen
///     position the spinner would occupy. Position tracks the
///     pull progress (read by a peer NotificationListener) and
///     the refresh state (set by the onRefresh wrapper).
///
/// Net effect: pull-to-refresh feels and acts like the platform's,
/// but the indicator that appears in the held-open gap is an
/// amber dumbbell lifting in place.
class WordmarkRefresh extends StatefulWidget {
  const WordmarkRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.topOffset,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// Distance from the top of this widget down to where the indicator
  /// settles when armed. Defaults to the OS safe-area inset + 56 to
  /// clear typical floating header rows.
  final double? topOffset;

  /// Minimum time the indicator stays visible. Refreshes that resolve
  /// faster than this still show the indicator long enough for the
  /// human eye to register the state change. Tuned to 220 ms — the
  /// usual perception threshold for a "yes, something happened"
  /// signal — instead of the previous 800 ms which left users on
  /// fast networks staring at skeletons for ~3/4 s after the data
  /// was already in. Anything below ~150 ms reads as a one-frame
  /// flash and members report "the gesture didn't work".
  static const Duration minActiveDisplay = Duration(milliseconds: 220);

  @override
  State<WordmarkRefresh> createState() => _WordmarkRefreshState();
}

class _WordmarkRefreshState extends State<WordmarkRefresh>
    with SingleTickerProviderStateMixin {
  /// Distance the user has to pull past the natural scroll edge before
  /// the platform's RefreshIndicator arms a refresh.
  static const double _triggerExtent = 70;

  /// Cap on how far the dumbbell visual ramps.
  static const double _maxIndicatorExtent = 110;

  double _pullExtent = 0;
  bool _refreshing = false;

  /// Highest top-pull extent the user reached during the most recent
  /// gesture, in the same logical pixels as `_pullExtent`. Reset to 0
  /// at the start of every new scroll gesture and read by
  /// `_wrappedOnRefresh` as a hard gate against phantom refreshes —
  /// `RefreshIndicator` can arm from oscillating ballistics or
  /// edge-case notifications even when the user never actually pulled
  /// down at the top, so we double-gate on this peak. Refresh runs
  /// only when the peak exceeds `_triggerExtent`, mirroring the same
  /// threshold the platform indicator uses for its dumbbell arming.
  double _peakPullThisGesture = 0;

  /// Drives the post-refresh "completion spin → fade out" sequence.
  /// Runs from 0 to 1 after the refresh future resolves:
  ///   - 0.0 → 0.55  → quick 360° rotation (the "rep complete" spin)
  ///   - 0.55 → 1.0 → opacity fade + slide-down (graceful exit)
  /// While this controller is animating, the platform's
  /// RefreshIndicator is still held open (we haven't returned from
  /// `_wrappedOnRefresh` yet), so the dumbbell finishes its motion
  /// inside the gap before the page slides closed.
  late final AnimationController _completion;
  // Was 520 ms — felt like the page was holding its breath after the
  // data already arrived. 180 ms is enough for the dumbbell's
  // "rep complete" beat to read without padding the perceived
  // refresh time.
  static const Duration _completionDuration = Duration(milliseconds: 180);

  @override
  void initState() {
    super.initState();
    _completion = AnimationController(
      vsync: this,
      duration: _completionDuration,
    );
  }

  @override
  void dispose() {
    _completion.dispose();
    super.dispose();
  }

  bool _onNotification(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (_refreshing) return false;

    if (n is ScrollStartNotification) {
      // New gesture — clear the peak so the next refresh-gate read
      // reflects only what the user does in this gesture, not stale
      // state from an earlier flick.
      _peakPullThisGesture = 0;
    } else if (n is OverscrollNotification && n.overscroll < 0) {
      final next =
          (_pullExtent - n.overscroll).clamp(0.0, _maxIndicatorExtent);
      if (next != _pullExtent) {
        setState(() => _pullExtent = next.toDouble());
      }
      if (next > _peakPullThisGesture) _peakPullThisGesture = next;
    } else if (n is ScrollUpdateNotification && n.metrics.pixels < 0) {
      final next = (-n.metrics.pixels).clamp(0.0, _maxIndicatorExtent);
      if (next != _pullExtent) {
        setState(() => _pullExtent = next.toDouble());
      }
      if (next > _peakPullThisGesture) _peakPullThisGesture = next;
    } else if (n is ScrollEndNotification && _pullExtent != 0) {
      // RefreshIndicator owns the trigger; if it fires, _refreshing
      // will flip true via the wrapped onRefresh callback. Either
      // way, reset the pull extent on release.
      setState(() => _pullExtent = 0);
    }
    return false;
  }

  /// Hard ceiling on how long the refresh can run before we force-
  /// close the indicator. Prevents the dumbbell from getting stuck
  /// visible if the page's `onRefresh` future never resolves (a
  /// pending HTTP call that hangs, an awaited stream that never
  /// emits, etc). 8 s is generous for any sane network call but
  /// short enough that a stuck indicator never becomes a permanent
  /// piece of the UI.
  static const Duration _refreshHardTimeout = Duration(seconds: 8);

  Future<void> _wrappedOnRefresh() async {
    // Hard gate against phantom refreshes. The platform
    // `RefreshIndicator` can arm from oscillating ballistics, transient
    // negative-pixel ticks during fast flings, and other edge cases
    // we don't always intercept upstream. Members were seeing the
    // gray skeleton state pop in after a hard upward flick at the
    // bottom — the simulation briefly registered as a top overscroll
    // and armed the indicator. The custom `_peakPullThisGesture`
    // tracker only grows from genuine top overscroll, so requiring it
    // to exceed `_triggerExtent` here is a second, deliberate check
    // that the user actually pulled the page down. If the gate
    // rejects, we resolve immediately so the indicator closes its
    // gap and no skeleton state ever flips on.
    if (_peakPullThisGesture < _triggerExtent) {
      return;
    }
    setState(() {
      _refreshing = true;
    });
    _completion.value = 0;
    try {
      // Phase 1: actual refresh + minimum display window.
      await Future.wait([
        widget.onRefresh().timeout(
          _refreshHardTimeout,
          onTimeout: () {
            // Swallow — the indicator closes regardless.
          },
        ),
        Future<void>.delayed(WordmarkRefresh.minActiveDisplay),
      ]);
      if (!mounted) return;
      // Phase 2: completion spin + fade. Runs while the platform
      // RefreshIndicator is still held open — once we return from
      // this whole future, the platform closes its gap.
      await _completion.forward(from: 0);
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _pullExtent = 0;
        });
        _completion.value = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displacement = widget.topOffset ??
        MediaQuery.viewPaddingOf(context).top + 56;
    final progress =
        (_pullExtent / _triggerExtent).clamp(0.0, 1.0).toDouble();
    // Dumbbell shows ONLY during the pull gesture — once the
    // refresh actually fires, descendants take over by morphing
    // their cards into skeleton placeholders (via [RefreshScope]).
    // The skeletons are a clearer "we're working" signal than a
    // floating spinner: they stay where the real content sits, so
    // the page reads as "the data is loading" instead of "an
    // overlay has appeared on top of unchanged content."
    final showPullOverlay = _pullExtent > 0 && !_refreshing;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onNotification,
          child: RefreshIndicator(
            onRefresh: _wrappedOnRefresh,
            // Render the platform indicator transparently — its
            // mechanics (gesture, hold-open gap, close animation)
            // are what we want; its spinner is what we don't.
            color: Colors.transparent,
            backgroundColor: Colors.transparent,
            elevation: 0,
            strokeWidth: 0,
            displacement: displacement,
            notificationPredicate: (n) => n.depth == 0,
            // Publish the refreshing flag so descendants (cards,
            // rows, lists) can swap themselves for skeletons while
            // the fetch is in flight.
            child: RefreshScope(
              isRefreshing: _refreshing,
              child: widget.child,
            ),
          ),
        ),
        if (showPullOverlay)
          Positioned(
            top: displacement - 22,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _completion,
                  builder: (context, _) => _DumbbellLoader(
                    progress: progress,
                    active: false,
                    completion: 0,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Inherited "we're refreshing" flag. Descendants of [WordmarkRefresh]
/// can read this to swap their content for skeleton placeholders
/// while the refresh fetch is in flight, instead of showing the same
/// stale data under a spinner overlay.
///
/// Usage:
/// ```dart
/// final refreshing = RefreshScope.of(context);
/// return refreshing ? const SkeletonGymRow() : GymRow(gym: g);
/// ```
class RefreshScope extends InheritedWidget {
  const RefreshScope({
    super.key,
    required this.isRefreshing,
    required super.child,
  });

  final bool isRefreshing;

  /// Read the current refresh state. Returns false when no
  /// [RefreshScope] ancestor exists, which is the right default for
  /// pages outside any pull-to-refresh wrapper.
  static bool of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<RefreshScope>();
    return scope?.isRefreshing ?? false;
  }

  @override
  bool updateShouldNotify(RefreshScope old) =>
      old.isRefreshing != isRefreshing;
}

/// Dumbbell loader. Lifecycle, in order:
///
///   1. **Pulling** — opacity + scale + slide-up tracks `progress`.
///      Bar is *off-screen below* at progress=0 and at rest at
///      progress=1. Spin period eases from slow to fast.
///   2. **Refreshing** (`active == true`, `completion == 0`) — bar
///      lifts and lowers continuously at full energy.
///   3. **Completion spin** (`completion` 0 → ~0.55) — bar does a
///      quick 360° rotation. The "rep complete" gesture.
///   4. **Exit** (`completion` ~0.55 → 1) — opacity fades and bar
///      slides down + scales out.
class _DumbbellLoader extends StatefulWidget {
  const _DumbbellLoader({
    required this.progress,
    required this.active,
    required this.completion,
  });

  final double progress;
  final bool active;

  /// 0 → 1 across the post-refresh completion sequence. 0 means
  /// nothing happening yet; 1 means fully faded out.
  final double completion;

  @override
  State<_DumbbellLoader> createState() => _DumbbellLoaderState();
}

class _DumbbellLoaderState extends State<_DumbbellLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const Duration _fastPeriod = Duration(milliseconds: 950);
  static const Duration _slowPeriod = Duration(milliseconds: 2200);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _periodFor(widget.progress, widget.active),
    );
    _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _DumbbellLoader old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress || old.active != widget.active) {
      _ctrl.duration = _periodFor(widget.progress, widget.active);
      if (!_ctrl.isAnimating) _ctrl.repeat();
    }
  }

  Duration _periodFor(double progress, bool active) {
    if (active) return _fastPeriod;
    final t = progress.clamp(0.0, 1.0);
    final ms = _slowPeriod.inMilliseconds +
        ((_fastPeriod.inMilliseconds - _slowPeriod.inMilliseconds) * t)
            .round();
    return Duration(milliseconds: ms);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pullProgress = widget.progress.clamp(0.0, 1.0).toDouble();
    final completion = widget.completion.clamp(0.0, 1.0).toDouble();

    // Exit fade kicks in once the completion sequence starts —
    // fade out smoothly, no separate spin phase since the dumbbell
    // is already spinning continuously.
    final exitProgress = widget.active && completion > 0
        ? Curves.easeInCubic.transform(completion)
        : 0.0;

    final opacity = widget.active
        ? (1.0 - exitProgress)
        : pullProgress;

    return Opacity(
      opacity: opacity,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          // Continuous rotation around centre — spinning the whole
          // way through pull, refresh, and fade-out. The dumbbell's
          // asymmetric silhouette (long bar, plates at the ends)
          // makes every angle visibly different.
          final angle = _ctrl.value * math.pi * 2;
          return Transform.rotate(
            angle: angle,
            child: _DumbbellPainting(active: widget.active, repaint: _ctrl),
          );
        },
      ),
    );
  }
}

/// Thin wrapper around [GymLoaderPainter]. Same silhouette as the
/// public [GymLoader] used everywhere else — geometry lives in
/// [GymLoaderPainter]; this widget just sizes it for the refresh
/// indicator's slot.
class _DumbbellPainting extends StatelessWidget {
  const _DumbbellPainting({
    required this.active,
    this.repaint,
  });

  final bool active;
  final Listenable? repaint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 22,
      child: CustomPaint(
        painter: GymLoaderPainter(
          color: GP.lime,
          glow: active,
          repaint: repaint,
        ),
      ),
    );
  }
}
