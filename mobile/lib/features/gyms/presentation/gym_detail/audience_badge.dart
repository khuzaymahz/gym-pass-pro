import 'package:flutter/material.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// Audience badge — shown above the gym name. Single-sex venues get
/// the loud admin colour language (pink for women-only, blue for
/// men-only); `mixed` gets a calm neutral "Everyone welcome" pill
/// built from theme tokens, so members always see who the gym is for
/// instead of being left guessing on mixed venues.
class AudienceBadge extends StatelessWidget {
  const AudienceBadge({super.key, required this.audience});

  final String audience;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final isMixed = audience == 'mixed';

    // Mixed reads as neutral chrome (muted token), not a warning —
    // it's the open-to-everyone default, just made explicit.
    final Color color;
    final String label;
    final IconData icon;
    switch (audience) {
      case 'mixed':
        color = gp.mutedSoft;
        label = l.audienceMixed;
        icon = Icons.groups_outlined;
      case 'female_only':
        color = const Color(0xFFEC4899);
        label = l.audienceFemaleOnly;
        icon = Icons.female;
      default:
        color = const Color(0xFF60A5FA);
        label = l.audienceMaleOnly;
        icon = Icons.male;
    }
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: isMixed ? gp.bg2 : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(GPRadius.pill),
        border: Border.all(
          color: isMixed ? gp.line2 : color.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: GPText.mono(
              size: 10,
              letterSpacing: 1.2,
              color: color,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
