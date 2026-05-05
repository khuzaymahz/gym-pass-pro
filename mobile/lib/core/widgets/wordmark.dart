import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/gp_tokens.dart';

class Wordmark extends StatelessWidget {
  final double size;
  final Color? paperColor;
  final Color? limeColor;

  const Wordmark({
    super.key,
    this.size = 28,
    this.paperColor,
    this.limeColor,
  });

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final inkToken = paperColor ?? gp.fg;
    final accent = limeColor ?? gp.accentInk;
    final style = TextStyle(
      fontFamily: 'Archivo',
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      fontSize: size,
      height: 1.0,
      letterSpacing: -size * 0.045,
    );
    // The brand wordmark is a logo, not translatable text — always reads
    // left-to-right so it doesn't visually flip to "PASSGYM" in RTL locales.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('GYM', style: style.copyWith(color: inkToken)),
          Text('PASS', style: style.copyWith(color: accent)),
        ],
      ),
    );
  }
}

/// Animated GYMPASS wordmark: a wave of light sweeps left-to-right through
/// the seven letters, looping continuously. Each letter brightens, lifts, and
/// glows as the wave passes through it. Used as a loading indicator anywhere
/// a static [Wordmark] would feel inert.
class WordmarkLoader extends StatefulWidget {
  const WordmarkLoader({
    super.key,
    this.size = 28,
    this.cycle = const Duration(milliseconds: 1400),
  });

  final double size;
  final Duration cycle;

  @override
  State<WordmarkLoader> createState() => _WordmarkLoaderState();
}

class _WordmarkLoaderState extends State<WordmarkLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.cycle)..repeat();

  static const _letters = ['G', 'Y', 'M', 'P', 'A', 'S', 'S'];

  // Width of the bright wave window in phase units (0..1). Wider = more
  // letters glowing simultaneously, softer feel.
  static const _waveWidth = 0.34;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final size = widget.size;
    // Baseline color per letter mirrors the static wordmark: GYM in the
    // foreground ink, PASS in the brand lime.
    final base = <Color>[
      gp.fg, gp.fg, gp.fg, // GYM
      gp.accentInk, gp.accentInk, gp.accentInk, gp.accentInk, // PASS
    ];
    final style = TextStyle(
      fontFamily: 'Archivo',
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      fontSize: size,
      height: 1.0,
      letterSpacing: -size * 0.045,
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          // Push the wave start before the first letter and finish after the
          // last so each letter gets a full peak in its turn.
          final t = -0.15 + _ctrl.value * 1.3;
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: List.generate(_letters.length, (i) {
              final phase = i / (_letters.length - 1);
              // Triangle envelope peaking at phase == t.
              final raw =
                  (1.0 - (t - phase).abs() / _waveWidth).clamp(0.0, 1.0);
              // Soften so the peak is sharper but the falloff is gentle.
              final glow = math.pow(raw, 1.5).toDouble();
              final color = Color.lerp(base[i], GP.limeHi, glow * 0.9)!;
              final lift = -size * 0.18 * glow;
              return Transform.translate(
                offset: Offset(0, lift),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: glow < 0.04
                        ? const []
                        : [
                            BoxShadow(
                              color: GP.lime.withValues(alpha: 0.55 * glow),
                              blurRadius: 22 * glow,
                              spreadRadius: 1.5 * glow,
                            ),
                          ],
                  ),
                  child: Text(_letters[i], style: style.copyWith(color: color)),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
