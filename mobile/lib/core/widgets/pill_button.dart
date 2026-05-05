import 'package:flutter/material.dart';

import '../theme/gp_text.dart';
import '../theme/gp_tokens.dart';

enum PillVariant { primary, secondary, ghost }

class PillButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final gp = context.gp;
    final isPrimary = variant == PillVariant.primary;
    final isSecondary = variant == PillVariant.secondary;
    final isDisabled = onPressed == null;

    final textColor = isPrimary
        ? (isDisabled ? gp.muted : gp.onLime)
        : (isDisabled ? gp.muted : gp.fg);

    // Wrap the label in Flexible so side-by-side PillButtons (e.g. the
    // invite-page SHARE / COPY row) can't overflow when the combined label +
    // icon + padding exceeds half the screen. Ellipsis is a last-resort:
    // callers should pick labels that actually fit — this just prevents the
    // striped overflow stripe if they don't.
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 16, color: textColor),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: GPText.ctaLabel.copyWith(color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 10),
          Icon(trailingIcon, size: 16, color: textColor),
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
          : (variant == PillVariant.ghost
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
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: decoration,
      alignment: Alignment.center,
      child: child,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.pill),
        onTap: onPressed,
        child: expand
            ? SizedBox(width: double.infinity, child: body)
            : body,
      ),
    );
  }
}
