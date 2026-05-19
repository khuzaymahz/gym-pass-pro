import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_error.dart';
import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/gym_logo.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/tier_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../data/day_pass.dart';
import '../data/day_pass_repository.dart';

/// Confirm-and-pay bottom sheet for a single day-pass purchase.
///
/// Kept deliberately simpler than the subscription checkout: the
/// day-pass SKU is a single-price, single-gym, mock-payment
/// transaction. No tier picker, no duration, no discount — one
/// summary line, one Pay button. The bottom sheet idiom (vs a
/// full route) lets the member dismiss without losing the gym
/// page underneath, which is the whole reason they're considering
/// the purchase.
///
/// Payment in dev runs through `MockPaymentProvider` server-side —
/// no real card flow, the mock always succeeds (and the OTP-1234
/// rule means we never charge anything real in development per
/// CLAUDE.md §4). For production this will route through whichever
/// gateway lands in `app/providers/payments/`.
/// Optional `gym` parameter passes the rich [GPGym] model so the
/// sheet can render the logo + tier chip. The CTA on gym detail
/// has the data already; other call sites that don't can omit it
/// and the sheet falls back to a generic header.
Future<DayPass?> showBuyDayPassSheet({
  required BuildContext context,
  required String gymSlug,
  required String gymName,
  required DayPassOffering offering,
  GPGym? gym,
  String? gymLogoUrl,
}) {
  final gp = context.gp;
  return showModalBottomSheet<DayPass?>(
    context: context,
    backgroundColor: gp.bg2,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(GPRadius.xl2)),
    ),
    builder: (_) => _BuyDayPassSheetBody(
      gymSlug: gymSlug,
      gymName: gymName,
      offering: offering,
      gym: gym,
      gymLogoUrl: gymLogoUrl,
    ),
  );
}

class _BuyDayPassSheetBody extends ConsumerStatefulWidget {
  const _BuyDayPassSheetBody({
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

  @override
  ConsumerState<_BuyDayPassSheetBody> createState() =>
      _BuyDayPassSheetBodyState();
}

class _BuyDayPassSheetBodyState extends ConsumerState<_BuyDayPassSheetBody> {
  bool _busy = false;

  Future<void> _onPay() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final pass = await ref
          .read(dayPassRepositoryProvider)
          .purchase(
            gymSlug: widget.gymSlug,
            // Dev mode runs the mock provider; production swaps in a
            // real gateway through the same `paymentMethod` enum. The
            // mock requires no payment-method-id, which is why
            // we don't surface a method picker on the sheet — the
            // first iteration assumes the member's default method.
            paymentMethodKind: 'mock',
          );
      // Invalidate so the Profile "Active passes" card + the
      // gym detail page's CTA refresh on the very next frame.
      ref.invalidate(myDayPassesProvider);
      if (!mounted) return;
      Navigator.of(context).pop(pass);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.dayPassPurchasedSnack)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(resolveErrorMessage(e, l))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final gp = context.gp;
    final priceText = widget.offering.priceJod % 1 == 0
        ? widget.offering.priceJod.toStringAsFixed(0)
        : widget.offering.priceJod.toStringAsFixed(2);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 18,
          bottom: 18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: gp.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header row: gym logo + name + tier chip. Mirrors the
            // gym detail page's identity strip so the buyer keeps
            // continuity ("yes, this is the same gym I tapped").
            // Falls back to a clean text-only title when the call
            // site didn't supply a `gym` model.
            _Header(
              gym: widget.gym,
              gymName: widget.gymName,
              gymLogoUrl: widget.gymLogoUrl,
              isAr: isAr,
            ),
            const SizedBox(height: 16),
            // Receipt-style breakdown. Visually grouped so the
            // member reads it as a small payment summary rather
            // than a label-value pair lost in surrounding chrome.
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: gp.bg3,
                borderRadius: BorderRadius.circular(GPRadius.md),
                border: Border.all(color: gp.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        size: 16,
                        color: gp.mutedSoft,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.dayPassSheetLineItem,
                          style: GPText.body(size: 14, color: gp.fg),
                        ),
                      ),
                      Text(
                        '$priceText ${l.currencyJod}',
                        style: GPText.body(
                          size: 14,
                          color: gp.fg,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(height: 1, color: gp.line),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 16,
                        color: gp.mutedSoft,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.dayPassSheetValidity(widget.offering.validityHours),
                          style: GPText.body(
                            size: 12,
                            color: gp.mutedSoft,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PillButton(
              label: _busy
                  ? l.dayPassSheetPaying
                  : l.dayPassSheetPay(priceText),
              onPressed: _busy ? null : _onPay,
              trailingIcon: _busy ? null : Icons.lock_open,
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(
                  l.cancel,
                  style: GPText.body(size: 13, color: gp.mutedSoft),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.dayPassSheetTerms,
              style: GPText.body(size: 11, color: gp.muted, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Buy-sheet header. Gym logo + name display + tier chip when we
/// know the gym; falls back to a centered display-text title when
/// we don't. Stays compact (logo 48px) so the rest of the sheet
/// doesn't push past the on-screen keyboard on smaller devices.
class _Header extends StatelessWidget {
  const _Header({
    required this.gym,
    required this.gymName,
    required this.gymLogoUrl,
    required this.isAr,
  });

  final GPGym? gym;
  final String gymName;
  final String? gymLogoUrl;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    if (gym == null) {
      // Generic header — no logo available.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.dayPassSheetTitle,
            style: GPText.mono(size: 10, letterSpacing: 1.8, color: gp.muted),
          ),
          const SizedBox(height: 8),
          Text(
            gymName,
            style: GPText.display(24, color: gp.fg),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GymLogo(gym: gym!, logoUrl: gymLogoUrl, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.dayPassSheetTitle,
                style: GPText.mono(
                  size: 9,
                  letterSpacing: 1.6,
                  color: gp.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                gymName,
                style: GPText.display(18, color: gp.fg, height: 1.05),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TierChip(tier: gym!.tierObj),
      ],
    );
  }
}
