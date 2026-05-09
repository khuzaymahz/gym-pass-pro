import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../core/widgets/gym_logo.dart';
import '../../../../core/widgets/overline.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../gyms/data/gym_summary.dart';
import '../../../gyms/data/media_url.dart';

/// Filter the live-backend gym list down to the network unlocked
/// for `tier`. A higher-ranked tier implicitly includes every
/// lower tier — Silver rank 1 is accessible to everyone; Diamond
/// rank 4 is reserved for Diamond members only.
///
/// Gyms whose `tier` slug doesn't decode (null, empty, unknown
/// string) fall through to Silver-rank treatment so they still
/// surface — better than the gym disappearing because the partner
/// hasn't filled in `requiredTier` yet.
List<GymSummary> filterGymsForTier(List<GymSummary> all, GPTier tier) {
  return all.where((g) {
    final key = g.tier;
    if (key == null || key.isEmpty) return tier.rank >= 1;
    return GPTier.byKey(key).rank <= tier.rank;
  }).toList();
}

class TierNetworkSheet {
  const TierNetworkSheet._();

  static Future<void> show({
    required BuildContext context,
    required GPTier tier,
    required String localizedTierName,
    required List<GymSummary> gyms,
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
        gyms: gyms,
      ),
    );
  }
}

class _TierNetworkBody extends ConsumerWidget {
  const _TierNetworkBody({
    required this.tier,
    required this.localizedTierName,
    required this.gyms,
  });

  final GPTier tier;
  final String localizedTierName;
  final List<GymSummary> gyms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    final apiBaseUrl = ref.watch(envProvider).apiBaseUrl;
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
                        apiBaseUrl: apiBaseUrl,
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
    required this.apiBaseUrl,
    required this.badgeLabel,
  });

  final GymSummary gym;
  final Color accent;
  final GpColors gp;
  final String apiBaseUrl;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final displayName = isAr && gym.nameAr.isNotEmpty ? gym.nameAr : gym.nameEn;
    final logoUrl = gym.logoUrl;
    final resolvedLogo =
        logoUrl == null || logoUrl.isEmpty ? null : resolveMediaUrl(apiBaseUrl, logoUrl);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: gp.bg3,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
      ),
      child: Row(
        children: [
          GymLogo.fromSummary(
            gym,
            resolvedLogoUrl: resolvedLogo,
            size: 44,
            shape: GymLogoShape.circle,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: GPText.body(
                    size: 14,
                    color: gp.fg,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if ((gym.area ?? '').isNotEmpty)
                  Text(
                    gym.area!,
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
