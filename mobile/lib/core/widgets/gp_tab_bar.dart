import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

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

  static const _tabs = <(String, IconData, IconData)>[
    ('home',    Icons.home,            Icons.home_outlined),
    ('explore', Icons.explore,         Icons.explore_outlined),
    ('scan',    Icons.qr_code_scanner, Icons.qr_code_2),
    ('profile', Icons.person,          Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: BoxDecoration(
        color: gp.bg,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: _tabs.map((t) {
            final isActive = active == t.$1;
            final isScan = t.$1 == 'scan';
            return Expanded(
              child: _TabItem(
                tabKey: t.$1,
                filledIcon: t.$2,
                outlinedIcon: t.$3,
                isActive: isActive,
                gp: gp,
                onTap: () {
                  HapticFeedback.selectionClick();
                  isScan ? onScan() : onTab(t.$1);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({
    required this.tabKey,
    required this.filledIcon,
    required this.outlinedIcon,
    required this.isActive,
    required this.gp,
    required this.onTap,
  });

  final String tabKey;
  final IconData filledIcon;
  final IconData outlinedIcon;
  final bool isActive;
  final GpColors gp;
  final VoidCallback onTap;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final color = isActive ? widget.gp.accentInk : widget.gp.muted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: SizedBox(
          height: 46,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  isActive ? widget.filledIcon : widget.outlinedIcon,
                  key: ValueKey('${widget.tabKey}_$isActive'),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: isActive ? 20 : 0,
                height: 2.5,
                decoration: BoxDecoration(
                  color: widget.gp.accentInk,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: widget.gp.accentInk.withValues(alpha: 0.65),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
