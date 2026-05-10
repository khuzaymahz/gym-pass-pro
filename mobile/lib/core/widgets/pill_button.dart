import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../theme/gp_text.dart';
import '../theme/gp_tokens.dart';

enum PillVariant { primary, secondary, ghost }

/// Brand pill button. Used for every page-level CTA.
///
/// Press affordance:
///   - **Scale**: 1.0 → 0.97 over 120 ms with `easeOut`. Subtle but
///     enough that the button reads as physical — the same trick
///     `GymRow` uses, just gentler since the pill is bigger.
///   - **Ripple**: Material InkWell on top, so the touch point also
///     gets a soft ink wash.
///   - **Haptic**: `lightImpact` fires on primary-variant taps. The
///     "I felt that" cue Apple's first-party UI uses for any
///     consequential action; secondary/ghost variants stay silent
///     so dense option grids don't chatter.
class PillButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final PillVariant variant;
  final IconData? trailingIcon;
  final IconData? leadingIcon;
  final bool expand;
  final double height;

  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PillVariant.primary,
    this.trailingIcon,
    this.leadingIcon,
    this.expand = true,
    this.height = 56,
  });

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final isPrimary = widget.variant == PillVariant.primary;
    final isSecondary = widget.variant == PillVariant.secondary;
    final isDisabled = widget.onPressed == null;

    final textColor = isPrimary
        ? (isDisabled ? gp.muted : gp.onLime)
        : (isDisabled ? gp.muted : gp.fg);

    // Wrap the label in Flexible so side-by-side PillButtons (e.g. the
    // invite-page SHARE / COPY row) can't overflow when the combined label +
    // icon + padding exceeds half the screen. Ellipsis is a last-resort:
    // callers should pick labels that actually fit — this just prevents the
    // striped overflow stripe if they don't.
    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.leadingIcon != null) ...[
          Icon(widget.leadingIcon, size: 16, color: textColor),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            widget.label.toUpperCase(),
            style: GPText.ctaLabel.copyWith(color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: 10),
          Icon(widget.trailingIcon, size: 16, color: textColor),
        ],
      ],
    );

    final primaryGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [gp.accentHi, gp.accent],
    );

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(GPRadius.pill),
      gradient: isPrimary && !isDisabled ? primaryGradient : null,
      color: isPrimary && isDisabled
          ? gp.bg3
          : (isSecondary
              ? gp.bg3
              : (isPrimary ? null : Colors.transparent)),
      border: isSecondary
          ? Border.all(color: gp.line2)
          : (widget.variant == PillVariant.ghost
              ? Border.all(color: gp.line)
              : (isPrimary && isDisabled
                  ? Border.all(color: gp.line)
                  : null)),
      boxShadow: isPrimary && !isDisabled
          ? [
              BoxShadow(
                color: gp.accent.withValues(alpha: 0.18),
                blurRadius: 20,
                spreadRadius: -6,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );

    final body = Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: decoration,
      alignment: Alignment.center,
      child: child,
    );

    return AnimatedScale(
      scale: (_pressed && !isDisabled) ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GPRadius.pill),
          onTap: isDisabled
              ? null
              : () {
                  if (isPrimary) HapticFeedback.lightImpact();
                  widget.onPressed!();
                },
          onHighlightChanged: _setPressed,
          child: widget.expand
              ? SizedBox(width: double.infinity, child: body)
              : body,
        ),
      ),
    );
  }
}
