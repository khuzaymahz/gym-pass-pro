import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/gym_summary.dart';
import 'explore_format.dart';
import 'gym_list_sheet.dart' show HeroLogo;

/// Floating profile card shown when a marker is tapped. Slides in
/// just above the bottom sheet's resting handle, dismissed by tapping
/// the map (handled by `MapOptions.onTap`) or the close X.
class SelectedGymCard extends ConsumerWidget {
  const SelectedGymCard({
    super.key,
    required this.gym,
    required this.distanceMeters,
    required this.onTap,
    required this.onClose,
  });

  final GymSummary gym;
  final double? distanceMeters;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final name = isAr && gym.nameAr.isNotEmpty ? gym.nameAr : gym.nameEn;
    final tier = gym.tier == null ? null : GPTier.byKey(gym.tier!);
    // Untiered gyms render with a neutral grey, not brand amber —
    // see the matching note in `GymPinMarker`. The tier accent is
    // a load-bearing colour cue, so we don't fake it for partners
    // who haven't set a `required_tier`.
    final accent = tier?.color ?? gp.muted;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        // Slide in from below + fade. Captures the "card popped up
        // from the marker" feel.
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 24),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GPRadius.lg),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: gp.bg2.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(GPRadius.lg),
              border: Border.all(color: gp.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: GPText.body(
                          size: 16,
                          color: gp.fg,
                          weight: FontWeight.w700,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (distanceMeters != null) ...[
                            Icon(Icons.directions_walk,
                                size: 13, color: gp.mutedSoft,),
                            const SizedBox(width: 4),
                            Text(
                              formatDistance(distanceMeters!, l),
                              style: GPText.body(
                                size: 12,
                                color: gp.mutedSoft,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (gym.area != null && gym.area!.isNotEmpty) ...[
                            Icon(Icons.place_outlined,
                                size: 13, color: gp.mutedSoft,),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                gym.area!,
                                style: GPText.body(
                                  size: 12,
                                  color: gp.mutedSoft,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (gym.category != null &&
                          gym.category!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          localizedCategory(l, gym.category!),
                          style: GPText.body(size: 12, color: gp.mutedSoft),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                HeroLogo(gym: gym, gp: gp, accent: accent),
                IconButton(
                  iconSize: 18,
                  splashRadius: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: gp.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
