import 'package:flutter/material.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/billing_state.dart';

class InvoiceTile extends StatelessWidget {
  const InvoiceTile({
    super.key,
    required this.invoice,
    required this.showDivider,
    required this.onTap,
  });

  final Invoice invoice;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: showDivider
                  ? BorderSide(color: gp.line)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: GP.success.withValues(alpha: 0.14),
                  border: Border.all(
                    color: GP.success.withValues(alpha: 0.4),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.check, size: 18, color: GP.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.id,
                      style: GPText.mono(
                        size: 11,
                        letterSpacing: 1.2,
                        color: gp.fg,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.billingInvoicePaid(invoice.iso, invoice.amountJod),
                      style: GPText.body(size: 13, color: gp.mutedSoft),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.billingInvoiceReceipt.toUpperCase(),
                    style: GPText.mono(
                      size: 10,
                      letterSpacing: 1.3,
                      color: gp.accentInk,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.download,
                    size: 14,
                    color: gp.accentInk,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
