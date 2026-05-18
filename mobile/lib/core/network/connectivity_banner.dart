import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/gp_text.dart';
import '../theme/gp_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'connectivity.dart';

/// Thin slide-down banner anchored to the top of the screen,
/// visible only while [connectivityProvider] reports
/// [NetworkStatus.offline]. Communicates "you're offline; we're
/// showing your saved list" without blocking the underlying UI.
///
/// **Layout contract**: the banner takes ZERO layout space when
/// online — `SizedBox.shrink()` is genuinely zero-sized AND the
/// SafeArea inset is folded *inside* the offline branch only.
/// This is intentional: HomeShell stacks this banner as a
/// `Positioned(top:0)` overlay above the navigation stack, so an
/// empty banner must not reserve the status-bar inset (doing so
/// produced a phantom ~50 px band between the system status bar
/// and every page header).
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityProvider);
    final isOffline = status == NetworkStatus.offline;
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    // AnimatedSwitcher gives us the slide-in / slide-out without
    // a controller and without reserving height when not visible.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        return SizeTransition(
          sizeFactor: anim,
          axisAlignment: -1,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      child: !isOffline
          ? const SizedBox.shrink(key: ValueKey('online'))
          : SafeArea(
              key: const ValueKey('offline'),
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: gp.bg2,
                  border: Border(
                    bottom: BorderSide(color: gp.line),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: GP.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.offlineBannerMessage,
                        style: GPText.mono(
                          size: 11,
                          letterSpacing: 1.2,
                          color: gp.fg,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
