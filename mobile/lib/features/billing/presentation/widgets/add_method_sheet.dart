import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../core/widgets/overline.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/billing_state.dart';
import '../../data/payment_draft.dart';
import 'method_forms/apple_pay_form.dart';
import 'method_forms/card_form.dart';
import 'method_forms/cliq_form.dart';
import 'method_forms/google_pay_form.dart';

typedef OnMethodAdded = void Function(String successMessage);

/// Entry point for the "Add payment method" bottom-sheet.
///
/// The sheet is a thin orchestrator: it owns the kind selector and delegates
/// field collection to a per-kind form widget. Drafts per kind are kept as
/// state so switching Card → CliQ → Card preserves partial input.
Future<void> showAddMethodSheet({
  required BuildContext context,
  required WidgetRef ref,
  required OnMethodAdded onAdded,
}) async {
  final gp = context.gp;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: gp.bg2,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(GPRadius.xl2)),
    ),
    builder: (_) => _AddMethodSheetBody(onAdded: onAdded),
  );
}

class _AddMethodSheetBody extends ConsumerStatefulWidget {
  const _AddMethodSheetBody({required this.onAdded});

  final OnMethodAdded onAdded;

  @override
  ConsumerState<_AddMethodSheetBody> createState() =>
      _AddMethodSheetBodyState();
}

/// One of the selectable kinds in the sheet. Narrower than
/// [PaymentMethodKind] because Visa vs Mastercard is detected automatically
/// from the card BIN — the user only picks "Card". Apple Pay only renders
/// on iOS, Google Pay only on Android — adding a wallet you can't open
/// from the device is a dead-end UX.
enum _Tab { card, cliq, applePay, googlePay }

/// Returns true when the app is running on iOS. Falls back to false on
/// web / unknown platforms so the wallet stays hidden rather than
/// silently broken.
bool _isIos() => !kIsWeb && Platform.isIOS;

bool _isAndroid() => !kIsWeb && Platform.isAndroid;

class _AddMethodSheetBodyState extends ConsumerState<_AddMethodSheetBody> {
  _Tab _tab = _Tab.card;

  CardDraft _cardDraft = const CardDraft();
  CliqDraft _cliqDraft = const CliqDraft();
  ApplePayDraft _appleDraft = const ApplePayDraft();
  GooglePayDraft _googleDraft = const GooglePayDraft();

  PaymentMethodDraft get _activeDraft => switch (_tab) {
        _Tab.card => _cardDraft,
        _Tab.cliq => _cliqDraft,
        _Tab.applePay => _appleDraft,
        _Tab.googlePay => _googleDraft,
      };

  Future<void> _save(AppLocalizations l) async {
    final draft = _activeDraft;
    final error = PaymentDraftValidator.firstError(draft, l);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final payload = PaymentMethodPayloadBuilder.build(draft, l);
    try {
      await ref.read(billingProvider.notifier).addMethod(
            kind: payload.kind,
            label: payload.label,
            last4: payload.last4,
            holder: payload.holder,
            expiryMm: payload.expiryMm,
            expiryYy: payload.expiryYy,
            cliqAlias: payload.cliqAlias,
            cliqPhone: payload.cliqPhone,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onAdded(l.billingMethodAdded);
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: SingleChildScrollView(
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
                const SizedBox(height: 18),
                DisplayText(l.billingAddTitle, size: 22),
                const SizedBox(height: 18),
                _tabRow(l, gp),
                const SizedBox(height: 18),
                _sectionHeader(l, gp),
                const SizedBox(height: 10),
                _activeForm(),
                const SizedBox(height: 20),
                PillButton(
                  label: l.billingAddSaveBtn,
                  trailingIcon: Icons.arrow_forward,
                  onPressed: () => _save(l),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _activeForm() {
    return switch (_tab) {
      _Tab.card => CardForm(
          initialDraft: _cardDraft,
          onChanged: (d) => setState(() => _cardDraft = d),
        ),
      _Tab.cliq => CliqForm(
          initialDraft: _cliqDraft,
          onChanged: (d) => setState(() => _cliqDraft = d),
        ),
      _Tab.applePay => ApplePayForm(
          initialDraft: _appleDraft,
          onChanged: (d) => setState(() => _appleDraft = d),
        ),
      _Tab.googlePay => GooglePayForm(
          initialDraft: _googleDraft,
          onChanged: (d) => setState(() => _googleDraft = d),
        ),
    };
  }

  Widget _sectionHeader(AppLocalizations l, GpColors gp) {
    final label = switch (_tab) {
      _Tab.card => l.billingAddCardSection,
      _Tab.cliq => l.billingAddCliqSection,
      _Tab.applePay => l.billingAddApplePaySection,
      _Tab.googlePay => l.billingAddGooglePaySection,
    };
    return Text(
      label.toUpperCase(),
      style: GPText.mono(
        size: 10,
        letterSpacing: 1.8,
        color: gp.muted,
      ),
    );
  }

  Widget _tabRow(AppLocalizations l, GpColors gp) {
    // Card + CliQ are universal. The wallet tab is gated on the host
    // platform: showing Apple Pay on Android (or vice versa) would
    // dead-end the member at a wallet they can't open. Web / desktop
    // see neither — neither wallet has a usable in-browser surface
    // for our checkout flow.
    final tabs = <(_Tab, String, IconData)>[
      (_Tab.card, l.billingAddCard, Icons.credit_card),
      (_Tab.cliq, l.billingAddCliq, Icons.account_balance_wallet_outlined),
      if (_isIos())
        (_Tab.applePay, l.billingAddApple, Icons.apple),
      if (_isAndroid())
        (_Tab.googlePay, l.billingAddGoogle, Icons.account_balance_wallet),
    ];
    return Column(
      children: [
        for (final t in tabs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _tabOption(
              gp,
              icon: t.$3,
              label: t.$2,
              active: _tab == t.$1,
              onTap: () => setState(() => _tab = t.$1),
            ),
          ),
      ],
    );
  }

  Widget _tabOption(
    GpColors gp, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? GP.lime22 : gp.bg3,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(
              color:
                  active ? gp.accentInk.withValues(alpha: 0.55) : gp.line,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: active ? gp.accentInk : gp.fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GPText.body(
                    size: 14,
                    color: active ? gp.accentInk : gp.fg,
                    weight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                active ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: active ? gp.accentInk : gp.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
