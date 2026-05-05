import 'package:flutter/material.dart';

import '../../../../core/format/money_format.dart';
import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../core/widgets/overline.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/billing_state.dart';

const int _vatPercent = 16;

class ReceiptSheet {
  const ReceiptSheet._();

  static Future<void> show({
    required BuildContext context,
    required Invoice invoice,
    required VoidCallback onEmailQueued,
  }) {
    final gp = context.gp;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: gp.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(GPRadius.xl2)),
      ),
      builder: (sheetCtx) =>
          _ReceiptBody(invoice: invoice, onEmailQueued: onEmailQueued),
    );
  }
}

class _ReceiptBody extends StatelessWidget {
  const _ReceiptBody({
    required this.invoice,
    required this.onEmailQueued,
  });

  final Invoice invoice;
  final VoidCallback onEmailQueued;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    final tax = (invoice.amountJod * _vatPercent / 100).round();
    final subtotal = invoice.amountJod - tax;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: gp.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DisplayText(l.billingReceiptTitle, size: 24),
                const Spacer(),
                Text(
                  invoice.id,
                  style: GPText.mono(
                    size: 11,
                    letterSpacing: 1.3,
                    color: gp.muted,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l.billingInvoicePaid(invoice.iso, invoice.amountJod),
              style: GPText.body(size: 13, color: gp.mutedSoft),
            ),
            const SizedBox(height: 18),
            Text(
              l.billingReceiptItemsLabel,
              style: GPText.mono(
                size: 10,
                letterSpacing: 1.6,
                color: gp.muted,
              ),
            ),
            const SizedBox(height: 10),
            _ReceiptLine(
              left: l.billingReceiptLineBase,
              right: MoneyFormat.jod(l, subtotal),
            ),
            const SizedBox(height: 6),
            _ReceiptLine(
              left: l.billingReceiptLineTax(tax),
              right: MoneyFormat.jod(l, tax),
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: gp.line),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  l.billingReceiptTotalLabel,
                  style: GPText.mono(
                    size: 11,
                    letterSpacing: 1.6,
                    color: gp.fg,
                    weight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  MoneyFormat.jod(l, invoice.amountJod),
                  style: GPText.body(
                    size: 18,
                    color: gp.fg,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PillButton(
              label: l.billingReceiptSendEmail,
              trailingIcon: Icons.mail_outline,
              onPressed: () {
                Navigator.of(context).pop();
                onEmailQueued();
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  l.billingReceiptCloseBtn.toUpperCase(),
                  style: GPText.mono(
                    size: 11,
                    letterSpacing: 1.4,
                    color: gp.muted,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            style: GPText.body(
              size: 14,
              color: gp.mutedSoft,
              weight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          right,
          style: GPText.body(
            size: 14,
            color: gp.fg,
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
