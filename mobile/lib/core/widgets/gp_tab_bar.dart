import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../l10n/app_localizations.dart';
import '../theme/gp_text.dart';
import '../theme/gp_tokens.dart';

class GpTabBar extends StatelessWidget {
  final String active;
  final ValueChanged<String> onTab;
  final VoidCallback onScan;

  const GpTabBar({
    super.key,
    required this.active,
    required this.onTab,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final tabs = <(String, String, IconData)>[
      ('home', l.tabHome, Icons.home_outlined),
      // Explore tab — was a list; now a map. Key stays in sync with
      // the home shell's `_currentKey` and the `/explore` route.
      // Icon is unchanged because explore_outlined is already what
      // the member associates with this slot.
      ('explore', l.tabExplore, Icons.explore_outlined),
      ('scan', l.tabScan, Icons.qr_code_2),
      ('profile', l.tabProfile, Icons.person_outline),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: gp.bg,
        border: Border(top: BorderSide(color: gp.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: tabs.map((t) {
            final isActive = active == t.$1;
            final isScan = t.$1 == 'scan';
            return Expanded(
              child: _TabItem(
                tabKey: t.$1,
                label: t.$2,
                icon: t.$3,
                isActive: isActive,
                gp: gp,
                onTap: () => isScan ? onScan() : onTab(t.$1),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Single bottom-nav tab. Manages its own press state so the tap
/// feedback is local — no setState ripples up to the whole bar
/// when a thumb hits one tab.
///
/// Press affordance:
///   - **Scale**: 1.0 → 0.92 over 120 ms. Same compression as
///     `IconBtn` so all icon-only press surfaces in the app feel
///     consistent.
///   - **Haptic**: `selectionClick` on every tap (active tab too —
///     the member tapped *something*, the click confirms it
///     registered even when there's no nav). iOS standard for
///     selection changes; Android maps to a similar light click.
///   - **Underline indicator**: existing `AnimatedContainer`
///     (320 ms easeOutCubic) keeps owning the active-tab ink bar
///     — that motion is about state, this scale is about touch.
class _TabItem extends StatefulWidget {
  final String tabKey;
  final String label;
  final IconData icon;
  final bool isActive;
  final GpColors gp;
  final VoidCallback onTap;

  const _TabItem({
    required this.tabKey,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.gp,
    required this.onTap,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isActive ? widget.gp.accentInk : widget.gp.muted;
    final labelColor = widget.isActive ? widget.gp.fg : widget.gp.muted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(
              widget.label.toUpperCase(),
              style: GPText.mono(
                size: 9,
                letterSpacing: 1.4,
                color: labelColor,
                weight:
                    widget.isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              width: widget.isActive ? 28 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: widget.gp.accentInk,
                borderRadius: BorderRadius.circular(2),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: widget.gp.accentInk.withValues(alpha: 0.7),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
