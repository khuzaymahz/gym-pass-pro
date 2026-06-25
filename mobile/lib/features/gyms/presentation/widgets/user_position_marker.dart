import 'package:flutter/material.dart';

import '../../../../core/theme/gp_tokens.dart';

/// "You are here" dot rendered on the explore map at the member's
/// resolved position. Three layers of the classic Google-Maps user
/// pin pattern:
///
///   - **Outer halo** at low alpha — a soft 28-px circle that
///     hints at GPS accuracy without claiming a precise radius.
///   - **White ring** — a 16-px disc that separates the inner dot
///     from the halo + tile texture so the marker reads on any
///     map background (the dark CARTO basemap, the warm-paper
///     light basemap, green parks, yellow roads).
///   - **Inner dot** — the saturated blue centre, 10 px.
///
/// Hard-coded blue (`#1A73E8`) rather than a tier colour so the
/// member never confuses "you are here" with a gym pin. Static
/// — no pulse, no animation. The locate-me FAB animation is
/// where the "found you" feedback lives; the dot itself stays
/// quiet so the eye registers it as a location, not as something
/// that wants attention.
class UserPositionMarker extends StatelessWidget {
  const UserPositionMarker({super.key});

  // Off-palette by convention — Maps users globally recognise this
  // shade of blue as "your location". Pulling from `GP.userPositionBlue`
  // keeps the hex out of the widget body so a future palette
  // adjustment is one line.
  static const Color _userBlue = GP.userPositionBlue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _userBlue.withValues(alpha: 0.22),
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _userBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
