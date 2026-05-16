import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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

  /// Open the receipt for an invoice in a modal bottom sheet. The
  /// primary CTA is **Download**: it formats the receipt as plain
  /// text (gym + amount + VAT + total + payment ref) and hands it to
  /// the OS share sheet via `share_plus`. The member can then save to
  /// Files, save to Drive, send via WhatsApp, etc. — whatever they
  /// have installed. The previous "Send to email" CTA was a stub
  /// (mocked SMTP never actually sent the mail) so a tap produced a
  /// trust-eroding snackbar with no follow-up. Direct download is
  /// the honest behaviour and works fully offline.
  static Future<void> show({
    required BuildContext context,
    required Invoice invoice,
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
      builder: (sheetCtx) => _ReceiptBody(invoice: invoice),
    );
  }
}

class _ReceiptBody extends StatelessWidget {
  const _ReceiptBody({required this.invoice});

  final Invoice invoice;

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
              label: l.billingReceiptDownload,
              trailingIcon: Icons.file_download_outlined,
              onPressed: () => _downloadReceipt(context, l, subtotal, tax),
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

  /// Format the receipt as plain text and hand it to the OS share
  /// sheet. The user picks the destination — Files, Drive, WhatsApp,
  /// Mail, etc. This is what "Download" actually means on mobile:
  /// not a hidden file in /sdcard/Downloads but an explicit
  /// destination the user controls. Once `share_plus` resolves we
  /// close the sheet so the billing list is the next thing the user
  /// sees, not a stale receipt overlay.
  Future<void> _downloadReceipt(
    BuildContext context,
    AppLocalizations l,
    int subtotal,
    int tax,
  ) async {
    final body = _formatReceiptText(l, subtotal, tax);
    final subject = l.billingReceiptDownloadSubject(invoice.id);
    final navigator = Navigator.of(context);
    try {
      await Share.share(body, subject: subject);
    } finally {
      if (navigator.mounted) navigator.pop();
    }
  }

  String _formatReceiptText(AppLocalizations l, int subtotal, int tax) {
    final total = MoneyFormat.jod(l, invoice.amountJod);
    final lines = <String>[
      'GymPass',
      l.billingReceiptTitle,
      '',
      '${l.billingReceiptItemsLabel.toLowerCase()}: ${invoice.id}',
      l.billingInvoicePaid(invoice.iso, invoice.amountJod),
      '',
      '${l.billingReceiptLineBase}: ${MoneyFormat.jod(l, subtotal)}',
      '${l.billingReceiptLineTax(tax)}: ${MoneyFormat.jod(l, tax)}',
      '${l.billingReceiptTotalLabel}: $total',
    ];
    return lines.join('\n');
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
