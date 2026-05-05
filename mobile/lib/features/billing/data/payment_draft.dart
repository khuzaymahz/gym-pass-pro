import '../../../l10n/app_localizations.dart';
import 'billing_state.dart';
import 'payment_validators.dart';

/// Draft state that the "add payment method" forms push up to the sheet.
///
/// Sealed so the compiler enforces that [PaymentDraftValidator] and
/// [PaymentMethodBuilder] handle every variant — adding a fifth payment
/// method later will fail to compile until both call sites are updated.
sealed class PaymentMethodDraft {
  const PaymentMethodDraft();

  PaymentMethodKind get kind;
}

class CardDraft extends PaymentMethodDraft {
  const CardDraft({
    this.number = '',
    this.expiry = '',
    this.cvv = '',
    this.holder = '',
  });

  final String number;
  final String expiry;
  final String cvv;
  final String holder;

  @override
  PaymentMethodKind get kind => PaymentValidators.detectNetwork(number);

  CardDraft copyWith({
    String? number,
    String? expiry,
    String? cvv,
    String? holder,
  }) =>
      CardDraft(
        number: number ?? this.number,
        expiry: expiry ?? this.expiry,
        cvv: cvv ?? this.cvv,
        holder: holder ?? this.holder,
      );
}

class CliqDraft extends PaymentMethodDraft {
  const CliqDraft({this.alias = '', this.phone = ''});

  /// CliQ alias (the `@handle` a user chose with their bank).
  final String alias;

  /// Jordan mobile in whatever form the user typed — normalized on submit.
  final String phone;

  @override
  PaymentMethodKind get kind => PaymentMethodKind.cliq;

  CliqDraft copyWith({String? alias, String? phone}) =>
      CliqDraft(
        alias: alias ?? this.alias,
        phone: phone ?? this.phone,
      );
}

class ApplePayDraft extends PaymentMethodDraft {
  const ApplePayDraft({this.connected = false});

  /// True after the device-wallet handoff completes. Mocked in dev mode.
  final bool connected;

  @override
  PaymentMethodKind get kind => PaymentMethodKind.applePay;

  ApplePayDraft copyWith({bool? connected}) =>
      ApplePayDraft(connected: connected ?? this.connected);
}

class GooglePayDraft extends PaymentMethodDraft {
  const GooglePayDraft({this.connected = false});

  /// True after the Google Pay sheet returns a payment token. Mocked in
  /// dev mode (same as Apple Pay) — real impl uses `pay` plugin /
  /// PaymentsClient on Android.
  final bool connected;

  @override
  PaymentMethodKind get kind => PaymentMethodKind.googlePay;

  GooglePayDraft copyWith({bool? connected}) =>
      GooglePayDraft(connected: connected ?? this.connected);
}

/// Validates a draft and returns the first localized error message, or null
/// if the draft is ready to submit. Kept separate from the draft classes so
/// the data layer doesn't pull in AppLocalizations.
class PaymentDraftValidator {
  const PaymentDraftValidator._();

  static String? firstError(PaymentMethodDraft draft, AppLocalizations l) {
    return switch (draft) {
      CardDraft d => _card(d, l),
      CliqDraft d => _cliq(d, l),
      ApplePayDraft d => _applePay(d, l),
      GooglePayDraft d => _googlePay(d, l),
    };
  }

  static String? _card(CardDraft d, AppLocalizations l) {
    if (!PaymentValidators.isCardNumberValid(d.number)) {
      return l.billingAddErrCardNumber;
    }
    if (!PaymentValidators.isExpiryValid(d.expiry)) {
      return l.billingAddErrExpiry;
    }
    if (!PaymentValidators.isCvvValid(d.cvv)) {
      return l.billingAddErrCvv;
    }
    if (!PaymentValidators.isHolderValid(d.holder)) {
      return l.billingAddErrHolder;
    }
    return null;
  }

