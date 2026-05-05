import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/gp_text.dart';
import '../../../../../core/theme/gp_tokens.dart';

/// Shared text-field styling for the add-payment-method forms. Keeps card /
/// CliQ / phone inputs visually identical and means every form flows the same
/// focus border and hint treatment.
class PaymentField extends StatelessWidget {
  const PaymentField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLength,
    this.obscure = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool obscure;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GPText.mono(
            size: 10,
            letterSpacing: 1.4,
            color: gp.muted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          obscureText: obscure,
          onChanged: onChanged,
          style: GPText.body(
            size: 15,
            color: gp.fg,
            weight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GPText.body(size: 14, color: gp.muted),
            counterText: '',
            filled: true,
            fillColor: gp.bg3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GPRadius.lg),
              borderSide: BorderSide(color: gp.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GPRadius.lg),
              borderSide: BorderSide(color: gp.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GPRadius.lg),
              borderSide: BorderSide(color: gp.accentInk, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
