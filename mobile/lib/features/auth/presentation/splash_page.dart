import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bootstrap/app_bootstrap.dart';
import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/glow.dart';
import '../../../core/widgets/overline.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_controller.dart';

/// First-frame brand surface. Locale + theme are correct from
/// the very first paint because `main()` sync-loads them via
/// [loadAppPreferences] before `runApp` — so no Arabic-flash for
/// an EN user, no dark-flash for a Light user. The native
/// launch background underneath is day/night-aware (Android
/// resource folders), so a member whose chosen theme matches
/// their OS theme sees one continuous surface across native →
/// Flutter → /home; a mismatch causes at most one transition at
/// the native → Flutter handoff (which is masked by the wordmark
/// reveal animation drawing on top of it).
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
        ..repeat(reverse: true);

  late final AnimationController _reveal =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..forward();

  @override
  void initState() {
    super.initState();
    // Defer the provider cascade past the first frame so the splash paints
    // immediately; route only once bootstrap has finished AND the reveal has
    // had time to play. Whichever finishes last wins.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bootstrap = ref.read(appBootstrapProvider.future);
      final minDisplay = Future<void>.delayed(const Duration(milliseconds: 900));
      Future.wait<void>([bootstrap, minDisplay]).then((_) => _advance());
    });
  }

  void _advance() {
    if (!mounted) return;
    // Stop both tickers before routing so they don't keep burning frames
    // behind the destination page until the widget is torn down.
    _pulse.stop();
    _reveal.stop();
    final phase = ref.read(authControllerProvider).phase;
    context.go(phase == AuthPhase.authed ? '/home' : '/sign-in');
  }

  @override
  void dispose() {
    _pulse.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    return Scaffold(
      backgroundColor: gp.bg,
      body: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => RadialGlow(
              opacity: 0.14 + _pulse.value * 0.08,
              radius: 1.33 + _pulse.value * 0.08,
              alignment: Alignment.center,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AnimatedWordmark(controller: _reveal, size: 76),
              const SizedBox(height: 22),
              _FadeInOverline(
                controller: _reveal,
                text: l.splashTagline,
              ),
              const SizedBox(height: 120),
              Text(
                l.splashLoading,
                style: GPText.mono(size: 10, letterSpacing: 2.4, color: gp.muted),
              ),
            ],
          ),
          Positioned(
            bottom: 40,
            child: Text(
              l.splashFooter,
              style: GPText.mono(size: 9, letterSpacing: 2.0, color: gp.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Creative two-word reveal for the GYM PASS wordmark. A lime continuity dot
/// sits at the center of the frame on first paint (matching the native launch
/// window) and dissolves as GYM slides in from the left and PASS slides in
/// from the right; an underline sweep seals the mark once both words meet.
class _AnimatedWordmark extends StatelessWidget {
  final AnimationController controller;
  final double size;

  const _AnimatedWordmark({required this.controller, required this.size});

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final dotFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.00, 0.30, curve: Curves.easeOut),
    );
    final gymSlide = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.15, 0.65, curve: Curves.easeOutCubic),
    );
    final passSlide = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.30, 0.85, curve: Curves.easeOutCubic),
    );
    final underline = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.60, 1.00, curve: Curves.easeOutCubic),
    );
    final breathe = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );

    final baseStyle = TextStyle(
      fontFamily: 'Archivo',
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      fontSize: size,
      height: 1.0,
      letterSpacing: -size * 0.045,
    );

    // Wordmark is a logo — lock LTR so it doesn't flip to "PASS GYM" in RTL.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          return Transform.scale(
            scale: 0.94 + breathe.value * 0.06,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 1 - dotFade.value,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: GP.lime,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Opacity(
                          opacity: gymSlide.value,
                          child: Transform.translate(
                            offset: Offset(-40 * (1 - gymSlide.value), 0),
                            child: Text(
                              'GYM',
                              style: baseStyle.copyWith(color: gp.fg),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: passSlide.value,
                          child: Transform.translate(
                            offset: Offset(40 * (1 - passSlide.value), 0),
                            child: Text(
                              'PASS',
                              style: baseStyle.copyWith(color: gp.accentInk),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _UnderlineSweep(
                      progress: underline.value,
                      color: gp.accentInk,
                      maxWidth: size * 4.2,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UnderlineSweep extends StatelessWidget {
  final double progress;
  final Color color;
  final double maxWidth;

  const _UnderlineSweep({
    required this.progress,
    required this.color,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: maxWidth,
      height: 3,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: maxWidth * progress,
          height: 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.55),
                blurRadius: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FadeInOverline extends StatelessWidget {
  final AnimationController controller;
  final String text;

  const _FadeInOverline({required this.controller, required this.text});

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.75, 1.00, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: fade,
      builder: (_, __) => Opacity(
        opacity: fade.value,
        child: Overline(text),
      ),
    );
  }
}
