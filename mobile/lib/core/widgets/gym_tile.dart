import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/gyms/data/home_region_store.dart';
import '../theme/gp_text.dart';
import '../theme/gp_tokens.dart';
import 'gym_logo.dart';

class GymTile extends StatelessWidget {
  final GPGym gym;
  final double size;
  final String? logoUrl;

  const GymTile({super.key, required this.gym, this.size = 54, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    return GymLogo(gym: gym, logoUrl: logoUrl, size: size);
  }
}

/// Tier marker for gym rows. Single shape, color-only differentiation —
/// so a user scanning the list sees "Silver vs Gold vs Platinum vs Diamond"
/// without decoding four different glyphs.
class _TierDot extends StatelessWidget {
  const _TierDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

class GymRow extends ConsumerStatefulWidget {
  final GPGym gym;
  final VoidCallback? onTap;
  final String? logoUrl;

  const GymRow({super.key, required this.gym, this.onTap, this.logoUrl});

  @override
  ConsumerState<GymRow> createState() => _GymRowState();
}

class _GymRowState extends ConsumerState<GymRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  bool _pressed = false;

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final gym = widget.gym;
    // Distance is computed live from the user's GPS via the shared
    // [userPositionProvider]. Hidden when the GPS hasn't resolved
    // yet — better an honest blank than a stale "2.6 KM" that lied.
    final user = ref.watch(userPositionProvider);
    final distanceKm = (user == null)
        ? null
        : gym.distanceKmFrom(user.lat, user.lng);
    return FadeTransition(
      opacity: CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic),
        ),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(GPRadius.lg),
              onTap: widget.onTap,
              onHighlightChanged: (down) => setState(() => _pressed = down),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: gp.bg2,
                  borderRadius: BorderRadius.circular(GPRadius.lg),
                  border: Border.all(color: gp.line),
                  boxShadow: gp.cardShadows,
                ),
                child: Row(
                  children: [
                    Hero(
                      tag: 'gym-logo-${gym.slug}',
                      child: GymTile(gym: gym, size: 56, logoUrl: widget.logoUrl),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gym.name,
                            style: GPText.body(
                              size: 15,
                              weight: FontWeight.w600,
                              color: gp.fg,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(gym.area.toUpperCase(), style: GPText.mono(size: 10, letterSpacing: 1.4, color: gp.muted)),
                              if (distanceKm != null) ...[
                                const SizedBox(width: 8),
                                Container(width: 3, height: 3, decoration: BoxDecoration(color: gp.muted, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Text('${distanceKm.toStringAsFixed(1)} KM', style: GPText.mono(size: 10, letterSpacing: 1.4, color: gp.muted)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    _TierDot(color: gym.tierObj.color),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
