import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/gp_tokens.dart';

/// Static GYMPASS brand logo rendered from the vector source.
/// GYM paths use `currentColor` so they follow the active theme
/// (white on dark, ink on light). PASS paths are hardcoded #F8BB0A
/// in the SVG so they are always gold — no override needed.
///
/// [size] controls the logo height in logical pixels; width scales
/// proportionally from the SVG aspect ratio (≈ 6.8 : 1).
class Wordmark extends StatelessWidget {
  const Wordmark({
    super.key,
    this.size = 28,
    this.gymColor,
  });

  final double size;

  /// Override the GYM letter colour. Defaults to `context.gp.fg`
  /// (white in dark mode, ink in light mode).
  final Color? gymColor;

  @override
  Widget build(BuildContext context) {
    final color = gymColor ?? context.gp.fg;
    return SvgPicture.asset(
      'assets/branding/gympass.svg',
      height: size,
      theme: SvgTheme(currentColor: color),
    );
  }
}

/// Animated GYMPASS logo: the GYM letters pulse between the theme
/// foreground and limeHi while PASS stays gold. Used as a loading
/// indicator anywhere a static [Wordmark] would feel inert.
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
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.cycle,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final color = Color.lerp(gp.fg, GP.limeHi, _ctrl.value * 0.55)!;
        return SvgPicture.asset(
          'assets/branding/gympass.svg',
          height: widget.size,
          theme: SvgTheme(currentColor: color),
        );
      },
    );
  }
}
