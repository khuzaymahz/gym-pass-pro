import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';

/// Per-tier styled rendering of the plan name in the plans-page card
/// header. Each tier reads as a different *material*:
///
///   - **Silver** — flat, minimal, low-chroma grey. No glow, no
///     animation. Reads as the entry tier without competing with the
///     paid ones for visual weight.
///   - **Gold** — warm amber, weight 800, a soft amber bloom behind
///     the text. Stays static (no animation) so the page doesn't feel
///     like a slot machine, but the bloom signals "you stepped up
///     from Silver".
///   - **Platinum** — pale white-blue with a slow shimmer gradient
///     sweeping across the glyphs. Implemented with a `ShaderMask`
///     so the moving highlight bands ride the actual letterforms,
///     giving the text a polished-metal feel.
///   - **Diamond** — cyan text with three sparkle stars positioned
///     around the wordmark, each pulsing on a staggered cycle so
///     they twinkle in sequence rather than blinking together. Reads
///     as crystal facets catching the light.
///
/// All four use the same monospace stack and the same letter-spacing
/// as the previous plain `GPText.mono` header — only the colour
/// treatment + adornments change. This keeps the row layout stable
/// (no width jump when tiers swap) and the typographic register
/// consistent with the rest of the page chrome.
class TierNameLabel extends StatefulWidget {
  const TierNameLabel({
    super.key,
    required this.tier,
    required this.label,
    this.fontSize = 11,
    this.letterSpacing = 1.8,
  });

  final GPTier tier;

  /// Already-localised tier name (e.g. "Platinum" / "بلاتيني"). The
  /// widget never localises itself — the caller supplies the right
  /// string for the active locale.
  final String label;

  final double fontSize;
  final double letterSpacing;

  @override
  State<TierNameLabel> createState() => _TierNameLabelState();
}

