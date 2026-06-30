import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/network_error.dart';
import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/gym_loader.dart';
import '../../../core/widgets/gym_logo.dart';
import '../../../core/widgets/gp_scaffold.dart';
import '../../../core/widgets/help_button.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../billing/data/billing_state.dart';
import '../../billing/presentation/widgets/add_method_sheet.dart';
import '../../billing/presentation/widgets/method_icon.dart';
import '../data/day_pass.dart';
import '../data/day_pass_repository.dart';

/// Arguments passed from the gym-detail "Day use" banner to the
/// checkout page. Stored in [dayPassCheckoutArgsProvider] so a hot
/// restart doesn't crash on a null GoRouter `extra` cast.
class DayPassCheckoutArgs {
  const DayPassCheckoutArgs({
    required this.gymSlug,
    required this.gymName,
    required this.offering,
    this.gym,
    this.gymLogoUrl,
  });

  final String gymSlug;
  final String gymName;
  final DayPassOffering offering;
  final GPGym? gym;
  final String? gymLogoUrl;
}

final dayPassCheckoutArgsProvider =
    StateProvider<DayPassCheckoutArgs?>((_) => null);

/// Per-session selected method — scoped to day-pass checkout so it
/// doesn't bleed into or from the subscription checkout's own
/// selectedMethodIdProvider.
final _dpMethodIdProvider = StateProvider<String?>((_) => null);

String _fmtJod(double amount) =>
    amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);

class DayPassCheckoutPage extends ConsumerStatefulWidget {
  const DayPassCheckoutPage({super.key});

  @override
  ConsumerState<DayPassCheckoutPage> createState() =>
      _DayPassCheckoutPageState();
}

class _DayPassCheckoutPageState extends ConsumerState<DayPassCheckoutPage> {
  bool _isPaying = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final args = ref.watch(dayPassCheckoutArgsProvider);

