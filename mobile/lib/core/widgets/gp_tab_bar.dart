import 'package:flutter/material.dart';

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
              child: GestureDetector(
                onTap: () => isScan ? onScan() : onTab(t.$1),
                behavior: HitTestBehavior.opaque,
                child: _TabItem(
                  label: t.$2,
                  icon: t.$3,
                  isActive: isActive,
                  gp: gp,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final GpColors gp;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.gp,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? gp.accentInk : gp.muted;
    final labelColor = isActive ? gp.fg : gp.muted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: GPText.mono(
            size: 9,
            letterSpacing: 1.4,
            color: labelColor,
            weight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: isActive ? 28 : 0,
          height: 2,
          decoration: BoxDecoration(
            color: gp.accentInk,
            borderRadius: BorderRadius.circular(2),
            boxShadow: isActive
                ? [BoxShadow(color: gp.accentInk.withValues(alpha: 0.7), blurRadius: 8)]
                : null,
          ),
        ),
      ],
    );
  }
}
