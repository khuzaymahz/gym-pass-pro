import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/gp_tokens.dart';

/// Round icon button for header chrome — back, fav, share, etc.
///
/// Press affordance:
///   - **Scale**: 1.0 → 0.92 over 120 ms with `easeOut`. Slightly
///     stronger compression than `PillButton` (0.97) because at
///     40 px the button is small enough that a 3 % shrink reads
///     as no movement at all; 8 % is the threshold where the
///     button visibly *responds* without feeling jumpy.
///   - **Ripple**: Material InkWell paints under the icon for a
///     touch-point ink wash on top of the scale.
class IconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool badge;
  final double size;
  final Color? tint;

  const IconBtn({
    super.key,
    required this.icon,
    this.onPressed,
    this.badge = false,
    this.size = 40,
    this.tint,
  });

  @override
  State<IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<IconBtn> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedScale(
          scale: (_pressed && !isDisabled) ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(GPRadius.pill),
              onTap: widget.onPressed,
              onHighlightChanged: _setPressed,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: context.gp.bg3,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.gp.line2),
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: Icon(
                    widget.icon,
                    key: ValueKey(widget.icon),
                    size: 18,
                    color: widget.tint ?? context.gp.fg,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.badge)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: context.gp.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.gp.accent.withValues(alpha: 0.7),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class BackBtn extends StatelessWidget {
  final VoidCallback? onPressed;
  final String fallback;
  const BackBtn({super.key, this.onPressed, this.fallback = '/home'});

  @override
  Widget build(BuildContext context) {
    // Direction-aware back affordance:
    //   - LTR (English): icon points LEFT, button anchors visual-left
    //     of the page header.
    //   - RTL (Arabic):  icon points RIGHT, button anchors visual-right
    //     of the page header (callers use `PositionedDirectional` /
    //     `Row` without forced LTR so the natural reading order
    //     places it correctly).
    // Flutter's `Material Icons.arrow_back` is *not* auto-mirrored by
    // the Icon widget on its own — we flip it explicitly so the
    // arrowhead always points to where "previous" comes from in the
    // current reading order.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return IconBtn(
      icon: isRtl ? Icons.arrow_forward : Icons.arrow_back,
      onPressed: onPressed ??
          () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(fallback);
            }
          },
    );
  }
}
