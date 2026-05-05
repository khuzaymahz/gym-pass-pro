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
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              radius: 0.5,
              colors: [
                color.withValues(alpha: opacity),
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
