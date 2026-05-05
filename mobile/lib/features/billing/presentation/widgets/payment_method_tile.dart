import 'package:flutter/material.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/billing_state.dart';
import 'billing_action_button.dart';
import 'method_icon.dart';

class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    super.key,
    required this.method,
    required this.isDefault,
    required this.onSetDefault,
    required this.onRemove,
  });

  final PaymentMethod method;
  final bool isDefault;
  final VoidCallback onSetDefault;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    final networkName = methodNetworkName(
      method.kind,
      l.billingCardNetworkVisa,
      l.billingCardNetworkMastercard,
      l.billingCardNetworkCliq,
      l.billingCardNetworkApple,
      l.billingCardNetworkGoogle,
    );
    final subtitle = method.last4.isNotEmpty
        ? '$networkName · ${_maskLast4(method.kind, method.last4)}'
        : networkName;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(
          color:
              isDefault ? gp.accentInk.withValues(alpha: 0.55) : gp.line,
        ),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: gp.bg3,
                  border: Border.all(color: gp.line),
                ),
                alignment: Alignment.center,
                child:
                    Icon(MethodIcon.of(method.kind), size: 20, color: gp.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.label,
                      style: GPText.body(
                        size: 14,
                        color: gp.fg,
                        weight: FontWeight.w600,
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
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4,),
                  decoration: BoxDecoration(
                    color: GP.lime22,
                    borderRadius: BorderRadius.circular(GPRadius.pill),
                    border: Border.all(
                      color: gp.accentInk.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    l.billingDefaultChip.toUpperCase(),
                    style: GPText.mono(
                      size: 9,
                      letterSpacing: 1.4,
                      color: gp.accentInk,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isDefault) ...[
                BillingActionButton(
                  icon: Icons.check_circle_outline,
                  label: l.billingSetDefault,
                  color: gp.accentInk,
                  onTap: onSetDefault,
                ),
                const SizedBox(width: 10),
              ],
              BillingActionButton(
                icon: Icons.delete_outline,
                label: l.billingRemoveMethod,
                color: GP.danger,
                onTap: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _maskLast4(PaymentMethodKind kind, String last4) {
    if (kind == PaymentMethodKind.cliq) return last4;
    if (kind == PaymentMethodKind.applePay) return last4;
    return '•••• $last4';
  }
}
