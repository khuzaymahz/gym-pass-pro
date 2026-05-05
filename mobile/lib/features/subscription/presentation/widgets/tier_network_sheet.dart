import 'package:flutter/material.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../core/widgets/gym_logo.dart';
import '../../../../core/widgets/overline.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../../../l10n/app_localizations.dart';

/// Gyms currently unlocked for `tier`. A higher-ranked tier implicitly
/// includes every lower tier — Silver rank 1 is accessible to everyone;
/// Diamond rank 4 is reserved for Diamond members only.
List<GPGym> gymsInTierNetwork(GPTier tier) =>
    GPGym.seed.where((g) => g.tierObj.rank <= tier.rank).toList();

class TierNetworkSheet {
  const TierNetworkSheet._();

  static Future<void> show({
    required BuildContext context,
    required GPTier tier,
    required String localizedTierName,
  }) {
    final gp = context.gp;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: gp.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(GPRadius.xl2)),
      ),
      builder: (sheetCtx) => _TierNetworkBody(
        tier: tier,
        localizedTierName: localizedTierName,
      ),
    );
  }
}

class _TierNetworkBody extends StatelessWidget {
  const _TierNetworkBody({
    required this.tier,
    required this.localizedTierName,
  });

  final GPTier tier;
  final String localizedTierName;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    final gyms = gymsInTierNetwork(tier);
    final accent = tier.readableOn(gp);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: gp.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tier.glyph,
                        style: TextStyle(color: accent, fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Overline(
                        l.plansNetworkCount(gyms.length).toUpperCase(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: DisplayText(
                          l.plansNetworkSheetTitle(localizedTierName),
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.plansNetworkSheetBody,
                    style: GPText.body(size: 13, color: gp.mutedSoft),
                  ),
                ],
              ),
            ),
            Expanded(
              child: gyms.isEmpty
                  ? _EmptyState(message: l.plansNetworkEmpty, gp: gp)
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding:
                          const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: gyms.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _GymRow(
                        gym: gyms[i],
                        accent: accent,
                        gp: gp,
                        badgeLabel: l.plansNetworkVisitsBadge,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
              child: PillButton(
                label: l.plansNetworkClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GymRow extends StatelessWidget {
  const _GymRow({
    required this.gym,
    required this.accent,
    required this.gp,
    required this.badgeLabel,
  });

  final GPGym gym;
  final Color accent;
  final GpColors gp;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: gp.bg3,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
      ),
      child: Row(
        children: [
          GymLogo(gym: gym, size: 44, shape: GymLogoShape.circle),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gym.name,
                  style: GPText.body(
                    size: 14,
                    color: gp.fg,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  gym.area,
                  style: GPText.mono(
                    size: 10,
                    letterSpacing: 1.2,
                    color: gp.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(GPRadius.pill),
              border: Border.all(color: accent.withValues(alpha: 0.55)),
            ),
            child: Text(
              badgeLabel,
              style: GPText.mono(
                size: 10,
                letterSpacing: 1.4,
                color: accent,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.gp});

  final String message;
  final GpColors gp;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GPText.body(size: 13, color: gp.muted),
        ),
      ),
    );
  }
}
