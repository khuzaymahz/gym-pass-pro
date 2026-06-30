import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/gp_scaffold.dart';
import '../../../core/widgets/help_button.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/top_bounce_physics.dart';
import '../../../core/widgets/wordmark_refresh.dart';
import '../../../l10n/app_localizations.dart';
import '../../day_pass/data/day_pass.dart';
import '../../day_pass/data/day_pass_repository.dart';
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
class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key});

  @override
  ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(billingProvider).loaded) {
        ref.read(billingProvider.notifier).refreshFromBackend();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final billing = ref.watch(billingProvider);
    final sub = ref.watch(subscriptionProvider);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return GpScaffold(
      tips: [
        HelpTip(icon: Icons.credit_card_outlined, text: l.helpBilling1),
        HelpTip(icon: Icons.receipt_long, text: l.helpBilling2),
        HelpTip(icon: Icons.error_outline, text: l.helpBilling3),
      ],
      body: Stack(
        children: [
          WordmarkRefresh(
            // Real refresh — re-fetches both the active subscription
            // (drives the header's tier chip + renewal date) and the
            // billing state (saved methods, invoice history). The
            // previous implementation awaited `.ready`, which after
            // the first hydrate is a resolved future and a no-op, so
            // the gesture appeared to work but the page never
            // actually re-fetched anything.
            onRefresh: () => Future.wait([
              ref
                  .read(subscriptionProvider.notifier)
                  .refreshFromBackend(throwOnError: true),
              ref.read(billingProvider.notifier).refreshFromBackend(),
            ]),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: TopBouncePhysics(),
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
              if (sub.hasSubscription &&
                  sub.renewIso != null &&
                  sub.tier != null)
                NextChargeCard(
                  renewIso: sub.renewIso!,
                  amountJod: sub.tier!.price,
                )
              else
                _NoActiveSubscriptionCard(),
              const SizedBox(height: 22),
              _SectionLabel(l.billingMethodsLabel),
              const SizedBox(height: 10),
              _MethodsList(
                billing: billing,
                onSetDefault: (id) => _setDefault(context, l, id),
                onRemove: (m) => _remove(context, l, m),
              ),
              const SizedBox(height: 14),
              PillButton(
                label: l.billingAddMethod,
                leadingIcon: Icons.add,
                variant: PillVariant.secondary,
                onPressed: () => _openAddSheet(context),
              ),
              const SizedBox(height: 22),
              _SectionLabel(l.billingHistoryLabel),
              const SizedBox(height: 10),
              _HistoryList(
                billing: billing,
                onOpenInvoice: (inv) => _openReceipt(context, inv),
              ),
              const _DayPassReceiptsSection(),
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
    AppLocalizations l,
    String id,
  ) async {
    await ref.read(billingProvider.notifier).setDefault(id);
    if (!context.mounted) return;
    _snack(context, l.billingDefaultUpdated);
  }

  Future<void> _remove(
    BuildContext context,
    AppLocalizations l,
    PaymentMethod m,
  ) async {
    final confirmed = await RemoveMethodDialog.confirm(context, m);
    if (!confirmed) return;
    await ref.read(billingProvider.notifier).removeMethod(m.id);
    if (!context.mounted) return;
    _snack(context, l.billingMethodRemoved);
  }

  Future<void> _openAddSheet(BuildContext context) async {
    await showAddMethodSheet(
      context: context,
      ref: ref,
      onAdded: (msg) {
        if (!context.mounted) return;
        _snack(context, msg);
      },
    );
  }

  Future<void> _openReceipt(BuildContext context, Invoice invoice) async {
    await ReceiptSheet.show(context: context, invoice: invoice);
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(duration: const Duration(seconds: 4), content: Text(message)));
  }
}

/// Empty-state card shown on Billing when the member has no active
/// subscription. Replaces the [NextChargeCard] (which would otherwise
/// dereference null `renewIso` / `tier`). Saved methods + invoice
/// history below still render normally — a member can keep cards on
/// file even without a live subscription.
class _NoActiveSubscriptionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.billingNoSubscriptionTitle,
            style: GPText.body(
              size: 15,
              color: gp.fg,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.billingNoSubscriptionBlurb,
            style: GPText.body(size: 13, color: gp.mutedSoft, height: 1.4),
          ),
          const SizedBox(height: 14),
          PillButton(
            label: l.billingNoSubscriptionCta,
            trailingIcon: Icons.arrow_forward,
            variant: PillVariant.secondary,
            onPressed: () => context.push('/subscription'),
          ),
        ],
      ),
    );
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

class _DayPassReceiptsSection extends ConsumerWidget {
  const _DayPassReceiptsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final passes = ref.watch(myDayPassesProvider).valueOrNull ?? const <DayPass>[];
    if (passes.isEmpty) return const SizedBox.shrink();

    final sorted = [...passes]
      ..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        _SectionLabel(l.billingDayPassesLabel),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(color: gp.line),
            boxShadow: gp.cardShadows,
          ),
          child: Column(
            children: [
              for (var i = 0; i < sorted.length; i++)
                _DayPassReceiptTile(
                  pass: sorted[i],
                  showDivider: i < sorted.length - 1,
                  isAr: Localizations.localeOf(context).languageCode == 'ar',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayPassReceiptTile extends StatelessWidget {
  const _DayPassReceiptTile({
    required this.pass,
    required this.showDivider,
    required this.isAr,
  });

  final DayPass pass;
  final bool showDivider;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    final isActive = pass.isActive(DateTime.now().toUtc());
    final isUsed = pass.status == 'used';
    final statusColor = isActive ? GP.lime : isUsed ? GP.success : gp.muted;
    final statusLabel = isActive
        ? l.gymDayPassCtaLabel
        : isUsed
            ? l.profileDayPassUsed(_formatDate(pass.usedAt ?? pass.expiresAt))
            : l.dayPassStatusExpired;
    final dateStr = _formatDate(pass.purchasedAt);
    final priceStr = pass.priceJod == pass.priceJod.truncateToDouble()
        ? '${pass.priceJod.toInt()} ${l.currencyJod}'
        : '${pass.priceJod.toStringAsFixed(2)} ${l.currencyJod}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              color: GP.lime.withValues(alpha: 0.14),
              border: Border.all(color: GP.lime.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.local_activity_outlined, size: 18, color: GP.lime),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pass.name,
                  style: GPText.body(
                    size: 13,
                    color: gp.fg,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr · $priceStr',
                  style: GPText.body(size: 12, color: gp.mutedSoft),
                ),
              ],
            ),
          ),
          Text(
            statusLabel.toUpperCase(),
            style: GPText.mono(
              size: 9,
              letterSpacing: 1.3,
              color: statusColor,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
