import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/gp_text.dart';
import '../../../../../core/theme/gp_tokens.dart';
import '../../../../../core/widgets/gym_loader.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../data/payment_draft.dart';

/// Apple Pay "connect" surface.
///
/// A real integration hands off to PassKit — the OS shows its own sheet and
/// returns a payment token. Here (dev mode per CLAUDE.md §4) we simulate
/// that handoff with a short delay and flip `connected = true` on the draft.
class ApplePayForm extends StatefulWidget {
  const ApplePayForm({
    super.key,
    required this.initialDraft,
    required this.onChanged,
  });

  final ApplePayDraft initialDraft;
  final ValueChanged<ApplePayDraft> onChanged;

  @override
  State<ApplePayForm> createState() => _ApplePayFormState();
}

class _ApplePayFormState extends State<ApplePayForm> {
  bool _connecting = false;

  Future<void> _connect() async {
    if (_connecting || widget.initialDraft.connected) return;
    setState(() => _connecting = true);
    HapticFeedback.selectionClick();
    // Simulated wallet handoff. Real impl calls PassKit and awaits the OS sheet.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _connecting = false);
    HapticFeedback.lightImpact();
    widget.onChanged(const ApplePayDraft(connected: true));
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    final connected = widget.initialDraft.connected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.billingAddApplePayBlurb,
          style: GPText.body(size: 14, color: gp.mutedSoft),
        ),
        const SizedBox(height: 14),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(GPRadius.lg),
            onTap: connected ? null : _connect,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: connected ? GP.lime22 : gp.bg3,
                borderRadius: BorderRadius.circular(GPRadius.lg),
                border: Border.all(
                  color: connected
                      ? gp.accentInk.withValues(alpha: 0.55)
                      : gp.line,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    connected ? Icons.check_circle : Icons.apple,
                    size: 22,
                    color: connected ? gp.accentInk : gp.fg,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _statusLabel(l, connected),
                      style: GPText.body(
                        size: 15,
                        color: connected ? gp.accentInk : gp.fg,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_connecting)
                    const GymLoader(size: GymLoaderSize.small),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _statusLabel(AppLocalizations l, bool connected) {
    if (connected) return l.billingAddApplePayConnected;
    if (_connecting) return l.billingAddApplePayConnecting;
    return l.billingAddApplePayConnect;
  }
}
