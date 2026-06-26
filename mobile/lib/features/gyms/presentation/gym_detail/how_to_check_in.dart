import 'package:flutter/material.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import 'gym_detail_helpers.dart';

/// "How to check in" — the three-step QR flow, with a leading note
/// when the gym is still locked (so the steps don't read as if the
/// member can scan in right now when they actually need to unlock
/// first).
class HowToCheckIn extends StatelessWidget {
  const HowToCheckIn({super.key, required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    final steps = [l.gymHowToStep1, l.gymHowToStep2, l.gymHowToStep3];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(gp, l.gymHowToTitle),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.md),
            border: Border.all(color: gp.line2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (locked) ...[
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: gp.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.gymHowToUnlockSub,
                        style: GPText.body(
                          size: 12,
                          color: gp.mutedSoft,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _step(gp, i + 1, steps[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _step(GpColors gp, int n, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: gp.accentInk.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: gp.accentInk.withValues(alpha: 0.35)),
          ),
          child: Text(
            '$n',
            style: GPText.mono(
              size: 11,
              color: gp.accentInk,
              weight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GPText.body(size: 13, color: gp.fg, height: 1.35),
          ),
        ),
      ],
    );
  }
}
