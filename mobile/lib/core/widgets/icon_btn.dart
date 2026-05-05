import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/gp_tokens.dart';

class IconBtn extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(GPRadius.pill),
            onTap: onPressed,
            child: Container(
              width: size,
              height: size,
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
                  icon,
                  key: ValueKey(icon),
                  size: 18,
                  color: tint ?? context.gp.fg,
                ),
              ),
            ),
          ),
        ),
        if (badge)
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
