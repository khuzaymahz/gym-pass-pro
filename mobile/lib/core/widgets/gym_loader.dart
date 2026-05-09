import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/gp_tokens.dart';

/// Brand-themed loading indicator — a dumbbell that *builds itself*
/// each cycle: plates drop in from above and grow from a sliver to
/// full height, sequenced from outermost to innermost. Once fully
/// assembled it holds for a beat, then resets.
///
/// Drop-in replacement for [CircularProgressIndicator] anywhere a
/// loading state needs to read as "GymPass is working". Use it for
/// indeterminate waits — weak-network API calls, page initial loads,
/// button-press spinners, sheet-content fetches.
///
/// **Size**: defaults to a compact 32 × 22. Override via [size] for
/// a hero loading screen (e.g. `size: GymLoaderSize.large`). The
/// number of plates per side scales with the size so a small
/// in-button loader stays legible (single plate) while the hero
/// composition gets the full three-plate drop sequence.
class GymLoader extends StatefulWidget {
  const GymLoader({
    super.key,
    this.size = GymLoaderSize.regular,
    this.color,
  });

  final GymLoaderSize size;

  /// Defaults to the brand lime. Override for a tier-tinted loader
  /// (e.g. inside a Gold tier sheet) or to swap to amber for a
  /// secondary surface.
  final Color? color;

  @override
  State<GymLoader> createState() => _GymLoaderState();
}

/// Predefined sizes. The new "build" animation is more visually
/// involved than the previous rotating silhouette, so the smaller
/// sizes drop plates from the design rather than try to cram three
/// of them into a 24-px slot.
enum GymLoaderSize {
  /// 24 × 16 — fits inside a button or compact pill. Single plate
  /// per side: the drop sequence still reads but the dumbbell stays
  /// uncluttered at button size.
  small,

  /// 32 × 22 — default. Two plates per side; the relative-size
  /// difference signals weight without requiring three elements at
  /// regular text-line height.
  regular,

  /// 48 × 32 — page-level loaders, empty-state cards. Full
  /// three-plate composition matching the hero design — outer plate
  /// is largest, inner-most is smallest; same shape every gym in
  /// the brand uses.
  large,
}

class _GymLoaderState extends State<GymLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // 2.4 s per cycle: plates finish dropping at the 80 % mark
    // (`progress` reaches 1.0), then the dumbbell holds for the
    // remaining 480 ms before resetting. The hold is what makes the
    // animation feel deliberate rather than busy — the eye has time
    // to register the assembled shape before the next cycle starts.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
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

  int get _plateCount {
    switch (widget.size) {
      case GymLoaderSize.small:
        return 1;
      case GymLoaderSize.regular:
        return 2;
      case GymLoaderSize.large:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dim = _dimensions;
    final gp = context.gp;
    final color = widget.color ?? GP.lime;
    // Grip + knurl colors are theme-driven so the dumbbell reads on
    // both the dark canvas (mid-grey grip with dark knurl ticks) and
    // the light surface (warm-grey grip with white knurl ticks). The
    // plates always carry the brand chroma — that's the part the eye
    // tracks during the drop sequence.
    final gripColor = gp.line2;
    final knurlColor = gp.bg;
    return SizedBox(
      width: dim.width,
      height: dim.height,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          // `progress` = 0 → empty grip + caps; 1.0 → fully assembled.
          // The 1.25 multiplier is what makes the plates finish
          // dropping at ~80 % of the cycle; the clamp at the top
          // gives the assembled state a 480 ms hold before reset.
          final progress = (_ctrl.value * 1.25).clamp(0.0, 1.0);
          return CustomPaint(
            painter: _DumbbellBuildPainter(
              plateColor: color,
              gripColor: gripColor,
              knurlColor: knurlColor,
              progress: progress,
              plateCount: _plateCount,
            ),
          );
        },
      ),
    );
  }
}

/// Paints the dumbbell with progressive plate-drop assembly. The grip
/// + caps are static; only the plates animate.
///
/// Geometry mirrors the React hero composition (`HeroDumbbell`):
/// grip is `0.90 × unit` long, plates are 0.96/0.82/0.66 × unit tall
/// (outer → inner), each `0.16/0.14/0.12 × unit` wide. `unit` is the
/// painter's normalising scale — chosen as the largest size that
/// fits both the canvas width and height so the dumbbell scales
/// proportionally regardless of the slot's aspect ratio.
class _DumbbellBuildPainter extends CustomPainter {
  _DumbbellBuildPainter({
    required this.plateColor,
    required this.gripColor,
    required this.knurlColor,
    required this.progress,
    required this.plateCount,
  });

  final Color plateColor;
  final Color gripColor;
  final Color knurlColor;
  final double progress;
  final int plateCount;

  static double _easeOutCubic(double t) =>
      1.0 - math.pow(1.0 - t, 3).toDouble();