  static String? _cliq(CliqDraft d, AppLocalizations l) {
    final aliasOk = d.alias.isNotEmpty &&
        PaymentValidators.isCliqAliasValid(d.alias);
    final phoneOk =
        d.phone.isNotEmpty && PaymentValidators.isJordanPhoneValid(d.phone);
    // Either channel is enough — real CliQ accepts both, banks route whichever
    // resolves first.
    if (!aliasOk && !phoneOk) return l.billingAddErrCliq;
    return null;
  }

  static String? _applePay(ApplePayDraft d, AppLocalizations l) {
    if (!d.connected) return l.billingAddErrApplePay;
    return null;
  }

  static String? _googlePay(GooglePayDraft d, AppLocalizations l) {
    if (!d.connected) return l.billingAddErrGooglePay;
    return null;
  }
}

/// Server-bound payload extracted from a validated draft. The mobile
/// sheet hands this to [BillingNotifier.addMethod] which calls the
/// backend's POST /me/payment-methods. The id of the resulting saved
/// method comes back from the backend — we never mint one client-side.
class PaymentMethodPayload {
  const PaymentMethodPayload({
    required this.kind,
    required this.label,
    this.last4 = '',
    this.holder,
    this.expiryMm,
    this.expiryYy,
    this.cliqAlias,
    this.cliqPhone,
  });

  final PaymentMethodKind kind;
  final String label;
  final String last4;
  final String? holder;
  final int? expiryMm;
  final int? expiryYy;
  final String? cliqAlias;
  final String? cliqPhone;
}

/// Build the wire payload from a validated draft. Assumes the draft has
/// already passed [PaymentDraftValidator.firstError].
class PaymentMethodPayloadBuilder {
  const PaymentMethodPayloadBuilder._();

  static PaymentMethodPayload build(
    PaymentMethodDraft draft,
    AppLocalizations l,
  ) {
    return switch (draft) {
      CardDraft d => _card(d, l),
      CliqDraft d => _cliq(d, l),
      ApplePayDraft _ => _applePay(l),
      GooglePayDraft _ => _googlePay(l),
    };
  }

  static PaymentMethodPayload _card(CardDraft d, AppLocalizations l) {
    final network = PaymentValidators.detectNetwork(d.number);
    final exp = PaymentValidators.parseExpiry(d.expiry);
    return PaymentMethodPayload(
      kind: network,
      label: network == PaymentMethodKind.mastercard
          ? l.billingCardNetworkMastercard
          : l.billingCardNetworkVisa,
      last4: PaymentValidators.last4(d.number),
      holder: d.holder.trim(),
      expiryMm: exp?.mm,
      expiryYy: exp?.yy,
    );
  }

  static PaymentMethodPayload _cliq(CliqDraft d, AppLocalizations l) {
    final alias = d.alias.trim();
    final normalizedPhone = d.phone.isEmpty
        ? null
        : PaymentValidators.normalizeJordanPhone(d.phone);
    // Display identifier: alias wins; otherwise last 4 of the phone number.
    final display = alias.isNotEmpty
        ? '@$alias'
        : (normalizedPhone == null
            ? ''
            : PaymentValidators.last4(normalizedPhone));
    return PaymentMethodPayload(
      kind: PaymentMethodKind.cliq,
      label: l.billingCardNetworkCliq,
      last4: display,
      cliqAlias: alias.isEmpty ? null : alias,
      cliqPhone: normalizedPhone,
    );
  }

  static PaymentMethodPayload _applePay(AppLocalizations l) {
    return PaymentMethodPayload(
      kind: PaymentMethodKind.applePay,
      label: l.billingCardNetworkApple,
    );
  }

  static PaymentMethodPayload _googlePay(AppLocalizations l) {
    return PaymentMethodPayload(
      kind: PaymentMethodKind.googlePay,
      label: l.billingCardNetworkGoogle,
    );
  }
}
