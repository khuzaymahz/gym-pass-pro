import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../data/payment_draft.dart';
import '../../../data/payment_validators.dart';
import 'payment_field.dart';

/// Card entry form — number, expiry, CVV, holder.
///
/// Collects what a real gateway would tokenize. We never persist the PAN or
/// CVV; the parent sheet builds a [PaymentMethod] that retains only the last
/// four digits, expiry month/year, and holder name.
class CardForm extends StatefulWidget {
  const CardForm({
    super.key,
    required this.initialDraft,
    required this.onChanged,
  });

  final CardDraft initialDraft;
  final ValueChanged<CardDraft> onChanged;

  @override
  State<CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<CardForm> {
  late final TextEditingController _number;
  late final TextEditingController _expiry;
  late final TextEditingController _cvv;
  late final TextEditingController _holder;

  @override
  void initState() {
    super.initState();
    _number = TextEditingController(
      text: PaymentValidators.formatCardNumber(widget.initialDraft.number),
    );
    _expiry = TextEditingController(
      text: PaymentValidators.formatExpiry(widget.initialDraft.expiry),
    );
    _cvv = TextEditingController(text: widget.initialDraft.cvv);
    _holder = TextEditingController(text: widget.initialDraft.holder);
  }

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _holder.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      CardDraft(
        number: PaymentValidators.digitsOnly(_number.text),
        expiry: PaymentValidators.digitsOnly(_expiry.text),
        cvv: PaymentValidators.digitsOnly(_cvv.text),
        holder: _holder.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PaymentField(
          controller: _number,
          label: l.billingAddCardNumberLabel,
          hint: l.billingAddCardNumberHint,
          keyboardType: TextInputType.number,
          maxLength: 23, // 19 digits + 4 spaces
          inputFormatters: [_CardNumberFormatter()],
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PaymentField(
                controller: _expiry,
                label: l.billingAddExpiryLabel,
                hint: l.billingAddExpiryHint,
                keyboardType: TextInputType.number,
                maxLength: 7, // "MM / YY"
                inputFormatters: [_ExpiryFormatter()],
                onChanged: (_) => _emit(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PaymentField(
                controller: _cvv,
                label: l.billingAddCvvLabel,
                hint: l.billingAddCvvHint,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscure: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (_) => _emit(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PaymentField(
          controller: _holder,
          label: l.billingAddHolderLabel,
          hint: l.billingAddHolderHint,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }
}

/// Groups digits in fours: "4242424242424242" → "4242 4242 4242 4242".
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = PaymentValidators.formatCardNumber(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formats expiry input as "MM / YY" while the user types.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = PaymentValidators.formatExpiry(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