  /// Plate specs in unit-fractions, outer → inner. We slice this list
  /// down to [plateCount] so smaller loader sizes show fewer plates
  /// (single largest plate per side at small, two plates at regular,
  /// full three at large).
  static const List<_PlateSpec> _plateSpecs = [
    _PlateSpec(0.16, 0.96),
    _PlateSpec(0.14, 0.82),
    _PlateSpec(0.12, 0.66),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Total dumbbell width in unit-fractions, picking the configured
    // plate count so the unit can be derived from the smaller
    // available axis.
    //   grip(0.90) + 2*(cap(0.10) + spacer(0.06)) + 2*sum(plate.w)
    final plates = _plateSpecs.sublist(0, plateCount);
    final totalPlateW = plates.fold<double>(0, (a, p) => a + p.w);
    final widthUnits = 0.90 + 2 * (0.10 + 0.06) + 2 * totalPlateW;
    const heightUnits = 1.20;

    final unit = math.min(size.width / widthUnits, size.height / heightUnits);
    final cx = size.width / 2;
    final cy = size.height / 2;

    final gripW = unit * 0.90;
    final gripH = unit * 0.18;
    final capW = unit * 0.10;
    final capH = unit * 0.55;
    final gripLeft = cx - gripW / 2;
    final gripTop = cy - gripH / 2;

    // GRIP — solid bar, single colour. The 0.35× radius is enough
    // for the ends to read as round-ended without becoming a pill.
    final gripPaint = Paint()..color = gripColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(gripLeft, gripTop, gripW, gripH),
        Radius.circular(gripH * 0.35),
      ),
      gripPaint,
    );

    // KNURL — light tick marks across the grip. We don't draw them
    // at the smallest size: at a 24-px loader the ticks would
    // sub-pixel and show as a smudged band rather than discrete
    // marks. From regular up they read cleanly.
    if (unit >= 16) {
      final knurlPaint = Paint()
        ..color = knurlColor.withValues(alpha: 0.55)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      const knurlCount = 7;
      for (var i = 0; i < knurlCount; i++) {
        final x = gripLeft + unit * 0.15 + i * unit * 0.10;
        if (x > gripLeft + gripW - unit * 0.05) break;
        canvas.drawLine(
          Offset(x, cy - gripH * 0.30),
          Offset(x, cy + gripH * 0.30),
          knurlPaint,
        );
      }
    }

    // END CAPS — clean rectangles flanking the grip. Drawn before
    // plates so the plates layer over the cap when they "snap" into
    // place at full extension.
    final capPaint = Paint()..color = gripColor.withValues(alpha: 0.92);
    for (final side in const [-1, 1]) {
      final capX =
          cx + side * (gripW / 2) + (side < 0 ? -capW : 0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(capX, cy - capH / 2, capW, capH),
          Radius.circular(unit * 0.05),
        ),
        capPaint,
      );
    }

    // PLATES — drop in sequentially per side. Each plate has its own
    // start fraction (`i / plateCount`); within its window it grows
    // from 0 to full height while sliding down from a `+0.25 × unit`
    // offset to its rest position. The 1.15 over-multiplier makes
    // each plate finish slightly before the next one starts so the
    // sequence reads as overlapping drops rather than discrete steps.
    for (final side in const [-1, 1]) {
      var runner = cx + side * (gripW / 2 + capW);
      for (var i = 0; i < plates.length; i++) {
        final p = plates[i];
        final start = i / plates.length;
        final local =
            ((progress - start) * plates.length * 1.15).clamp(0.0, 1.0);
        final e = _easeOutCubic(local);
        final pw = p.w * unit;
        final ph = p.h * unit * e;
        final xPos = side < 0 ? runner - pw : runner;
        runner += side * pw;
        if (e <= 0) continue;
        final dropOffset = (1 - e) * unit * 0.25;
        final plateRect = Rect.fromLTWH(
          xPos,
          cy - ph / 2 + dropOffset,
          pw,
          ph,
        );
        final plateRRect = RRect.fromRectAndRadius(
          plateRect,
          Radius.circular(unit * 0.04),
        );

        // Glow snap once the plate is essentially fully formed —
        // mirrors the React `drop-shadow` appearing at e > 0.92. A
        // separate blurred draw underneath the solid fill simulates
        // CSS's drop-shadow without bleeding the fill itself.
        if (e > 0.92 && unit >= 12) {
          final glowPaint = Paint()
            ..color = plateColor.withValues(alpha: 0.32)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.10);
          canvas.drawRRect(plateRRect, glowPaint);
        }

        final platePaint = Paint()..color = plateColor.withValues(alpha: e);
        canvas.drawRRect(plateRRect, platePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_DumbbellBuildPainter old) =>
      old.plateColor != plateColor ||
      old.gripColor != gripColor ||
      old.knurlColor != knurlColor ||
      old.progress != progress ||
      old.plateCount != plateCount;
}

class _PlateSpec {
  const _PlateSpec(this.w, this.h);
  final double w;
  final double h;
}
