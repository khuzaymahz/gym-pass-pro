import 'package:flutter/material.dart';

import '../theme/gp_tokens.dart';

/// Skeleton primitives used during pull-to-refresh and first loads.
///
/// **Design intent**: when the member pulls to refresh, the existing
/// cards morph into low-contrast block placeholders that pulse softly.
/// The placeholders preserve the *shape* of the real content so the
/// page doesn't shift when real data slides back in. This replaces
/// the previous behaviour where a dumbbell spinner overlaid the
/// (still-visible) old content — seeing the old content while the
/// refresh ran created the illusion that nothing was happening.
///
/// **Pulse, not shimmer**: classic Material skeletons sweep a bright
/// gradient across the box. Up close that reads as "this surface
/// is shiny" rather than "this surface is loading," and on dark
/// themes the bright sweep flares. A subtle opacity pulse (0.55 →
/// 0.85) reads as "thinking" without competing with the rest of the
/// chrome.
///
/// All primitives use the same controller-driven pulse so multiple
/// skeletons in the same view breathe together rather than
/// staggering — the screen reads as a single calm system instead
/// of a flicker of independent rectangles.

/// Bare rectangular placeholder. Build the rest of the skeleton out
/// of these — a card is a column of [SkeletonBox]es of varying
/// widths and heights.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.radius = 6,
  });

  final double height;

  /// Null = stretch to parent width (use inside a Column /
  /// SizedBox.expand). A finite value clamps the box.
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // 1.4 s per cycle — slow enough to read as "considered" rather
    // than urgent (urgent suggests an error). Reverses on each
    // half-cycle so the opacity ramps both ways.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // Opacity ramp 0.55 → 0.95 with an ease curve so the
        // pulse feels like a breath, not a strobe.
        final t = Curves.easeInOut.transform(_ctrl.value);
        final alpha = 0.55 + 0.40 * t;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: gp.bg3.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// Skeleton stand-in for a `GymRow` — logo on the start, two text
/// lines, tier dot on the end. Same outer dimensions as a real row
/// so the list doesn't shift when real data lands.
class SkeletonGymRow extends StatelessWidget {
  const SkeletonGymRow({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
      ),
      child: const Row(
        children: [
          SkeletonBox(height: 56, width: 56, radius: 12),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14, width: 140),
                SizedBox(height: 8),
                SkeletonBox(height: 10, width: 90),
              ],
            ),
          ),
          SkeletonBox(height: 10, width: 10, radius: 5),
        ],
      ),
    );
  }
}

/// Skeleton stand-in for the home page's `_PlanCard` — tier chip
/// top-start, status pill top-end, big visit number + cycle bar,
/// then the per-cycle / term-progress lines. Same outer dimensions
/// as the live card so the page below doesn't shift.
class SkeletonPlanCard extends StatelessWidget {
  const SkeletonPlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.xl),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(height: 22, width: 70, radius: 11),
              Spacer(),
              SkeletonBox(height: 22, width: 60, radius: 6),
            ],
          ),
          SizedBox(height: 18),
          // Big visit-count line — wide-ish block to mimic the
          // "0 /30 visits" text height.
          SkeletonBox(height: 38, width: 140),
          SizedBox(height: 18),
          SkeletonBox(height: 6, radius: 3),
          SizedBox(height: 14),
          Row(
            children: [
              SkeletonBox(height: 11, width: 130),
              Spacer(),
              SkeletonBox(height: 11, width: 60),
            ],
          ),
          SizedBox(height: 6),
          SkeletonBox(height: 9, width: 200),
        ],
      ),
    );
  }
}

/// Skeleton stand-in for a billing payment-method tile.
class SkeletonMethodTile extends StatelessWidget {
  const SkeletonMethodTile({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
      ),
      child: const Row(
        children: [
          SkeletonBox(height: 40, width: 40, radius: 10),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14, width: 120),
                SizedBox(height: 6),
                SkeletonBox(height: 10, width: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton stand-in for a single invoice row.
class SkeletonInvoiceRow extends StatelessWidget {
  const SkeletonInvoiceRow({super.key, this.showDivider = true});

  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        children: [
          const Row(
            children: [
              SkeletonBox(height: 28, width: 28, radius: 6),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 11, width: 160),
                    SizedBox(height: 6),
                    SkeletonBox(height: 9, width: 100),
                  ],
                ),
              ),
              SkeletonBox(height: 11, width: 60),
            ],
          ),
          if (showDivider) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: gp.line),
          ],
        ],
      ),
    );
  }
}

/// Skeleton stand-in for a notification row.
class SkeletonNotificationRow extends StatelessWidget {
  const SkeletonNotificationRow({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 8, width: 8, radius: 4),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 13, width: 180),
                SizedBox(height: 8),
                SkeletonBox(height: 11, width: 240),
                SizedBox(height: 8),
                SkeletonBox(height: 9, width: 70),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
