import 'package:flutter/material.dart';

import '../../../../core/theme/gp_tokens.dart';
import '../../../../core/widgets/gym_loader.dart';

/// Locate-me FAB. Sits over the map's trailing edge.
///
/// Two-gesture model:
///   - **Single tap** ([onTap]) — resolves the user's position and
///     frames their *region* with surrounding gyms ("eagle view").
///     The default affordance: members usually want to see what's
///     near them, not exactly where they're standing.
///   - **Double tap** ([onDoubleTap], optional) — resolves and
///     zooms tight on the user dot. Power-user shortcut for
///     "where exactly am I" without sacrificing the default's
///     region-aware framing. Falls back to single-tap behaviour
///     if the parent doesn't provide a handler.
///
/// While [loading] is true the icon swaps for the brand
/// [GymLoader] (small) and both gestures are disabled — gives the
/// member a visible "I heard you, finding you now" cue while
/// geolocator does its 0–8 s work, and stops a tap-spam from
/// queueing overlapping requests. The dumbbell loader matches the
/// app's other "we're working" surfaces (warm-up overlay, sheet
/// load, payment overlay) so the loading vocabulary is consistent
/// across every wait state.
class LocateMeButton extends StatelessWidget {
  const LocateMeButton({
    super.key,
    required this.onTap,
    this.onDoubleTap,
    this.loading = false,
  });

  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
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
        onDoubleTap: (loading || onDoubleTap == null) ? null : onDoubleTap,
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
              ? const GymLoader(size: GymLoaderSize.small)
              : Icon(Icons.my_location, size: 20, color: gp.fg),
        ),
      ),
    );
  }
}
