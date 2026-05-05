import 'package:flutter/material.dart';

import '../../data/billing_state.dart';

/// Maps a payment method kind to its display icon. Kept separate so
/// changing the icon set doesn't force every consumer to switch.
class MethodIcon {
  const MethodIcon._();

  static IconData of(PaymentMethodKind kind) => switch (kind) {
        PaymentMethodKind.visa => Icons.credit_card,
        PaymentMethodKind.mastercard => Icons.credit_card,
        PaymentMethodKind.cliq => Icons.account_balance_wallet_outlined,
        PaymentMethodKind.applePay => Icons.apple,
        // Material's bundled icon set has no Google logo glyph; the
        // wallet/cards icon reads as a tokenized payment surface, which
        // is what Google Pay represents to the member.
        PaymentMethodKind.googlePay => Icons.account_balance_wallet,
      };
}

/// Maps a payment method kind to its localized network label.
String methodNetworkName(
  PaymentMethodKind kind,
  String visa,
  String mastercard,
  String cliq,
  String apple,
  String google,
) =>
    switch (kind) {
      PaymentMethodKind.visa => visa,
      PaymentMethodKind.mastercard => mastercard,
      PaymentMethodKind.cliq => cliq,
      PaymentMethodKind.applePay => apple,
      PaymentMethodKind.googlePay => google,
    };
