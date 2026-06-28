import 'package:flutter/material.dart';

import '../../../../core/theme/gp_tokens.dart';
import '../../../../core/widgets/gym_loader.dart';
import '../../../../core/widgets/icon_btn.dart';

/// Skeleton shown while the backend gym summary is in flight for a
/// slug that isn't part of the hardcoded `GPGym.seed` list (i.e.
/// every gym onboarded by an admin / imported from OSM). Without
/// this, the page would render the seed-first fallback (Iron Forge)
/// for the ~150-400 ms between mount and first network response,
/// producing the "every gym briefly looks like Iron Forge" bug.
///
/// The skeleton mirrors the page's actual silhouette — hero block,
/// title bar, body slot — so the real page slides in without a
/// layout shift when the data lands.
class LoadingDetailSkeleton extends StatelessWidget {
  const LoadingDetailSkeleton({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Scaffold(
      backgroundColor: gp.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero block — fills available height so the skeleton
                // never overflows on short screens (e.g. when the
                // keyboard is open or the device is small).
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: Container(
                      decoration: BoxDecoration(
                        color: gp.bg2,
                        border: Border(
                          bottom: BorderSide(color: gp.line),
                        ),
                      ),
                      child: const Center(
                        child: GymLoader(size: GymLoaderSize.large),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Title placeholder bar.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 24,
                    width: 220,
                    decoration: BoxDecoration(
                      color: gp.bg2,
                      borderRadius: BorderRadius.circular(GPRadius.sm),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Subtitle placeholder bar.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 14,
                    width: 140,
                    decoration: BoxDecoration(
                      color: gp.bg2,
                      borderRadius: BorderRadius.circular(GPRadius.sm),
                    ),
                  ),
                ),
              ],
            ),
            const PositionedDirectional(
              top: 12,
              start: 20,
              child: BackBtn(fallback: '/explore'),
            ),
          ],
        ),
      ),
    );
  }
}