    // Guard: args are GC'd on hot restart or stale navigation — pop
    // cleanly rather than rendering a broken empty-state page.
    if (args == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final billing = ref.watch(billingProvider);
    final selectedId = ref.watch(_dpMethodIdProvider);
    final resolved = _resolveMethod(billing, selectedId);
    final isProd = AppEnv.current.isProduction;
    final canPay = resolved != null || !isProd;
    final priceStr = _fmtJod(args.offering.priceJod);

    return PopScope(
      canPop: !_isPaying,
      child: GpScaffold(
        tips: [
          HelpTip(icon: Icons.credit_card_outlined, text: l.helpBilling1),
          HelpTip(icon: Icons.receipt_long, text: l.helpBilling2),
          HelpTip(icon: Icons.error_outline, text: l.helpBilling3),
        ],
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
                        _gymSummaryCard(context, gp, l, args, priceStr),
                        const SizedBox(height: 16),
                        _methodPicker(context, billing, resolved, l, gp),
                        const SizedBox(height: 16),
                        _totalsCard(context, gp, l, args, priceStr),
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
                              const Icon(
                                Icons.info_outline,
                                size: 14,
                                color: GP.danger,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l.errorPaymentMethod,
                                  style: GPText.body(
                                    size: 12,
                                    color: GP.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        PillButton(
                          label: l.dayPassSheetPay(priceStr),
                          trailingIcon: Icons.arrow_forward,
                          onPressed: (canPay && !_isPaying)
                              ? () => _onPay(context, args, resolved)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isPaying)
                _PayingOverlay(label: l.checkoutPayingOverlay),
            ],
          ),
        ),
      ),
    );
  }

  PaymentMethod? _resolveMethod(BillingState billing, String? selectedId) {
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
    DayPassCheckoutArgs args,
    PaymentMethod? method,
  ) async {
    if (_isPaying) return;
    setState(() => _isPaying = true);
    // Capture before any await so the linter is satisfied and the
    // references stay valid even if the widget rebuilds mid-flight.
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dayPassRepositoryProvider).purchase(
            gymSlug: args.gymSlug,
            paymentMethodKind: method?.kind.storageKey ?? 'mock',
            paymentMethodId: method?.id,
          );
      ref.invalidate(myDayPassesProvider);
      if (!mounted) return;
      nav.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(duration: const Duration(seconds: 4), content: Text(l.dayPassPurchasedSnack)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPaying = false);
      final classified = classifyNetworkError(e);
      final msg = classified.apiException?.code == 'DAY_PASS_DUPLICATE_ACTIVE'
          ? l.dayPassDuplicateActive
          : resolveErrorMessage(e, l);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(duration: const Duration(seconds: 4), content: Text(msg)));
    }
  }

  Widget _gymSummaryCard(
    BuildContext context,
    GpColors gp,
    AppLocalizations l,
    DayPassCheckoutArgs args,
    String priceStr,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.xl),
        border: Border.all(color: GP.lime.withValues(alpha: 0.3)),
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
                    GP.lime.withValues(alpha: 0.15),
                    GP.lime.withValues(alpha: 0),
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
                  if (args.gym != null)
                    GymLogo(
                      gym: args.gym!,
                      logoUrl: args.gymLogoUrl,
                      size: 36,
                    )
                  else
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: GP.lime.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(GPRadius.sm),
                      ),
                      child: const Icon(
                        Icons.confirmation_number_outlined,
                        color: GP.lime,
                        size: 18,
                      ),
                    ),
                  const Spacer(),
                  // "DAY USE" badge — mirrors TierChip register in lime
                  // so it reads as a guest-access token, not a tier.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: GP.lime.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(GPRadius.sm),
                      border: Border.all(
                        color: GP.lime.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      l.gymDayPassCtaLabel,
                      style: GPText.mono(
                        size: 9,
                        letterSpacing: 1.4,
                        color: GP.lime,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.dayPassValidityChip(args.offering.validityHours),
                    style: GPText.mono(
                      size: 10,
                      letterSpacing: 1.4,
                      color: gp.mutedSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                args.gymName,
                style: GPText.display(30, color: gp.fg, height: 1.05),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                '$priceStr ${l.currencyJod}',
                style: GPText.body(size: 14, color: gp.mutedSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _methodPicker(
    BuildContext context,
    BillingState billing,
    PaymentMethod? resolved,
    AppLocalizations l,
    GpColors gp,
  ) {
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
          Text(
            l.checkoutPaymentMethod,
            style: GPText.mono(
              size: 10,
              letterSpacing: 1.8,
              color: gp.muted,
            ),
          ),
          const SizedBox(height: 10),
          if (billing.methods.isEmpty)
            _emptyMethodState(context, l, gp)
          else ...[
            for (final m in billing.methods)
              _methodRow(context, m, resolved?.id == m.id, l, gp),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _openAddSheet(context, l),
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

  Widget _emptyMethodState(
    BuildContext context,
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
          onPressed: () => _openAddSheet(context, l),
        ),
      ],
    );
  }

  Widget _methodRow(
    BuildContext context,
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
    final subtitle =
        m.last4.isNotEmpty ? '$networkName · ${m.last4}' : networkName;
    return GestureDetector(
      onTap: () => ref.read(_dpMethodIdProvider.notifier).state = m.id,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? GP.lime22 : gp.bg,
          borderRadius: BorderRadius.circular(GPRadius.md),
          border: Border.all(
            color: selected
                ? gp.accentInk.withValues(alpha: 0.55)
                : gp.line,
          ),
        ),
        child: Row(
          children: [
            Icon(
              MethodIcon.of(m.kind),
              size: 18,
              color: selected ? gp.accentInk : gp.fg,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.label,
                    style: GPText.body(
                      size: 14,
                      color: gp.fg,
                      weight: FontWeight.w500,
                    ),
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
                  color: selected ? gp.accentInk : gp.line2,
                  width: 1.4,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: gp.accentInk,
                          shape: BoxShape.circle,
                        ),
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
    AppLocalizations l,
  ) async {
    final before =
        ref.read(billingProvider).methods.map((m) => m.id).toSet();
    await showAddMethodSheet(
      context: context,
      ref: ref,
      onAdded: (msg) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(duration: const Duration(seconds: 4), content: Text(msg)));
      },
    );
    final after = ref.read(billingProvider).methods;
    for (final m in after) {
      if (!before.contains(m.id)) {
        ref.read(_dpMethodIdProvider.notifier).state = m.id;
        break;
      }
    }
  }

  Widget _totalsCard(
    BuildContext context,
    GpColors gp,
    AppLocalizations l,
    DayPassCheckoutArgs args,
    String priceStr,
  ) {
    final currency = l.currencyJod;

    Widget row(
      String label,
      String value, {
      bool strong = false,
      Color? valueColor,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(
              label.toUpperCase(),
              style: GPText.mono(
                size: 10,
                letterSpacing: 1.4,
                color: gp.mutedSoft,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: strong
                  ? GPText.display(22, color: valueColor ?? gp.fg, height: 1)
                  : GPText.body(
                      size: 14,
                      color: gp.fg,
                      weight: FontWeight.w500,
                    ),
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
          row(l.dayPassSheetLineItem, '$priceStr $currency'),
          const SizedBox(height: 4),
          Container(height: 1, color: gp.line),
          const SizedBox(height: 4),
          row(
            l.checkoutTotal,
            '$priceStr $currency',
            strong: true,
            valueColor: GP.lime,
          ),
        ],
      ),
    );
  }
}

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
