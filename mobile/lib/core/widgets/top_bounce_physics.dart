import 'package:flutter/material.dart';

/// Bouncing at the top edge (so pull-to-refresh feels native and the
/// dumbbell loader has the rubber-band gesture it expects), but
/// **clamping at the bottom** — overscrolling past the last row no
/// longer rebounds back. Members were mistaking the bottom rebound
/// for a refresh ("did the page just refresh? I only swiped up at
/// the bottom"); on a short page like Profile the bounce reads as a
/// fake transition. Clamping the bottom means the page just stops at
/// its last row, which is the unambiguous signal we want.
///
/// **Why both `applyBoundaryConditions` AND `createBallisticSimulation`
/// are overridden:** clamping the bottom in `applyBoundaryConditions`
/// alone wasn't enough. The inherited `BouncingScrollSimulation`
/// keeps a spring at *both* edges, so a hard upward fling at the
/// bottom would: hit max → spring rebound → high return velocity →
/// position oscillates past min → that registers as a top-edge
/// overscroll → `RefreshIndicator` arms → a real refresh fires that
/// the user never asked for. Building the ballistic with the trailing
/// extent pinned to the current position kills the bottom spring;
/// the leading (top) spring is preserved so a user-initiated pull
/// from the top still bounces back naturally after refresh.
///
/// Pair with [AlwaysScrollableScrollPhysics] on pages whose content
/// is shorter than the viewport — the parent ensures the gesture is
/// always available even when there's nothing to scroll, so the
/// pull-to-refresh trigger keeps working on a near-empty list.
///
/// Usage:
/// ```dart
/// ListView(
///   physics: const AlwaysScrollableScrollPhysics(
///     parent: TopBouncePhysics(),
///   ),
///   ...
/// )
/// ```
class TopBouncePhysics extends BouncingScrollPhysics {
  const TopBouncePhysics({super.parent});

  @override
  TopBouncePhysics applyTo(ScrollPhysics? ancestor) {
    return TopBouncePhysics(parent: buildParent(ancestor));
  }

  /// Block any pull *past* the bottom edge before it ever produces an
  /// overscroll (and an `OverscrollNotification`). The two `if`
  /// blocks below mirror the "value past max" branches from
  /// [ClampingScrollPhysics] verbatim, so the bottom edge feels
  /// exactly like the Android default — a hard stop at the last row.
  /// Top-edge cases fall through and inherit
  /// [BouncingScrollPhysics]'s permissive behaviour (return 0 → no
  /// clamp → bounce).
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (position.maxScrollExtent <= position.pixels && position.pixels < value) {
      return value - position.pixels;
    }
    if (position.maxScrollExtent < value && position.pixels < value) {
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }

  /// Build the post-fling simulation. The default
  /// [BouncingScrollPhysics] returns a [BouncingScrollSimulation]
  /// with springs at *both* edges; we need the bottom spring gone or
  /// a hard upward fling oscillates back through the top edge and
  /// triggers a phantom refresh.
  ///
  /// Strategy:
  ///   - **Already at or past the bottom max** — return null. There's
  ///     nothing to animate (we already clamped in
  ///     `applyBoundaryConditions`); a stale spring would only cause
  ///     the oscillation we're trying to kill.
  ///   - **Heading down with a positive velocity** — use
  ///     [ClampingScrollSimulation]. Friction-only; the position
  ///     stops at max with no spring back. No oscillation past min,
  ///     no phantom refresh.
  ///   - **At or past the top, or moving up** — fall through to the
  ///     inherited bouncing simulation so the pull-to-refresh
  ///     gesture and its rebound keep their iOS-feel.
  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);
    final atOrPastBottom = position.pixels >= position.maxScrollExtent;
    final headingDown = velocity > 0;

    if (atOrPastBottom && velocity.abs() < tolerance.velocity) {
      return null;
    }

    // Below-or-heading-toward-bottom path: no springs, just friction.
    // The condition `position.pixels >= position.minScrollExtent` keeps
    // us from stealing the top-pull rebound — when the user has
    // released a pull-to-refresh gesture the position is *negative*
    // (past min) and we want the springy return.
    if (position.pixels >= position.minScrollExtent && headingDown) {
      return ClampingScrollSimulation(
        position: position.pixels,
        velocity: velocity,
        tolerance: tolerance,
      );
    }

    return super.createBallisticSimulation(position, velocity);
  }
}
