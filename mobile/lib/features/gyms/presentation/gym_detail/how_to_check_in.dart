import 'package:flutter/material.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import 'gym_detail_helpers.dart';

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
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          decoration: BoxDecoration(
            color: gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.md),
            border: Border.all(color: gp.line2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (locked) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: GP.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(GPRadius.sm),
                    border: Border.all(color: GP.danger.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: GP.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.gymHowToUnlockSub,
                          style: GPText.body(
                            size: 12,
                            color: GP.danger,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Timeline spine
                    Column(
                      children: [
                        for (var i = 0; i < steps.length; i++) ...[
                          _StepBadge(n: i + 1, gp: gp),
                          if (i < steps.length - 1)
                            Expanded(
                              child: Container(
                                width: 1.5,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      gp.accentInk.withValues(alpha: 0.5),
                                      gp.accentInk.withValues(alpha: 0.15),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Step texts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < steps.length; i++)
                            _StepText(
                              text: steps[i],
                              isLast: i == steps.length - 1,
                              gp: gp,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.n, required this.gp});

  final int n;
  final GpColors gp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gp.accentInk.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: gp.accentInk.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: gp.accentInk.withValues(alpha: 0.25),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Text(
        '$n',
        style: GPText.mono(
          size: 12,
          color: gp.accentInk,
          weight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StepText extends StatelessWidget {
  const _StepText({
    required this.text,
    required this.isLast,
    required this.gp,
  });

  final String text;
  final bool isLast;
  final GpColors gp;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isLast ? null : 54,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          style: GPText.body(
            size: 13,
            color: gp.fg,
            height: 1.4,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
