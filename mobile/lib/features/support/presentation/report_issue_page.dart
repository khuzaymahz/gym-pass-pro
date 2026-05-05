import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../data/support_tickets.dart';

class ReportIssuePage extends ConsumerStatefulWidget {
  const ReportIssuePage({super.key});

  @override
  ConsumerState<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends ConsumerState<ReportIssuePage> {
  String? _category;
  String? _attachmentName;
  bool _submitting = false;
  final _gymCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _gymCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations l) async {
    if (_category == null || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.reportMissingFields)));
      return;
    }
    setState(() => _submitting = true);
    final gym = _gymCtrl.text.trim();
    final ticketRef = await ref.read(supportTicketsProvider.notifier).submitReport(
          category: _category!,
          description: _descCtrl.text.trim(),
          gym: gym.isEmpty ? null : gym,
          attachment: _attachmentName,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    await _showConfirmation(l, ticketRef);
    if (!mounted) return;
    setState(() {
      _category = null;
      _attachmentName = null;
      _gymCtrl.clear();
      _descCtrl.clear();
    });
  }

  Future<void> _pickAttachment(AppLocalizations l, GpColors gp) async {
    final today = DateTime.now();
    final iso = '${today.year}-${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final options = <(IconData, String, String?)>[
      (Icons.screenshot_outlined, l.reportAttachScreenshot,
          'Screenshot $iso.png',),
      (Icons.photo_library_outlined, l.reportAttachCameraRoll,
          'camera-roll-$iso.jpg',),
      (Icons.photo_camera_outlined, l.reportAttachPhoto,
          'capture-$iso.jpg',),
      if (_attachmentName != null)
        (Icons.delete_outline, l.reportAttachRemove, null),
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: gp.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(GPRadius.xl2)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
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
              const SizedBox(height: 16),
              DisplayText(l.reportAttachPickerTitle, size: 22),
              const SizedBox(height: 14),
              for (final o in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(GPRadius.lg),
                      onTap: () {
                        setState(() => _attachmentName = o.$3);
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: gp.bg3,
                          borderRadius: BorderRadius.circular(GPRadius.lg),
                          border: Border.all(color: gp.line),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              o.$1,
                              size: 20,
                              color: o.$3 == null ? GP.danger : gp.accentInk,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                o.$2,
                                style: GPText.body(
                                  size: 14,
                                  color: o.$3 == null ? GP.danger : gp.fg,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
                l.reportSubmittedTitle,
                style: GPText.body(
                    size: 18, color: gp.fg, weight: FontWeight.w600,),
              ),
            ),
          ],
        ),
        content: Text(
          l.reportSubmittedBody(ticketRef),
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final categories = <(String, String, IconData)>[
      ('checkin', l.reportCategoryCheckin, Icons.qr_code_2),
      ('payment', l.reportCategoryPayment, Icons.payments_outlined),
      ('app', l.reportCategoryApp, Icons.phone_iphone),
      ('account', l.reportCategoryAccount, Icons.person_outline),
      ('other', l.reportCategoryOther, Icons.more_horiz),
    ];
    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 28),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Overline(l.reportOverline)],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  DisplayText(l.reportHeadline, size: 36),
                  const SizedBox(width: 10),
                  SerifAccent(l.reportHeadlineAccent, size: 36),
                ],
              ),
              const SizedBox(height: 12),
              Text(l.reportBlurb,
                  style: GPText.body(size: 14, color: gp.mutedSoft),),
              const SizedBox(height: 24),
              _sectionLabel(l.reportCategoryLabel, gp),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories
                    .map((c) => _categoryChip(c.$1, c.$2, c.$3, gp))
                    .toList(),
              ),
              const SizedBox(height: 22),
              _fieldLabel(l.reportGymLabel, gp),
              const SizedBox(height: 8),
              _field(
                controller: _gymCtrl,
                hint: l.reportGymHint,
                gp: gp,
              ),
              const SizedBox(height: 16),
              _fieldLabel(l.reportDescLabel, gp),
              const SizedBox(height: 8),
              _field(
                controller: _descCtrl,
                hint: l.reportDescHint,
                gp: gp,
                minLines: 5,
                maxLines: 10,
              ),
              const SizedBox(height: 20),
              _sectionLabel(l.reportAttachLabel, gp),
              const SizedBox(height: 10),
              _attachmentTile(l, gp),
              const SizedBox(height: 28),
              PillButton(
                label: l.reportSubmitBtn,
                trailingIcon: Icons.send,
                onPressed: _submitting ? null : () => _submit(l),
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

  Widget _categoryChip(String key, String label, IconData icon, GpColors gp) {
    final active = _category == key;
    return GestureDetector(
      onTap: () => setState(() => _category = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? GP.lime22 : gp.bg2,
          borderRadius: BorderRadius.circular(GPRadius.pill),
          border: Border.all(
            color:
                active ? gp.accentInk.withValues(alpha: 0.55) : gp.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: active ? gp.accentInk : gp.mutedSoft,),
            const SizedBox(width: 8),
            Text(
              label,
              style: GPText.body(
                size: 13,
                color: active ? gp.accentInk : gp.fg,
                weight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentTile(AppLocalizations l, GpColors gp) {
    final attached = _attachmentName != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.lg),
        onTap: () => _pickAttachment(l, gp),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: attached ? GP.lime22 : gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(
              color: attached
                  ? gp.accentInk.withValues(alpha: 0.55)
                  : gp.line,
            ),
          ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: gp.accentInk.withValues(alpha: 0.15),
                border: Border.all(
                    color: gp.accentInk.withValues(alpha: 0.4),),
              ),
              alignment: Alignment.center,
              child: Icon(
                attached ? Icons.check : Icons.image_outlined,
                size: 18,
                color: gp.accentInk,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _attachmentName ?? l.reportAttachPlaceholder,
                style: GPText.body(
                    size: 14, color: gp.fg, weight: FontWeight.w500,),
              ),
            ),
            Icon(
              attached ? Icons.edit_outlined : Icons.add,
              size: 18,
              color: gp.muted,
            ),
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
