import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/glow.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../data/subscription_state.dart';

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  String _tierName(AppLocalizations l, String key) {
    switch (key) {
      case 'silver':
        return l.tierSilver;
      case 'platinum':
        return l.tierPlatinum;
      case 'diamond':
        return l.tierDiamond;
      case 'gold':
      default:
        return l.tierGold;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    // This route is the post-checkout landing surface, so a tier is always
    // set by the time we arrive. The fallback to the first tier is purely
    // defensive (e.g. hot-reload landing here in dev) and never represents
    // a real member's plan — the router would redirect them to /plans first.
    final sub = ref.watch(subscriptionProvider);
    final tier = sub.tier ?? GPTier.all.first;
    // Surface the cumulative term pool (e.g. 180 for a 6-month plan), not the
    // monthly allocation. Falling back to the tier monthly cap only matters
    // for the defensive no-subscription branch above.
    final total =
        sub.termTotalVisits > 0 ? sub.termTotalVisits : tier.visits;
    final visits = '$total';
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: RadialGlow(color: tier.color, opacity: 0.18, size: 600),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Overline(l.welcomeOverline),
                  const SizedBox(height: 40),
                  SizedBox(
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PulseRings(maxSize: 260, color: tier.color),
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [tier.color, tier.color.withValues(alpha: 0.6)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: tier.color.withValues(alpha: 0.5),
                                blurRadius: 40,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              tier.glyph,
                              style: const TextStyle(color: GP.ink, fontSize: 56, height: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      DisplayText(l.welcomeYoureTitle, size: 42, height: 0.9),
                      const SizedBox(width: 10),
                      SerifAccent(l.welcomeYoureAccent, size: 42),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l.welcomeSubTier(_tierName(l, tier.key)).toUpperCase(),
                    style: GPText.display(20, color: tier.readableOn(gp), height: 1.0),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 300,
                    child: Text(
                      l.welcomeBlurbLong(visits),
                      textAlign: TextAlign.center,
                      style: GPText.body(size: 14, color: gp.mutedSoft, height: 1.5),
                    ),
                  ),
                  const Spacer(),
                  PillButton(
                    label: l.welcomeFindGym,
                    trailingIcon: Icons.arrow_forward,
                    onPressed: () => context.go('/explore'),
                  ),
                  const SizedBox(height: 10),
                  PillButton(
                    label: l.welcomeGoHome,
                    variant: PillVariant.ghost,
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
