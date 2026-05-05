import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/wordmark_refresh.dart';
import '../../../l10n/app_localizations.dart';
import '../../subscription/data/subscription_state.dart';
import '../data/billing_state.dart';
import '../../../core/widgets/skeleton.dart';
import 'widgets/add_method_sheet.dart';
import 'widgets/invoice_tile.dart';
import 'widgets/next_charge_card.dart';
import 'widgets/payment_method_tile.dart';
import 'widgets/receipt_sheet.dart';
import 'widgets/remove_method_dialog.dart';

/// Billing page — composition root. Each block (next-charge card, methods
/// list, add sheet, invoice history, receipt sheet) lives in its own
/// widget. This file only wires state → widgets and routes user
/// intents back into the `billingProvider` notifier.
class BillingPage extends ConsumerWidget {
  const BillingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final billing = ref.watch(billingProvider);
    final sub = ref.watch(subscriptionProvider);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Scaffold(
      body: Stack(
        children: [
          WordmarkRefresh(
            onRefresh: () => ref.read(subscriptionProvider.notifier).ready,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 32),
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Overline(l.billingOverline)],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  DisplayText(l.billingHeadline, size: 36),
                  const SizedBox(width: 10),
                  SerifAccent(l.billingHeadlineAccent, size: 36),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l.billingBlurb,
                style: GPText.body(size: 14, color: gp.mutedSoft),
              ),
              const SizedBox(height: 22),
              NextChargeCard(
                renewIso: sub.renewIso!,
                amountJod: sub.tier!.price,
              ),
              const SizedBox(height: 22),
              _SectionLabel(l.billingMethodsLabel),
              const SizedBox(height: 10),
              _MethodsList(
                billing: billing,
                onSetDefault: (id) => _setDefault(context, ref, l, id),
                onRemove: (m) => _remove(context, ref, l, m),
              ),
              const SizedBox(height: 14),
              PillButton(
                label: l.billingAddMethod,
                leadingIcon: Icons.add,
                variant: PillVariant.secondary,
                onPressed: () => _openAddSheet(context, ref),
              ),
              const SizedBox(height: 22),
              _SectionLabel(l.billingHistoryLabel),
              const SizedBox(height: 10),
              _HistoryList(
                billing: billing,
                onOpenInvoice: (inv) => _openReceipt(context, l, inv),
              ),
              ],
            ),
          ),
          PositionedDirectional(
            top: topInset + 12,
            start: 20,
            child: const BackBtn(fallback: '/profile'),
          ),
        ],
      ),
    );
  }

  Future<void> _setDefault(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    String id,
  ) async {
    await ref.read(billingProvider.notifier).setDefault(id);
    if (!context.mounted) return;
    _snack(context, l.billingDefaultUpdated);
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    PaymentMethod m,
  ) async {
    final confirmed = await RemoveMethodDialog.confirm(context, m);
    if (!confirmed) return;
    await ref.read(billingProvider.notifier).removeMethod(m.id);
    if (!context.mounted) return;
    _snack(context, l.billingMethodRemoved);
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    await showAddMethodSheet(
      context: context,
      ref: ref,
      onAdded: (msg) {
        if (!context.mounted) return;
        _snack(context, msg);
      },
    );
  }

  Future<void> _openReceipt(
    BuildContext context,
    AppLocalizations l,
    Invoice invoice,
  ) async {
    await ReceiptSheet.show(
      context: context,
      invoice: invoice,
      onEmailQueued: () {
        if (!context.mounted) return;
        _snack(context, l.billingReceiptEmailQueued);
      },
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Text(
      text,
      style: GPText.mono(size: 10, letterSpacing: 1.8, color: gp.muted),
    );
  }
}

class _MethodsList extends StatelessWidget {
  const _MethodsList({
    required this.billing,
    required this.onSetDefault,
    required this.onRemove,
  });

  final BillingState billing;
  final void Function(String id) onSetDefault;
  final void Function(PaymentMethod method) onRemove;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    // Skeleton swap during pull-to-refresh — preserves the row
    // count (or shows a sensible 2 if the member has none yet)
    // so the page below doesn't shift.
    if (RefreshScope.of(context)) {
      final n = billing.methods.length.clamp(2, 4);
      return Column(
        children: [
          for (var i = 0; i < n; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: SkeletonMethodTile(),
            ),
        ],
      );
    }
    if (billing.methods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: gp.bg2,
          borderRadius: BorderRadius.circular(GPRadius.lg),
          border: Border.all(color: gp.line),
        ),
        child: Text(
          l.billingMethodsEmpty,
          style: GPText.body(size: 14, color: gp.mutedSoft),
        ),
      );
    }
    return Column(
      children: [
        for (final m in billing.methods)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PaymentMethodTile(
              method: m,
              isDefault: billing.defaultMethodId == m.id,
              onSetDefault: () => onSetDefault(m.id),
              onRemove: () => onRemove(m),
            ),
          ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.billing,
    required this.onOpenInvoice,
  });

  final BillingState billing;
  final void Function(Invoice invoice) onOpenInvoice;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    if (RefreshScope.of(context)) {
      final n = billing.invoices.length.clamp(3, 5);
      return Container(
        decoration: BoxDecoration(
          color: gp.bg2,
          borderRadius: BorderRadius.circular(GPRadius.lg),
          border: Border.all(color: gp.line),
        ),
        child: Column(
          children: [
            for (var i = 0; i < n; i++)
              SkeletonInvoiceRow(showDivider: i < n - 1),
          ],
        ),
      );
    }
    if (billing.invoices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: gp.bg2,
          borderRadius: BorderRadius.circular(GPRadius.lg),
          border: Border.all(color: gp.line),
        ),
        child: Text(
          l.billingHistoryEmpty,
          style: GPText.body(size: 14, color: gp.mutedSoft),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        children: [
          for (var i = 0; i < billing.invoices.length; i++)
            InvoiceTile(
              invoice: billing.invoices[i],
              showDivider: i < billing.invoices.length - 1,
              onTap: () => onOpenInvoice(billing.invoices[i]),
            ),
        ],
      ),
    );
  }
}
