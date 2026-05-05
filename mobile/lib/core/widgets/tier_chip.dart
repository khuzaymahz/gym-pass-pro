import 'package:flutter/material.dart';

import '../theme/gp_text.dart';
import '../theme/gp_tokens.dart';

class TierChip extends StatelessWidget {
  final GPTier tier;
  final double fontSize;

  const TierChip({super.key, required this.tier, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final ink = tier.readableOn(gp);
    final fillTier = tier.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 1.0,
        vertical: fontSize * 0.5,
      ),
      decoration: BoxDecoration(
        color: fillTier.withValues(alpha: 0.14),
        border: Border.all(color: fillTier.withValues(alpha: 0.44)),
        borderRadius: BorderRadius.circular(GPRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tier.glyph, style: TextStyle(color: ink, fontSize: fontSize + 2, height: 1)),
          const SizedBox(width: 6),
          Text(
            tier.name.toUpperCase(),
            style: GPText.mono(
              size: fontSize,
              weight: FontWeight.w600,
              letterSpacing: fontSize * 0.12,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}
