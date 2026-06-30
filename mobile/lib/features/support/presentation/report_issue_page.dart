import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/gp_scaffold.dart';
import '../../../core/widgets/help_button.dart';
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
  /// Real picked attachment from camera or gallery. The previous
  /// implementation stored a fabricated filename string ("Screenshot
  /// 2026-05-16.png") that never actually pointed at anything; now
  /// we hold the live `XFile` so the report submission can ship the
  /// basename to the backend (and a future iteration can upload the
  /// bytes). Stays null when no attachment is picked, which is also
  /// the only state where the "Remove" affordance is hidden — the
  /// previous sheet always showed remove even on a fresh report
  /// because the options were treated as a generic list rather than
  /// real actions.
  XFile? _attachment;
  bool _submitting = false;
  final _gymCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();

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
        ..showSnackBar(SnackBar(duration: const Duration(seconds: 4), content: Text(l.reportMissingFields)));
      return;
    }
    setState(() => _submitting = true);
    final gym = _gymCtrl.text.trim();
    final ticketRef = await ref.read(supportTicketsProvider.notifier).submitReport(
          category: _category!,
          description: _descCtrl.text.trim(),
          gym: gym.isEmpty ? null : gym,
          attachment: _attachment?.name,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    await _showConfirmation(l, ticketRef);
    if (!mounted) return;
    setState(() {
      _category = null;
      _attachment = null;
      _gymCtrl.clear();
      _descCtrl.clear();
    });
  }

  /// Open the attach-evidence sheet. Each row maps to a real action:
  ///   - Camera roll → `image_picker.pickImage(source: gallery)`
  ///   - Take a photo → `image_picker.pickImage(source: camera)`
  ///   - Remove → drop the current attachment (shown only when one
  ///     is present)
  ///
  /// Previously this sheet stored fabricated filenames against each
  /// option as if the user had selected one from a list — the member
  /// saw "Screenshot 2026-05-16.png" attach without anything actually
  /// happening, and remove sat alongside the picker options as if
  /// it were just another file source. Now each row triggers the
  /// matching system intent and the picked `XFile` becomes the live
  /// attachment.
  Future<void> _pickAttachment(AppLocalizations l, GpColors gp) async {
    final hasAttachment = _attachment != null;
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
              _AttachOption(
                icon: Icons.photo_camera_outlined,
                label: l.reportAttachPhoto,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickFromSource(l, ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              _AttachOption(
                icon: Icons.photo_library_outlined,
                label: l.reportAttachCameraRoll,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickFromSource(l, ImageSource.gallery);
                },
              ),
              if (hasAttachment) ...[
                const SizedBox(height: 8),
                _AttachOption(
                  icon: Icons.delete_outline,
                  label: l.reportAttachRemove,
                  danger: true,
                  onTap: () {
                    setState(() => _attachment = null);
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Hand off to `image_picker` for the requested source. On a denial
  /// or platform error we surface a snackbar instead of silently
  /// reverting — the member tapped expecting an outcome, so they
  /// deserve to know if nothing happened. Quality is capped at 1600 px
  /// long-edge so a 12-MP back-camera photo doesn't bloat the eventual
  /// upload to the backend.
  Future<void> _pickFromSource(
    AppLocalizations l,
    ImageSource source,
  ) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (!mounted) return;
      if (picked == null) return;
      setState(() => _attachment = picked);
    } on PlatformException catch (err) {
      if (!mounted) return;
      final isDenied = err.code == 'photo_access_denied' ||
          err.code == 'camera_access_denied';
      final message = isDenied
          ? (source == ImageSource.camera
              ? l.reportAttachCameraDenied
              : l.reportAttachGalleryDenied)
          : l.reportAttachPickFailed;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(duration: const Duration(seconds: 4), content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(duration: const Duration(seconds: 4), content: Text(l.reportAttachPickFailed)));
    }
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
    return GpScaffold(
      tips: [
        HelpTip(icon: Icons.category_outlined, text: l.helpSupportReport1),
        HelpTip(icon: Icons.attach_file_rounded, text: l.helpSupportReport2),
        HelpTip(icon: Icons.location_on_outlined, text: l.helpSupportReport3),
      ],
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
    final attachment = _attachment;
    final attached = attachment != null;
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
              // Real thumbnail when attached, neutral placeholder otherwise.
              // Image.file is fine here — the XFile path is a temp dir
              // owned by image_picker and survives the page lifetime.
              if (attached)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(attachment.path),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: gp.accentInk.withValues(alpha: 0.15),
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image_outlined,
                          size: 20, color: gp.accentInk,),
                    ),
                  ),
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: gp.accentInk.withValues(alpha: 0.15),
                    border: Border.all(
                      color: gp.accentInk.withValues(alpha: 0.4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: gp.accentInk,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  attached ? attachment.name : l.reportAttachPlaceholder,
                  style: GPText.body(
                    size: 14,
                    color: gp.fg,
                    weight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

/// Single row inside the attach-evidence sheet. Kept as a private
/// widget so the `danger` styling (red icon + red label, used by
/// the Remove option) doesn't sprinkle conditionals across the
/// caller. Each row is a real action — taps invoke camera /
/// gallery / remove — so the row is responsible for dismissing the
/// sheet via the onTap caller.
class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final color = danger ? GP.danger : gp.accentInk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: gp.bg3,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(color: gp.line),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GPText.body(
                    size: 14,
                    color: danger ? GP.danger : gp.fg,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
