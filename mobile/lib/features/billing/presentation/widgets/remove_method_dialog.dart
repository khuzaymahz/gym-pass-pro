import 'package:flutter/material.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/billing_state.dart';

class RemoveMethodDialog {
  const RemoveMethodDialog._();

  static Future<bool> confirm(
    BuildContext context,
    PaymentMethod method,
  ) async {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: gp.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GPRadius.lg),
        ),
        title: Text(
          l.billingRemoveConfirmTitle,
          style:
              GPText.body(size: 18, color: gp.fg, weight: FontWeight.w600),
        ),
        content: Text(
          l.billingRemoveConfirmBody(method.label),
          style: GPText.body(size: 14, color: gp.mutedSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l.cancel.toUpperCase(),
              style: GPText.mono(
                size: 11,
                letterSpacing: 1.4,
                color: gp.fg,
                weight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: GP.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GPRadius.pill),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l.billingRemoveConfirmYes.toUpperCase(),
              style: GPText.mono(
                size: 11,
                letterSpacing: 1.4,
                color: Colors.white,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}