class _TierNameLabelState extends State<TierNameLabel>
    with SingleTickerProviderStateMixin {
  /// Drives both the platinum shimmer sweep and the diamond sparkle
  /// twinkle. We use one controller for both so the cost is a single
  /// frame callback rather than two competing tickers per page.
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    switch (widget.tier.key) {
      case 'silver':
        return _silver();
      case 'gold':
        return _gold();
      case 'platinum':
        return _platinum();
      case 'diamond':
        return _diamond();
      default:
        return _silver();
    }
  }

  /// **Silver** — plain text, low chroma, no decoration. The brief
  /// said "grey, flat, minimal"; we honour that literally — no glow,
  /// no animation, the lowest visual weight in the four-tier stack.
  Widget _silver() {
    return Text(
      widget.label.toUpperCase(),
      style: GPText.mono(
        size: widget.fontSize,
        letterSpacing: widget.letterSpacing,
        color: const Color(0xFF9E9E9E),
        weight: FontWeight.w600,
      ),
    );
  }

  /// **Gold** — warm amber text with a soft bloom behind it. The
  /// bloom is a static `Stack` layer (not an animation) so the card
  /// doesn't pulse when the eye is meant to settle on price/visits.
  Widget _gold() {
    const goldColor = Color(0xFFF9A825);
    return Stack(
      alignment: Alignment.center,
      children: [
        // Soft amber bloom behind the text. Sits at low alpha so the
        // text reads cleanly without competing for chroma — the bloom
        // is the "warm" cue, the text is the "bright" cue.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: goldColor.withValues(alpha: 0.45),
                blurRadius: 14,
                spreadRadius: -2,
              ),
            ],
          ),
        ),
        Text(
          widget.label.toUpperCase(),
          style: GPText.mono(
            size: widget.fontSize,
            letterSpacing: widget.letterSpacing,
            color: goldColor,
            weight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  /// **Platinum** — a `ShaderMask` paints the text with a sliding
  /// linear gradient (white-blue → bright white → white-blue) that
  /// loops over `_ctrl.value`. The gradient stops are offset by a
  /// fraction of `t` so the bright band sweeps left-to-right across
  /// the wordmark each cycle, reading as a polished-metal sheen
  /// rather than a marquee scroll.
  Widget _platinum() {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return ShaderMask(
          // BoxFit-tight rect so the gradient maps to the text's
          // bounding box, not the parent's.
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 + t * 2, -0.4),
              end: Alignment(1 + t * 2, 0.4),
              colors: const [
                Color(0xFFB8D4FF),
                Color(0xFFFFFFFF),
                Color(0xFFB8D4FF),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.label.toUpperCase(),
            style: GPText.mono(
              size: widget.fontSize,
              letterSpacing: widget.letterSpacing,
              // ShaderMask paints over white, so any opaque colour
              // here works — picking white keeps the glyphs at full
              // chroma when the gradient lands its bright stop on
              // them.
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }

  /// **Diamond** — the wordmark in cyan with three small sparkle
  /// stars positioned around it. Each sparkle has a phase-offset so
  /// they twinkle in sequence (top-left → top-right → bottom). The
  /// stars are decorative only — the underlying text remains the
  /// canonical name and is what screen readers see.
  Widget _diamond() {
    const diamondColor = Color(0xFF00E5FF);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              widget.label.toUpperCase(),
              style: GPText.mono(
                size: widget.fontSize,
                letterSpacing: widget.letterSpacing,
                color: diamondColor,
                weight: FontWeight.w800,
              ),
            ),
            // Three sparkles, each on its own phase. Math: each gets
            // a phase offset of 1/3 so the twinkles cascade rather
            // than co-fire. `_sparkleOpacity` clamps the wave to
            // [0.2, 1.0] so they fade rather than disappear, keeping
            // the area lively across the whole cycle.
            Positioned(
              top: -4,
              left: -6,
              child: _Sparkle(
                opacity: _sparkleOpacity(t, 0.0),
                color: diamondColor,
                size: 8,
              ),
            ),
            Positioned(
              top: -2,
              right: -8,
              child: _Sparkle(
                opacity: _sparkleOpacity(t, 1 / 3),
                color: diamondColor,
                size: 6,
              ),
            ),
            Positioned(
              bottom: -6,
              right: 12,
              child: _Sparkle(
                opacity: _sparkleOpacity(t, 2 / 3),
                color: diamondColor,
                size: 5,
              ),
            ),
          ],
        );
      },
    );
  }

  static double _sparkleOpacity(double t, double phase) {
    final shifted = (t + phase) % 1.0;
    // Sine wave [0, 1] over the cycle, then clamped to [0.2, 1.0]
    // so the sparkle never fully disappears — the eye should always
    // catch some twinkle no matter when it lands on the row.
    final sine = 0.5 + 0.5 * math.sin(shifted * 2 * math.pi);
    return 0.2 + 0.8 * sine;
  }
}

/// Four-pointed star drawn with two crossed diamonds. Pure paint, no
/// asset dependency — the shape scales with [size] so we can drop in
/// a 5px or 8px sparkle without aliasing artifacts a small PNG would
/// have.
class _Sparkle extends StatelessWidget {
  const _Sparkle({
    required this.opacity,
    required this.color,
    required this.size,
  });

  final double opacity;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _SparklePainter(color: color)),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final hw = size.width / 2;
    final hh = size.height / 2;
    // Pinch the side arms inward so the star reads as a 4-point
    // star rather than a square diamond — gives the diamond glyph a
    // crisper "twinkle" silhouette.
    const pinch = 0.18;
    final path = Path()
      ..moveTo(cx, 0)
      ..lineTo(cx + hw * pinch, cy - hh * pinch)
      ..lineTo(size.width, cy)
      ..lineTo(cx + hw * pinch, cy + hh * pinch)
      ..lineTo(cx, size.height)
      ..lineTo(cx - hw * pinch, cy + hh * pinch)
      ..lineTo(0, cy)
      ..lineTo(cx - hw * pinch, cy - hh * pinch)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color;
}
