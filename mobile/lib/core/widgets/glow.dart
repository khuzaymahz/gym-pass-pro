import 'package:flutter/material.dart';

import '../theme/gp_tokens.dart';

class RadialGlow extends StatelessWidget {
  final Color color;
  final double opacity;
  final Alignment alignment;
  // Gradient radius as a fraction of the shortest side / 2 (Flutter's
  // RadialGradient convention). 1.33 ≈ the old size:520 glow on a
  // 390 px-wide phone; increase for a wider bloom.
  final double radius;

  // `size` is kept for call-site compatibility but is no longer used —
  // the glow now fills its parent (no more visible box edges).
  // ignore: unused_element
  final double size;

  const RadialGlow({
    super.key,
    this.color = GP.lime,
    this.opacity = 0.18,
    this.alignment = Alignment.topCenter,
    this.radius = 1.33,
    this.size = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Fills the parent completely (via SizedBox.expand) so there is no
    // fixed-size container whose edges can show on dark backgrounds.
    // RadialGradient.center positions the hot-spot; radius controls how
    // far the glow spreads before fading to transparent alpha=0.
    return IgnorePointer(
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: alignment,
              radius: radius,
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * 0.55),
                color.withValues(alpha: opacity * 0.22),
                color.withValues(alpha: opacity * 0.06),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PulseRings extends StatefulWidget {
  final double maxSize;
  final Color color;

  const PulseRings({super.key, this.maxSize = 280, this.color = GP.lime});

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      );
      Future.delayed(Duration(milliseconds: 400 * i), () {
        if (mounted) c.repeat();
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.maxSize,
      height: widget.maxSize,
      child: Stack(
        alignment: Alignment.center,
        children: _controllers.map((c) {
          return AnimatedBuilder(
            animation: c,
            builder: (_, __) {
              final v = c.value;
              return Container(
                width: widget.maxSize * v,
                height: widget.maxSize * v,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: (1 - v) * 0.6),
                    width: 1.2,
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
