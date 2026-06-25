import 'package:flutter/material.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// Custom CTA for the day-pass purchase entry. Different shape from
/// the platform-wide `PillButton` because it carries a secondary
/// subtitle — the buyer needs to know they're buying a 24-hour
/// one-off, not a subscription. Visually the lime-on-ink fill
/// matches the brand accent and signals "this is a paid action,
/// not navigation".
class DayPassCta extends StatefulWidget {
  const DayPassCta({
    super.key,
    required this.priceJod,
    required this.validityHours,
    required this.onPressed,
  });

  final double priceJod;
  final int validityHours;
  final VoidCallback? onPressed;

  @override
  State<DayPassCta> createState() => _DayPassCtaState();
}

class _DayPassCtaState extends State<DayPassCta> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final disabled = widget.onPressed == null;
    final priceStr = _formatJodPriceStandalone(widget.priceJod);
    return AnimatedScale(
      scale: (_pressed && !disabled) ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GPRadius.pill),
          onTap: widget.onPressed,
          onHighlightChanged: _setPressed,
          child: Container(
            height: 64,
            padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 22, 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [GP.limeHi, GP.lime],
              ),
              borderRadius: BorderRadius.circular(GPRadius.pill),
              boxShadow: [
                BoxShadow(
                  color: GP.lime.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: GP.ink.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.confirmation_number_outlined,
                    color: GP.ink,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.gymDayPassCta(priceStr),
                        style: GPText.body(
                          size: 15,
                          color: GP.ink,
                          weight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Subtitle is the validity hint cropped to its
                      // first sentence ("Valid for 24 hours after
                      // purchase.") — the second clause about
                      // non-rollover lives in the buy-sheet; the
                      // CTA only needs the headline reassurance.
                      Text(
                        l
                            .dayPassSheetValidity(widget.validityHours)
                            .split('.')
                            .first
                            .trim(),
                        style: GPText.body(
                          size: 11,
                          color: GP.ink.withValues(alpha: 0.62),
                          height: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward,
                  color: GP.ink,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatJodPriceStandalone(double amount) {
  if (amount % 1 == 0) return amount.toStringAsFixed(0);
  return amount.toStringAsFixed(2);
}
