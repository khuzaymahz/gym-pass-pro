import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/gp_text.dart';
import '../theme/gp_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'connectivity.dart';

/// Thin slide-down banner anchored to the top of the screen via
/// `SafeArea`, visible only while [connectivityProvider] reports
/// [NetworkStatus.offline]. Communicates "you're offline; we're
/// showing your saved list" without blocking the underlying UI.
///
/// Drop one instance per scaffold in the bottom-nav shell so every
/// tab inherits the same indicator. The widget renders a sized box
/// when online so layouts that build it unconditionally don't have
/// to reserve space.
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
          : Container(
              key: const ValueKey('offline'),
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
    );
  }
}
