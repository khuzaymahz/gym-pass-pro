import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money_format.dart';
import '../../../core/network/network_error.dart';
import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/gym_loader.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/tier_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../../billing/data/billing_state.dart';
import '../../billing/presentation/widgets/add_method_sheet.dart';
import '../../billing/presentation/widgets/method_icon.dart';
import '../data/plan_pricing.dart';
import '../data/subscription_state.dart';
import 'plans_page.dart';

/// Translates a thrown error from the checkout/purchase flow into a
/// localized snackbar message. Routed through the central network
/// classifier so transport faults reliably surface as "check your
/// connection" while gateway / validation rejections collapse to the
/// generic snack — we never leak a raw `DioException [unknown]: null`.
String _resolveCheckoutError(Object e, AppLocalizations l) {
  return resolveErrorMessage(e, l);
}

/// Selected saved-method id for this checkout. Cleared between checkouts by
/// resetting on the welcome page; auto-initialized from the member's default
/// method in the picker.
final selectedMethodIdProvider = StateProvider<String?>((_) => null);

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key, this.isRenewal = false});

  /// True when the page was entered via "Renew now" from My Subscription.
  /// The member keeps the same tier and duration but forfeits the current
  /// term's remaining days in exchange for a fresh billing period — so no
  /// extension credit applies and the pay action resets the term instead of
  /// extending or activating.
  final bool isRenewal;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  /// True from the moment the member taps "Pay" until the backend
  /// returns (success → navigate to /welcome, or error → snackbar).
  /// While set, the page paints a full-screen overlay with the
  /// `GymLoader` and a "Processing payment…" caption. The overlay
  /// captures all input so members can't double-tap Pay or back-out
  /// of the page mid-network — the previous freeze had no visible
  /// indicator and looked like the app had hung.
  bool _isPaying = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selectedKey = ref.watch(selectedTierProvider);
    final durationMonths = ref.watch(selectedDurationProvider);
    final sub = ref.watch(subscriptionProvider);
    final currentTier = sub.tier;
    // Selection takes priority (the user just tapped a card on /plans).
    // If the user reached checkout via "Upgrade" they may not have re-selected,
    // in which case we fall back to the current tier. For a brand-new member
    // with no current tier and no selection, we default to the entry tier
    // from the design system's ordered list so the summary card is never blank.
    final tier = selectedKey != null
        ? GPTier.byKey(selectedKey)
        : (currentTier ?? GPTier.all.first);
    final billing = ref.watch(billingProvider);
    final selectedId = ref.watch(selectedMethodIdProvider);
    final resolvedMethod = _resolve(billing, selectedId);
    // Extension mode: same tier, longer duration than the active term. The
    // member is topping up an in-flight plan, so the displayed total is the
    // delta (new-total minus what they already paid for the current term).
    final currentDuration = sub.durationMonths ?? 0;
    // Renewal forces a fresh term on the same tier, so it is explicitly not
    // an extension even when tier + duration match the current plan.
    final isExtension = !widget.isRenewal &&
        sub.hasSubscription &&
        currentTier != null &&
        tier.key == currentTier.key &&
        durationMonths > currentDuration;
    // Subtotal = monthly × duration. Discount is subtracted as a separate line
    // so the user sees exactly what they save by committing longer. Tax then
    // applies to the discounted amount (same order the gateway will use).
    final discountPercent = discountPercentForDuration(durationMonths);
    final gross = tier.price * durationMonths;
    final discount = gross - totalPriceForDuration(tier.price, durationMonths);
    final currentCredit = isExtension
        ? totalPriceForDuration(tier.price, currentDuration)
        : 0;
    final discountedSubtotal = gross - discount - currentCredit;
    final tax = (discountedSubtotal * 0.16).round();
    final total = discountedSubtotal + tax;
    final canPay = resolvedMethod != null;
    final projectedRenew =
        isExtension ? sub.projectedRenewIso(durationMonths) : null;

    // Block the back gesture / system back button while a payment
    // is in flight — the network call has already been issued and
    // the member won't get a clean cancel by exiting the page; the
    // loader overlay is the visible "wait, this is happening"
    // signal.
    return PopScope(
      canPop: !_isPaying,
      child: Scaffold(
        body: SafeArea(
          minimum: const EdgeInsets.only(bottom: 8),
          child: Stack(
            children: [
              Column(
                children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  // BackBtn is hidden mid-payment — `PopScope` blocks the
                  // system-back gesture but the visible widget calls
                  // `Navigator.pop()` directly, which would skip the gate
                  // and leave the page mid-charge. Replacing it with an
                  // empty 40-px spacer keeps the title row balanced.
                  if (_isPaying)
                    const SizedBox(width: 40)
                  else
                    const BackBtn(),
                  const Spacer(),
                  Overline(l.checkoutOverline),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  DisplayText(l.checkoutTitle, size: 36),
                  const SizedBox(width: 10),
                  SerifAccent(l.checkoutTitleAccent, size: 36),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  _tierSummary(
                    context,
                    tier,
                    durationMonths,
                    l,
                    isExtension: isExtension,
                    projectedRenewIso: projectedRenew,
                  ),
                  const SizedBox(height: 16),
                  _methodPicker(context, ref, billing, resolvedMethod, l),
                  const SizedBox(height: 16),
                  _totals(
                    context,
                    gross,
                    discount,
                    discountPercent,
                    currentCredit,
                    tax,
                    total,
                    tier.readableOn(context.gp),
                    l,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Column(
                children: [
                  if (!canPay) ...[
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: GP.danger,),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(l.errorPaymentMethod,
                              style: GPText.body(size: 12, color: GP.danger),),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  PillButton(
                    label: l.checkoutPayAmount(total),
                    trailingIcon: Icons.arrow_forward,
                    onPressed: (canPay && !_isPaying)
                        ? () => _onPay(
                              context,
                              ref,
                              tier,
                              durationMonths,
                              total,
                              resolvedMethod,
                              isExtension: isExtension,
                              isRenewal: widget.isRenewal,
                            )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
              if (_isPaying) _PayingOverlay(label: l.checkoutPayingOverlay),
            ],
          ),
        ),
      ),
    );
  }

  /// Matches the persisted selection back to a concrete method; returns null
  /// if the stored id was removed between sessions or nothing is selected yet.
  PaymentMethod? _resolve(BillingState billing, String? selectedId) {
    if (billing.methods.isEmpty) return null;
    final id = selectedId ?? billing.defaultMethodId;
    if (id == null) return billing.methods.first;
    for (final m in billing.methods) {
      if (m.id == id) return m;
    }
    return billing.methods.first;
  }

  Future<void> _onPay(
    BuildContext context,
    WidgetRef ref,
    GPTier tier,
    int durationMonths,
    int total,
    PaymentMethod? selectedMethod, {
    required bool isExtension,
    required bool isRenewal,
  }) async {
    if (_isPaying) return;
    setState(() => _isPaying = true);
    final sub = ref.read(subscriptionProvider.notifier);
    final billing = ref.read(billingProvider.notifier);
    final hasExistingSub = ref.read(subscriptionProvider).hasSubscription;
    // Backend kind: card / cliq / apple_pay / mock. Maps from the local
    // PaymentMethodKind enum so the audit trail records what the gateway
    // actually charged through.
    final paymentKind = _kindFor(selectedMethod);

    try {
      // Renewal / extension / upgrade all collapse to "cancel current,
      // buy fresh" against the backend — the backend doesn't yet support
      // in-place mutations, so a clean replace keeps both halves honest.
      // First-time purchases skip the cancel.
      if (isRenewal || isExtension || hasExistingSub) {
        await sub.replaceWithPurchase(
          tierKey: tier.key,
          durationMonths: durationMonths,
          paymentMethodId: selectedMethod?.id,
          paymentMethodKind: paymentKind,
        );
      } else {
        await sub.purchase(
          tierKey: tier.key,
          durationMonths: durationMonths,
          paymentMethodId: selectedMethod?.id,
          paymentMethodKind: paymentKind,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      // Drop the overlay before showing the snackbar so the member
      // can read it and try again.
      if (mounted) setState(() => _isPaying = false);
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_resolveCheckoutError(e, l))));
      return;
    }
    final now = DateTime.now();
    await billing.recordInvoice(Invoice(
      id: 'INV-${now.millisecondsSinceEpoch}',
      iso: _isoDate(now),
      amountJod: total,
      tierKey: tier.key,
      paid: true,
    ),);
    if (!context.mounted) return;
    // Keep the overlay up through the navigation transition so the
    // page doesn't briefly flash back to the checkout summary before
    // /welcome takes over. The State will dispose with the overlay
    // still flagged true; that's fine — the route swap unmounts the
    // whole page.
    context.go('/welcome');
  }

  /// Map the saved-method kind to the backend's `payment_method_enum`.
  /// Members without a selected method default to `mock` so the dev
  /// gateway accepts the charge — production wiring will gate the
  /// "Pay" button on a real selection.
  String _kindFor(PaymentMethod? m) {
    if (m == null) return 'mock';
    switch (m.kind) {
      case PaymentMethodKind.visa:
      case PaymentMethodKind.mastercard:
        return 'card';
      case PaymentMethodKind.cliq:
        return 'cliq';
      case PaymentMethodKind.applePay:
        return 'apple_pay';
      case PaymentMethodKind.googlePay:
        return 'google_pay';
    }
  }

  String _isoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Widget _tierSummary(
    BuildContext context,
    GPTier tier,
    int durationMonths,
    AppLocalizations l, {
    required bool isExtension,
    String? projectedRenewIso,
  }) {
    final gp = context.gp;
    final durationLabel = _durationLabel(l, durationMonths);
    final accent = tier.readableOn(gp);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.xl),
        border: Border.all(color: tier.color.withValues(alpha: 0.3)),
        boxShadow: gp.cardShadows,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    tier.color.withValues(alpha: 0.22),
                    tier.color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TierChip(tier: tier),
                  if (isExtension) ...[
                    const SizedBox(width: 6),
                    _extensionBadge(l, accent),
                  ],
                  const Spacer(),
                  Text(durationLabel,
                      style: GPText.mono(
                          size: 10, letterSpacing: 1.4, color: gp.mutedSoft,),),
                ],
              ),
              const SizedBox(height: 16),
              Text(tier.name.toUpperCase(),
                  style: GPText.display(38,
                      color: tier.readableOn(gp), height: 0.9,),),
              const SizedBox(height: 10),
              Text(
                '${tier.visits} ${l.homeVisits}',
                style: GPText.body(size: 13, color: gp.mutedSoft),
              ),
              if (isExtension && projectedRenewIso != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      l.checkoutExtensionRenewsOn,
                      style: GPText.mono(
                        size: 10,
                        letterSpacing: 1.6,
                        color: gp.muted,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      projectedRenewIso,
                      style: GPText.mono(
                        size: 11,
                        letterSpacing: 1.2,
                        color: accent,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _extensionBadge(AppLocalizations l, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(GPRadius.sm),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Text(
        l.checkoutExtensionBadge,
        style: GPText.mono(
          size: 9,
          letterSpacing: 1.4,
          color: accent,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _methodPicker(
    BuildContext context,
    WidgetRef ref,
    BillingState billing,
    PaymentMethod? resolved,
    AppLocalizations l,
  ) {
    final gp = context.gp;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.checkoutPaymentMethod,
              style: GPText.mono(
                  size: 10, letterSpacing: 1.8, color: gp.muted,),),
          const SizedBox(height: 10),
          if (billing.methods.isEmpty)
            _emptyState(context, ref, l, gp)
          else ...[
            for (final m in billing.methods)
              _methodRow(context, ref, m, resolved?.id == m.id, l, gp),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _openAddSheet(context, ref, l),
                icon: Icon(Icons.add, size: 16, color: gp.accentInk),
                label: Text(
                  l.checkoutAddAnother,
                  style: GPText.mono(
                    size: 11,
                    letterSpacing: 1.4,
                    color: gp.accentInk,
                    weight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    GpColors gp,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            l.checkoutNoMethodsHint,
            style: GPText.body(size: 13, color: gp.mutedSoft),
          ),
        ),
        const SizedBox(height: 6),
        PillButton(
          label: l.checkoutAddPaymentMethod,
          trailingIcon: Icons.add,
          onPressed: () => _openAddSheet(context, ref, l),
        ),
      ],
    );
  }

  Widget _methodRow(
    BuildContext context,
    WidgetRef ref,
    PaymentMethod m,
    bool selected,
    AppLocalizations l,
    GpColors gp,
  ) {
    final networkName = methodNetworkName(
      m.kind,
      l.billingCardNetworkVisa,
      l.billingCardNetworkMastercard,
      l.billingCardNetworkCliq,
      l.billingCardNetworkApple,
      l.billingCardNetworkGoogle,
    );
    final subtitle = m.last4.isNotEmpty ? '$networkName · ${m.last4}' : networkName;
    return GestureDetector(
      onTap: () =>
          ref.read(selectedMethodIdProvider.notifier).state = m.id,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? GP.lime22 : gp.bg,
          borderRadius: BorderRadius.circular(GPRadius.md),
          border: Border.all(
            color: selected ? gp.accentInk.withValues(alpha: 0.55) : gp.line,
          ),
        ),
        child: Row(
          children: [
            Icon(MethodIcon.of(m.kind),
                size: 18, color: selected ? gp.accentInk : gp.fg,),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.label,
                    style: GPText.body(
                        size: 14, color: gp.fg, weight: FontWeight.w500,),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GPText.mono(
                      size: 10,
                      letterSpacing: 1.1,
                      color: gp.mutedSoft,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? gp.accentInk : gp.line2, width: 1.4,),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: gp.accentInk, shape: BoxShape.circle,),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddSheet(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final before = ref.read(billingProvider).methods.map((m) => m.id).toSet();
    await showAddMethodSheet(
      context: context,
      ref: ref,
      onAdded: (msg) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      },
    );
    // Auto-select the newly added method so the pay button activates without
    // a second tap. Identifying it by id-set diff keeps the logic robust if
    // the sheet is ever extended to add multiple at once.
    final after = ref.read(billingProvider).methods;
    for (final m in after) {
      if (!before.contains(m.id)) {
        ref.read(selectedMethodIdProvider.notifier).state = m.id;
        break;
      }
    }
  }

  Widget _totals(
    BuildContext context,
    int subtotal,
    int discount,
    int discountPercent,
    int currentCredit,
    int tax,
    int total,
    Color accent,
    AppLocalizations l,
  ) {
    final gp = context.gp;
    Widget row(String label, String value,
        {bool strong = false, Color? valueColor,}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(label.toUpperCase(),
                style: GPText.mono(
                    size: 10, letterSpacing: 1.4, color: gp.mutedSoft,),),
            const Spacer(),
            Text(
              value,
              style: strong
                  ? GPText.display(22, color: valueColor ?? gp.fg, height: 1)
                  : GPText.body(size: 14, color: gp.fg, weight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        children: [
          row(l.checkoutSubtotal, MoneyFormat.jod(l, subtotal)),
          if (discount > 0)
            row(l.checkoutDiscount(discountPercent),
                '-${MoneyFormat.jod(l, discount)}',
                valueColor: accent,),
          if (currentCredit > 0)
            row(l.checkoutCurrentPlanCredit,
                '-${MoneyFormat.jod(l, currentCredit)}',
                valueColor: accent,),
          row(l.checkoutTax, MoneyFormat.jod(l, tax)),
          const SizedBox(height: 4),
          Container(height: 1, color: gp.line),
          const SizedBox(height: 4),
          row(l.checkoutTotal, MoneyFormat.jod(l, total),
              strong: true, valueColor: accent,),
        ],
      ),
    );
  }

  String _durationLabel(AppLocalizations l, int months) {
    switch (months) {
      case 12:
        return l.checkoutDurationYear;
      case 1:
        return l.checkoutOneMonth;
      default:
        return l.checkoutDurationSummary(months);
    }
  }
}

/// Full-screen modal-style overlay that paints over the checkout
/// content while the payment network call is in flight. The
/// `GymLoader` carries the visual; the caption gives the member
/// explicit "we're processing your payment, don't navigate away"
/// language so the freeze reads as deliberate work, not as the app
/// hanging. Sits above all interactive widgets — taps, drags, and
/// the system back gesture (gated separately by `PopScope`) all
/// land here and do nothing, which is the correct behaviour while
/// the gateway is mid-charge.
class _PayingOverlay extends StatelessWidget {
  const _PayingOverlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: gp.bg.withValues(alpha: 0.85),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GymLoader(size: GymLoaderSize.large),
              const SizedBox(height: 18),
              Text(
                label,
                style: GPText.mono(
                  size: 11,
                  letterSpacing: 1.8,
                  color: gp.fg,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
