import 'package:flutter/material.dart';

import '../../../../core/theme/gp_tokens.dart';

/// Locate-me FAB. Sits over the map's trailing edge; the parent's
/// onTap fires a fresh GPS read and pans the camera to the result.
///
/// While [loading] is true the icon swaps for a small lime spinner
/// and tap is disabled — gives the member a visible "I heard you,
/// finding you now" cue while geolocator does its 0–6 s work, and
/// stops a tap-spam from queueing overlapping requests.
class LocateMeButton extends StatelessWidget {
  const LocateMeButton({
    super.key,
    required this.onTap,
    this.loading = false,
  });

  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Material(
      color: gp.bg2.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      child: InkWell(
        onTap: loading ? null : onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: gp.line),
          ),
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(gp.accentInk),
                  ),
                )
              : Icon(Icons.my_location, size: 20, color: gp.fg),
        ),
      ),
    );
  }
}
