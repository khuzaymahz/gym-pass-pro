import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../theme/gp_text.dart';
import '../theme/gp_tokens.dart';
import '../../l10n/app_localizations.dart';

/// Floating (?) help button. Place it inside a [Stack] with
/// [Positioned] to anchor it to the bottom-right of a screen,
/// above the system home indicator.
///
/// Tapping opens a scrollable bottom sheet listing plain-language
/// tips for the current screen. All copy comes from [AppLocalizations]
/// so it localises automatically.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.tips});

  final List<HelpTip> tips;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showSheet(context, gp);
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: gp.bg2,
          shape: BoxShape.circle,
          border: Border.all(color: gp.line2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '?',
            style: GPText.mono(
              size: 14,
              color: gp.accentInk,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  void _showSheet(BuildContext context, GpColors gp) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HelpSheet(tips: tips, l: l, gp: gp),
    );
  }
}

class HelpTip {
  const HelpTip({required this.icon, required this.text});
  final IconData icon;
  final String text;
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet({
    required this.tips,
    required this.l,
    required this.gp,
  });

  final List<HelpTip> tips;
  final AppLocalizations l;
  final GpColors gp;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        12, 0, 12, 12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.xl2),
        border: Border.all(color: gp.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: gp.line2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  l.helpSheetTitle.toUpperCase(),
                  style: GPText.mono(
                    size: 11,
                    letterSpacing: 1.8,
                    color: gp.accentInk,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.42,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: tips
                    .map(
                      (tip) => Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: gp.accentInk.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(tip.icon, size: 16, color: gp.accentInk),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  tip.text,
                                  style: GPText.body(
                                    size: 13,
                                    color: gp.mutedSoft,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: gp.accentInk.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GPRadius.xl),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  l.helpDismiss,
                  style: GPText.mono(
                    size: 12,
                    letterSpacing: 1.4,
                    color: gp.accentInk,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
