import 'package:flutter/material.dart';

import '../theme/gp_tokens.dart';

class RadialGlow extends StatelessWidget {
  final Color color;
  final double opacity;
  final double size;
  final Alignment alignment;

  const RadialGlow({
    super.key,
    this.color = GP.lime,
    this.opacity = 0.18,
    this.size = 520,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    // Soft falloff: 5 stops with a cubic-ish curve, gradient `radius: 1.0`
    // so the dim outer ring fades inside the square's diagonal. A flat
    // 2-stop linear ramp at `radius: 0.5` produces a visible disc edge
    // and concentric banding on dark backgrounds; the extra stops give
    // the GPU enough alpha resolution to dither the falloff smoothly.
    // No `BoxShape.circle` — the alpha hits 0 at radius 1.0, so a hard
    // circular clip is unnecessary and only adds an aliased edge.
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.0,
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
