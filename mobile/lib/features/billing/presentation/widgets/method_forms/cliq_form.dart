import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/gp_text.dart';
import '../../../../../core/theme/gp_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../data/payment_draft.dart';
import '../../../data/payment_validators.dart';
import 'payment_field.dart';

/// CliQ entry form — the user picks a single identifier (alias OR phone)
/// and fills only that field. Real CliQ routes on whichever resolves, so
/// one channel per record keeps the saved method unambiguous.
class CliqForm extends StatefulWidget {
  const CliqForm({
    super.key,
    required this.initialDraft,
    required this.onChanged,
  });

  final CliqDraft initialDraft;
  final ValueChanged<CliqDraft> onChanged;

  @override
  State<CliqForm> createState() => _CliqFormState();
}

enum _CliqMode { alias, phone }

class _CliqFormState extends State<CliqForm> {
  late final TextEditingController _alias;
  late final TextEditingController _phone;
  late _CliqMode _mode;

  @override
  void initState() {
    super.initState();
    _alias = TextEditingController(text: widget.initialDraft.alias);
    _phone = TextEditingController(
      text: PaymentValidators.formatJordanPhone(widget.initialDraft.phone),
    );
    // If the user arrives with a phone already filled but no alias, land on
    // the phone tab; otherwise default to alias.
    _mode = widget.initialDraft.phone.isNotEmpty &&
            widget.initialDraft.alias.isEmpty
        ? _CliqMode.phone
        : _CliqMode.alias;
  }

  @override
  void dispose() {
    _alias.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      CliqDraft(
        alias: _mode == _CliqMode.alias ? _alias.text.trim() : '',
        phone: _mode == _CliqMode.phone
            ? PaymentValidators.digitsOnly(_phone.text)
            : '',
      ),
    );
  }

  void _setMode(_CliqMode next) {
    if (_mode == next) return;
    setState(() {
      _mode = next;
      // Clear the inactive channel so the saved draft carries only the
      // chosen identifier.
      if (next == _CliqMode.alias) {
        _phone.clear();
      } else {
        _alias.clear();
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ModeToggle(
          mode: _mode,
          aliasLabel: l.billingAddCliqModeAlias,
          phoneLabel: l.billingAddCliqModePhone,
          onChanged: _setMode,
        ),
        const SizedBox(height: 12),
        if (_mode == _CliqMode.alias)
          PaymentField(
            controller: _alias,
            label: l.billingAddCliqAliasLabel,
            hint: l.billingAddCliqAliasHint,
            keyboardType: TextInputType.text,
            maxLength: 30,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._-]')),
            ],
            onChanged: (_) => _emit(),
          )
        else
          PaymentField(
            controller: _phone,
            label: l.billingAddCliqPhoneLabel,
            hint: l.billingAddCliqPhoneHint,
            keyboardType: TextInputType.phone,
            maxLength: 17, // "+962 7X XXX XXXX"
            inputFormatters: [_JordanPhoneFormatter()],
            onChanged: (_) => _emit(),
          ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.aliasLabel,
    required this.phoneLabel,
    required this.onChanged,
  });

  final _CliqMode mode;
  final String aliasLabel;
  final String phoneLabel;
  final ValueChanged<_CliqMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: gp.bg3,
        borderRadius: BorderRadius.circular(GPRadius.pill),
        border: Border.all(color: gp.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _chip(
              context,
              label: aliasLabel,
              selected: mode == _CliqMode.alias,
              onTap: () => onChanged(_CliqMode.alias),
            ),
          ),
          Expanded(
            child: _chip(
              context,
              label: phoneLabel,
              selected: mode == _CliqMode.phone,
              onTap: () => onChanged(_CliqMode.phone),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final gp = context.gp;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? GP.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(GPRadius.pill),
        ),
        child: Center(
          child: Text(
            label,
            style: GPText.body(
              size: 13,
              color: selected ? GP.ink : gp.mutedSoft,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _JordanPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = PaymentValidators.formatJordanPhone(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
