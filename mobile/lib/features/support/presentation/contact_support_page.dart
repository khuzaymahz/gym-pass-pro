import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../data/support_tickets.dart';

class ContactSupportPage extends ConsumerStatefulWidget {
  const ContactSupportPage({super.key});

  @override
  ConsumerState<ContactSupportPage> createState() =>
      _ContactSupportPageState();
}

class _ContactSupportPageState extends ConsumerState<ContactSupportPage> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(AppLocalizations l) async {
    final subject = _subjectCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.supportMissingFields)));
      return;
    }
    setState(() => _submitting = true);
    final ticketRef = await ref
        .read(supportTicketsProvider.notifier)
        .submitMessage(subject: subject, body: body);
    if (!mounted) return;
    setState(() => _submitting = false);
    _subjectCtrl.clear();
    _bodyCtrl.clear();
    await _showConfirmation(l, ticketRef);
  }

  Future<void> _showConfirmation(
      AppLocalizations l, String ticketRef,) async {
    final gp = context.gp;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: gp.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GPRadius.lg),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: GP.success, size: 22,),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.supportSubmittedTitle,
                style: GPText.body(
                    size: 18, color: gp.fg, weight: FontWeight.w600,),
              ),
            ),
          ],
        ),
        content: Text(
          l.supportSentWithRef(ticketRef),
          style: GPText.body(size: 14, color: gp.mutedSoft, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: GP.lime,
              foregroundColor: GP.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GPRadius.pill),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text(
              l.reportSubmittedClose.toUpperCase(),
              style: GPText.mono(
                size: 11,
                letterSpacing: 1.4,
                color: GP.ink,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Open a deep-link URL (`tel:`, `mailto:`, `https://wa.me/`) in
  /// the matching OS app. Falls back to copying the source value to
  /// the clipboard with a toast when no handler is registered (no
  /// SIM in the device for `tel:`, no mail client for `mailto:`,
  /// WhatsApp not installed for the WA link) — so the member always
  /// walks away with the contact info, just sometimes via a
  /// less-direct path.
  Future<void> _launchOrCopy(
    AppLocalizations l, {
    required Uri uri,
    required String fallbackValue,
  }) async {
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (launched || !mounted) return;
    // Fallback: copy + toast. Better than a silent no-op when the
    // dialer / mail / WhatsApp app can't be opened on this device.
    await Clipboard.setData(ClipboardData(text: fallbackValue));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l.supportChannelCopied(fallbackValue))),
      );
  }

  Future<void> _callPhone(AppLocalizations l, String phone) async {
    // tel: URIs must be pure digits (optionally with a leading +).
    // Spaces and dashes in the display value would be silently
    // stripped by some dialers, rejected as malformed by others.
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    await _launchOrCopy(
      l,
      uri: Uri(scheme: 'tel', path: digits),
      fallbackValue: phone,
    );
  }

  Future<void> _emailSupport(AppLocalizations l, String email) async {
    // Prefill subject so the operator's inbox lands the message in
    // the right queue instead of arriving as "(no subject)".
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeQueryComponent(l.supportEmailDefaultSubject)}',
    );
    await _launchOrCopy(l, uri: uri, fallbackValue: email);
  }

  Future<void> _openWhatsapp(AppLocalizations l, String phone) async {
    // wa.me requires the number in international form without `+`
    // or spaces. `https://wa.me/9627XXX...` opens WhatsApp on Android
    // / iOS / web. A `text=` param prefills the chat compose so the
    // operator sees context immediately.
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse(
      'https://wa.me/$digits'
      '?text=${Uri.encodeQueryComponent(l.supportEmailDefaultSubject)}',
    );
    await _launchOrCopy(l, uri: uri, fallbackValue: phone);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 28),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Overline(l.supportOverline)],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  DisplayText(l.supportHeadline, size: 36),
                  const SizedBox(width: 10),
                  SerifAccent(l.supportHeadlineAccent, size: 36),
                ],
              ),
              const SizedBox(height: 12),
              Text(l.supportBlurb,
                  style: GPText.body(size: 14, color: gp.mutedSoft),),
              const SizedBox(height: 24),
              _sectionLabel(l.supportChannelsLabel, gp),
              const SizedBox(height: 10),
              _channelCard(
                icon: Icons.phone_outlined,
                title: l.supportChannelCallTitle,
                subtitle: l.supportChannelCallSubtitle,
                trailing: l.supportSupportPhone,
                gp: gp,
                onTap: () => _callPhone(l, l.supportSupportPhone),
              ),
              const SizedBox(height: 10),
              _channelCard(
                icon: Icons.email_outlined,
                title: l.supportChannelEmailTitle,
                subtitle: l.supportChannelEmailSubtitle,
                gp: gp,
                onTap: () => _emailSupport(l, l.supportEmail),
              ),
              const SizedBox(height: 10),
              _channelCard(
                icon: Icons.chat_bubble_outline,
                title: l.supportChannelWhatsappTitle,
                subtitle: l.supportChannelWhatsappSubtitle,
                gp: gp,
                accent: GP.success,
                onTap: () => _openWhatsapp(l, l.supportWhatsapp),
              ),
              const SizedBox(height: 28),
              _sectionLabel(l.supportMessageLabel, gp),
              const SizedBox(height: 12),
              _fieldLabel(l.supportSubjectLabel, gp),
              const SizedBox(height: 8),
              _field(
                controller: _subjectCtrl,
                hint: l.supportSubjectHint,
                gp: gp,
              ),
              const SizedBox(height: 16),
              _fieldLabel(l.supportBodyLabel, gp),
              const SizedBox(height: 8),
              _field(
                controller: _bodyCtrl,
                hint: l.supportBodyHint,
                gp: gp,
                minLines: 4,
                maxLines: 8,
              ),
              const SizedBox(height: 24),
              PillButton(
                label: l.supportSendBtn,
                trailingIcon: Icons.send,
                onPressed: _submitting ? null : () => _send(l),
              ),
            ],
          ),
          PositionedDirectional(
            top: topInset + 12,
            start: 20,
            child: const BackBtn(fallback: '/profile'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, GpColors gp) => Text(
        text,
        style: GPText.mono(
          size: 10,
          letterSpacing: 1.8,
          color: gp.muted,
        ),
      );

  Widget _fieldLabel(String text, GpColors gp) => Text(
        text.toUpperCase(),
        style: GPText.mono(
          size: 10,
          letterSpacing: 1.5,
          color: gp.mutedSoft,
        ),
      );

  Widget _channelCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required GpColors gp,
    required VoidCallback onTap,
    String? trailing,
    Color? accent,
  }) {
    final a = accent ?? gp.accentInk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(color: gp.line),
            boxShadow: gp.cardShadows,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: a.withValues(alpha: 0.15),
                  border: Border.all(color: a.withValues(alpha: 0.4)),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: a, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GPText.body(
                            size: 14,
                            color: gp.fg,
                            weight: FontWeight.w600,),),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: GPText.body(size: 12, color: gp.mutedSoft),),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailing,
                  style: GPText.mono(
                      size: 10, letterSpacing: 1.2, color: gp.muted,),
                ),
              ],
              const SizedBox(width: 6),
              Icon(Icons.copy, size: 14, color: gp.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required GpColors gp,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      cursorColor: gp.accentInk,
      style: GPText.body(size: 15, color: gp.fg, weight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GPText.body(size: 14, color: gp.muted),
        filled: true,
        fillColor: gp.bg2,
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
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    );
  }
}
