import 'package:flutter/material.dart';

import '../../../../core/theme/gp_tokens.dart';

/// Locate-me FAB. Sits over the map's trailing edge; the parent's
/// onTap pans the camera to the member's GPS position (or kicks off
/// a fresh permission request + GPS read on first tap).
class LocateMeButton extends StatelessWidget {
  const LocateMeButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Material(
      color: gp.bg2.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: gp.line),
          ),
          child: Icon(Icons.my_location, size: 20, color: gp.fg),
        ),
      ),
    );
  }
}
