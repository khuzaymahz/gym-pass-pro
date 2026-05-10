import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bootstrap/app_bootstrap.dart';
import '../../../core/prefs/app_preferences.dart';
import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/glow.dart';
import '../../../core/widgets/overline.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_controller.dart';

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
    // Splash deliberately follows the **OS brightness**, not the
    // user's stored theme preference, for the same reason the
    // native launch background does (see `values/colors.xml` →
    // `gp_launch_bg`): the brand moment lives between the OS's
    // launch window and Flutter's first frame, both of which are
    // OS-driven, so painting the splash from `prefs.themeMode`
    // (which lags behind because it hydrates from secure_storage
    // post-frame) creates a guaranteed dark→light flicker mid-
    // splash for any member who chose Light. By following OS
    // brightness here, the native launch flash and the Flutter
    // splash share the same surface — the handoff is invisible —
    // and the at-most-one theme transition happens cleanly at
    // the splash → /home navigation, where the route slide masks
    // it. Pick the matching palette explicitly from `GpColors`
    // so we get the same exact shade Flutter would have applied.
    final isOsDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final palette = isOsDark ? GpColors.dark : GpColors.light;
    final hydrated = ref.watch(
      appPreferencesProvider.select((p) => p.hydrated),
    );
    return Scaffold(
      backgroundColor: palette.bg,
      body: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => RadialGlow(
              opacity: 0.14 + _pulse.value * 0.08,
              size: 520 + _pulse.value * 30,
              alignment: Alignment.center,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AnimatedWordmark(
                controller: _reveal,
                size: 76,
                fg: palette.fg,
                accentInk: palette.accentInk,
              ),
              const SizedBox(height: 22),
              // Locale-dependent text — only render once secure_storage
              // has hydrated and we know the user's chosen locale. Until
              // then, reserve the vertical space with a fixed-height
              // SizedBox so the wordmark doesn't shift when the tagline
              // fades in. Without this gate, a member who chose EN sees
              // the Arabic tagline for ~50–200 ms before it flips.
              SizedBox(
                height: 14,
                child: hydrated
                    ? _FadeInOverline(
                        controller: _reveal,
                        text: l.splashTagline,
                      )
                    : null,
              ),
              const SizedBox(height: 120),
              SizedBox(
                height: 14,
                child: hydrated
                    ? Text(
                        l.splashLoading,
                        style: GPText.mono(
                          size: 10,
                          letterSpacing: 2.4,
                          color: palette.muted,
                        ),
                      )
                    : null,
              ),
            ],
          ),
          Positioned(
            bottom: 40,
            child: SizedBox(
              height: 13,
              child: hydrated
                  ? Text(
                      l.splashFooter,
                      style: GPText.mono(
                        size: 9,
                        letterSpacing: 2.0,
                        color: palette.muted,
                      ),
                    )
                  : null,
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
  // `fg` and `accentInk` are passed in from the parent rather than
  // pulled from `context.gp` so the wordmark follows the splash's
  // OS-driven palette (see the rationale on `_SplashPageState.build`)
  // instead of the active app theme — which during the splash window
  // is the default `ThemeMode.dark` until prefs hydrate.
  final Color fg;
  final Color accentInk;

  const _AnimatedWordmark({
    required this.controller,
    required this.size,
    required this.fg,
    required this.accentInk,
  });

  @override
  Widget build(BuildContext context) {
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
                              style: baseStyle.copyWith(color: fg),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: passSlide.value,
                          child: Transform.translate(
                            offset: Offset(40 * (1 - passSlide.value), 0),
                            child: Text(
                              'PASS',
                              style: baseStyle.copyWith(color: accentInk),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _UnderlineSweep(
                      progress: underline.value,
                      color: accentInk,
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
