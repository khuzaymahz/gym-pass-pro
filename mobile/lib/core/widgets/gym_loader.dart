import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/gp_tokens.dart';

/// Brand-themed loading indicator — an amber dumbbell that lifts and
/// lowers continuously. Drop-in replacement for
/// [CircularProgressIndicator] anywhere a loading state needs to read
/// as "GymPass is working", not generic Material.
///
/// Use it for **any indeterminate wait**: weak-network API calls,
/// page initial-loads, button-press spinners, sheet-content fetches.
/// The pull-to-refresh wrapper [WordmarkRefresh] uses the same
/// painter under the hood, so the indicator the member sees mid-pull
/// matches the one inside a button mid-loading.
///
/// **Size**: defaults to a compact 44 × 30. Override via [size] for
/// a hero loading screen (e.g. `size: GymLoaderSize.large`).
class GymLoader extends StatefulWidget {
  const GymLoader({
    super.key,
    this.size = GymLoaderSize.regular,
    this.color,
  });

  final GymLoaderSize size;

  /// Defaults to the brand amber. Override for a tier-tinted loader
  /// (e.g. inside a Gold tier sheet).
  final Color? color;

  @override
  State<GymLoader> createState() => _GymLoaderState();
}

/// Predefined sizes. Smaller across the board than typical Material
/// spinners — the dumbbell's silhouette reads instantly even at
/// 24 px, and a smaller indicator feels less heavy on screens
/// where it's a temporary state.
enum GymLoaderSize {
  /// 24 × 16 — fits inside a button or compact pill.
  small,

  /// 32 × 22 — default. Inline with text content.
  regular,

  /// 48 × 32 — page-level loaders, empty-state cards.
  large,
}

class _GymLoaderState extends State<GymLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // ~1 lift cycle per second. Same period as the active state in
    // WordmarkRefresh so the visual rhythm is consistent across the
    // app — a member never wonders "is this loader the same brand
    // thing as the other one?".
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Size get _dimensions {
    switch (widget.size) {
      case GymLoaderSize.small:
        return const Size(24, 16);
      case GymLoaderSize.regular:
        return const Size(32, 22);
      case GymLoaderSize.large:
        return const Size(48, 32);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dim = _dimensions;
    final color = widget.color ?? GP.lime;
    return SizedBox(
      width: dim.width,
      height: dim.height,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          // Continuous rotation around centre. The dumbbell shape
          // is asymmetric (long bar, plates at the ends) so 360°
          // motion reads obviously as spinning — at every angle
          // the silhouette is different.
          final angle = _ctrl.value * math.pi * 2;
          return Transform.rotate(
            angle: angle,
            child: CustomPaint(
              painter: GymLoaderPainter(color: color, repaint: _ctrl),
            ),
          );
        },
      ),
    );
  }
}

/// Static dumbbell silhouette — two plates connected by a short bar.
/// The hosting widget rotates the canvas; the painter just draws the
/// shape centred. Layout:
///
///   [plate] [collar] [shaft] [collar] [plate]
class GymLoaderPainter extends CustomPainter {
  GymLoaderPainter({
    required this.color,
    this.glow = true,
    super.repaint,
  });

  final Color color;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final barHeight = size.height * 0.85;
    final barCentreY = size.height / 2;

    final plateWidth = size.width * 0.22;
    final plateHeight = barHeight;
    final collarWidth = size.width * 0.045;
    final collarHeight = barHeight * 0.58;
    final shaftThickness = barHeight * (glow ? 0.24 : 0.20);

    final leftPlateCx = plateWidth / 2 + 1;
    final rightPlateCx = size.width - plateWidth / 2 - 1;
    final leftCollarCx = leftPlateCx + plateWidth / 2 + collarWidth / 2;
    final rightCollarCx = rightPlateCx - plateWidth / 2 - collarWidth / 2;
    final shaftLeft = leftCollarCx + collarWidth / 2;
    final shaftRight = rightCollarCx - collarWidth / 2;

    final shaftRect = Rect.fromLTRB(
      shaftLeft,
      barCentreY - shaftThickness / 2,
      shaftRight,
      barCentreY + shaftThickness / 2,
    );
    final leftCollarRect = Rect.fromCenter(
      center: Offset(leftCollarCx, barCentreY),
      width: collarWidth,
      height: collarHeight,
    );
    final rightCollarRect = Rect.fromCenter(
      center: Offset(rightCollarCx, barCentreY),
      width: collarWidth,
      height: collarHeight,
    );
    final leftPlateRect = Rect.fromCenter(
      center: Offset(leftPlateCx, barCentreY),
      width: plateWidth,
      height: plateHeight,
    );
    final rightPlateRect = Rect.fromCenter(
      center: Offset(rightPlateCx, barCentreY),
      width: plateWidth,
      height: plateHeight,
    );

    if (glow) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            leftPlateRect.inflate(2),
            const Radius.circular(3),
          ),
          glowPaint,
        )
        ..drawRRect(
          RRect.fromRectAndRadius(
            rightPlateRect.inflate(2),
            const Radius.circular(3),
          ),
          glowPaint,
        );
    }

    final solidPaint = Paint()..color = color;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(shaftRect, const Radius.circular(2)),
        solidPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(leftCollarRect, const Radius.circular(2)),
        solidPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(rightCollarRect, const Radius.circular(2)),
        solidPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(leftPlateRect, const Radius.circular(3)),
        solidPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(rightPlateRect, const Radius.circular(3)),
        solidPaint,
      );
  }

  @override
  bool shouldRepaint(GymLoaderPainter old) =>
      old.color != color || old.glow != glow;
}
