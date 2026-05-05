import 'package:flutter/material.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';

class NextChargeCard extends StatelessWidget {
  const NextChargeCard({
    super.key,
    required this.renewIso,
    required this.amountJod,
  });

  final String renewIso;
  final int amountJod;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GP.lime22,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.accentInk.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gp.accentInk.withValues(alpha: 0.18),
              border: Border.all(
                color: gp.accentInk.withValues(alpha: 0.45),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.schedule, color: gp.accentInk, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.billingNextChargeLabel,
                  style: GPText.mono(
                    size: 10,
                    letterSpacing: 1.6,
                    color: gp.mutedSoft,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.billingNextChargeBody(renewIso, amountJod),
                  style: GPText.body(
                    size: 15,
                    color: gp.fg,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
