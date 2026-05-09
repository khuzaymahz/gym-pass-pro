import 'package:flutter/material.dart';

import '../../features/gyms/data/gym_initials.dart';
import '../../features/gyms/data/gym_summary.dart';
import '../theme/gp_text.dart';
import '../theme/gp_tokens.dart';

/// Consistent visual mark for a gym, used everywhere the gym is referenced
/// (tiles, rows, plan network sheets, detail header). Renders the uploaded
/// logo when available; otherwise falls back to a flat ink disc + a
/// tier-coloured monogram (one or two letters, see `gymInitials`).
///
/// **Identity** matches the explore-map marker and popup hero: same tier
/// ring colour, same flat `gp.bg3` interior, same monogram. So a member
/// who taps a pin on the map sees the *same* mark on the detail page —
/// no surprise switch from a green-gradient square with one letter to a
/// circular tier ring with two. Tiers, not categories, drive the colour
/// because tier is the access-relevant signal at a glance.
class GymLogo extends StatelessWidget {
  const GymLogo({
    super.key,
    required this.gym,
    this.logoUrl,
    this.size = 54,
    this.shape = GymLogoShape.rounded,
  });

  /// Adapter for the real backend `GymSummary` payload — used by
  /// the plans-page network sheet, the explore list, and any other
  /// surface that fetches gyms from `/api/v1/gyms`. Maps the
  /// summary's tier slug + name + logoUrl onto the same widget the
  /// seed-driven sites use, so a single visual mark renders
  /// regardless of whether the gym data came from the seed
  /// fixture or the live backend.
  static Widget fromSummary(
    GymSummary summary, {
    required String? resolvedLogoUrl,
    double size = 54,
    GymLogoShape shape = GymLogoShape.rounded,
  }) {
    // Build a minimal `GPGym` shim so the inner painter doesn't
    // need to learn two data shapes. The logo widget only reads
    // `name` + `tierObj.color`; the rest of the GPGym fields are
    // satisfied with safe defaults.
    final tierKey = summary.tier ?? 'silver';
    final shim = GPGym(
      slug: summary.slug,
      name: summary.nameEn.isNotEmpty ? summary.nameEn : summary.nameAr,
      area: summary.area ?? '',
      category: summary.category ?? 'gym',
      tier: tierKey,
      lat: summary.lat ?? 0,
      lng: summary.lng ?? 0,
    );
    return GymLogo(
      gym: shim,
      logoUrl: resolvedLogoUrl,
      size: size,
      shape: shape,
    );
  }

  final GPGym gym;
  final String? logoUrl;
  final double size;
  final GymLogoShape shape;

  BorderRadius get _radius {
    switch (shape) {
      case GymLogoShape.circle:
        return BorderRadius.circular(size);
      case GymLogoShape.rounded:
        return BorderRadius.circular(size * 0.22);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final tier = gym.tierObj.color;
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;

    // Match the map marker: flat ink disc inside a tier-coloured ring.
    // The previous category-coloured gradient pulled the eye away from
    // the tier signal and made the same gym read differently on the
    // detail page than on the map. Single source of visual truth now.
    final frame = BoxDecoration(
      borderRadius: _radius,
      color: gp.bg3,
      border: Border.all(color: tier, width: size * 0.045),
      boxShadow: [
        BoxShadow(
          color: tier.withValues(alpha: 0.18),
          blurRadius: size * 0.35,
          offset: const Offset(0, 2),
        ),
      ],
    );

    return Semantics(
      label: gym.name,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: frame,
        clipBehavior: Clip.antiAlias,
        child: hasLogo
            ? Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return _FadeIn(child: child);
                  }
                  return _Initial(gym: gym, size: size);
                },
                errorBuilder: (_, __, ___) => _Initial(gym: gym, size: size),
              )
            : _Initial(gym: gym, size: size),
      ),
    );
  }
}

enum GymLogoShape { rounded, circle }

class _Initial extends StatelessWidget {
  const _Initial({required this.gym, required this.size});
  final GPGym gym;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mono = gymInitials(gym.name);
    // Two-letter monograms need a smaller font so "IF" fits the disc
    // as comfortably as a lone "H" would.
    final factor = mono.length >= 2 ? 0.36 : 0.5;
    return Center(
      child: Text(
        mono,
        style: GPText.display(
          size * factor,
          color: gym.tierObj.color,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Brief fade on logo reveal — small kinetic touch that makes tiles feel
/// alive as the screen paints, without being noisy enough to be a performance
/// cost on list scroll.
class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child});
  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      child: widget.child,
    );
  }
}
