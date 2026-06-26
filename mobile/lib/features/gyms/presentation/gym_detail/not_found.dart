import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../core/widgets/icon_btn.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../../../l10n/app_localizations.dart';

class NotFound extends StatelessWidget {
  const NotFound({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: gp.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_outlined, size: 56, color: gp.muted),
                  const SizedBox(height: 16),
                  Text(
                    l.gymNotFoundTitle,
                    textAlign: TextAlign.center,
                    style: GPText.display(24, color: gp.fg, height: 1.0),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.gymNotFoundBody(slug),
                    textAlign: TextAlign.center,
                    style: GPText.body(
                      size: 14,
                      color: gp.mutedSoft,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  PillButton(
                    label: l.gymNotFoundBackToExplore,
                    trailingIcon: Icons.arrow_forward,
                    onPressed: () => context.go('/explore'),
                  ),
                ],
              ),
            ),
            const PositionedDirectional(
              top: 12,
              start: 20,
              child: BackBtn(fallback: '/explore'),
            ),
          ],
        ),
      ),
    );
  }
}
