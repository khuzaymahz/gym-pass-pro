import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../theme/gp_tokens.dart';

class GpTabBar extends StatefulWidget {
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

  static const _tabKeys = ['home', 'explore', 'scan', 'profile'];

  static int _indexForKey(String key) {
    final i = _tabKeys.indexOf(key);
    return i < 0 ? 0 : i;
  }

  @override
  State<GpTabBar> createState() => _GpTabBarState();
}

class _GpTabBarState extends State<GpTabBar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Tween<double> _tween;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final startIdx = GpTabBar._indexForKey(widget.active).toDouble();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _tween = Tween<double>(begin: startIdx, end: startIdx);
    _anim = _tween.animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(covariant GpTabBar old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      final newIdx = GpTabBar._indexForKey(widget.active).toDouble();
      _tween = Tween<double>(begin: _anim.value, end: newIdx);
      _anim = _tween.animate(
        CurvedAnimation(parent: _ctrl..reset()..forward(), curve: Curves.easeOutBack),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: BoxDecoration(color: gp.bg),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (_, constraints) {
            final tabW = constraints.maxWidth / GpTabBar._tabs.length;
            return Stack(
              children: [
                Row(
                  children: GpTabBar._tabs.map((t) {
                    final isActive = widget.active == t.$1;
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
                          isScan ? widget.onScan() : widget.onTab(t.$1);
                        },
                      ),
                    );
                  }).toList(),
                ),
                // Single indicator slides between tabs with a spring-like
                // overshoot (easeOutBack), giving a sticky/travel feel.
                AnimatedBuilder(
                  animation: _anim,
                  builder: (_, __) {
                    final x = tabW * _anim.value + (tabW - 20) / 2;
                    return Positioned(
                      bottom: 7,
                      left: x,
                      child: Container(
                        width: 20,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: gp.accentInk,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: gp.accentInk.withValues(alpha: 0.65),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
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
              // Spacing to keep icon centred at the same Y as before.
              const SizedBox(height: 7),
            ],
          ),
        ),
      ),
    );
  }
}
