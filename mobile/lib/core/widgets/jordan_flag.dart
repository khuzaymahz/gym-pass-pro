import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tiny Jordanian flag rendered in the country's proper ratio (2:1) with the
/// three horizontal bands (black / white / green), the red chevron on the
/// hoist, and the seven-pointed white star. Used in the phone-field prefix
/// instead of the `🇯🇴` emoji because:
///   1. Emoji flag glyphs fall back to plain text (`JO`) on Windows, emulators
///      without a full emoji font, or low-density devices.
///   2. On some Android flavors the fallback renders a *different* country's
///      flag depending on locale, which the user correctly called out as
///      "that's not the Jordanian flag."
///
/// The painter is deterministic across platforms and adds no dependency.
class JordanFlag extends StatelessWidget {
  const JordanFlag({super.key, this.height = 14});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height * 2,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CustomPaint(painter: _JordanFlagPainter()),
      ),
    );
  }
}

class _JordanFlagPainter extends CustomPainter {
  // Jordan flag colors, from the official spec.
  static const _black = Color(0xFF000000);
  static const _white = Color(0xFFFFFFFF);
  static const _green = Color(0xFF007A3D);
  static const _red = Color(0xFFCE1126);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final band = h / 3;

    // Three horizontal bands.
    final paint = Paint();
    paint.color = _black;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, band), paint);
    paint.color = _white;
    canvas.drawRect(Rect.fromLTWH(0, band, w, band), paint);
    paint.color = _green;
    canvas.drawRect(Rect.fromLTWH(0, 2 * band, w, band), paint);

    // Red hoist chevron — isoceles triangle whose base is the full hoist
    // edge and whose tip reaches the horizontal midpoint of the flag.
    final chevron = Path()
      ..moveTo(0, 0)
      ..lineTo(w / 2, h / 2)
      ..lineTo(0, h)
      ..close();
    paint.color = _red;
    canvas.drawPath(chevron, paint);

    // Seven-pointed white star centered on the chevron.
    _drawStar(
      canvas,
      center: Offset(w * 0.22, h / 2),
      radius: h * 0.18,
      points: 7,
      color: _white,
    );
  }

  void _drawStar(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required int points,
    required Color color,
  }) {
    // Two interleaved rings — tips (outer) and valleys (inner) — traced in
    // order, same algorithm as standard n-point star rendering.
    final inner = radius * 0.45;
    final step = math.pi / points;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : inner;
      final angle = -math.pi / 2 + i * step;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _JordanFlagPainter oldDelegate) => false;
}
