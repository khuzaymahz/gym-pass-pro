import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../data/gym_initials.dart';
import '../../data/gym_summary.dart';
import '../../data/media_url.dart';

/// Logo-as-pin marker. Renders the gym's circular logo (or initials
/// fallback) with a tier-coloured ring + flat drop shadow and a small
/// needle below pointing at the actual lat/lng.
///
/// Selection cue is **size-only**, deliberately. The earlier
/// implementation animated the accent-coloured box shadow (alpha +
/// blur) on tap — that produced a brief yellow glow flash for
/// untiered gyms and read as buggy when switching between pins. Now
/// the only thing that animates is the pin's circle size (38 → 42 px)
/// and ring thickness (2 → 2.5 px); the colours and the drop shadow
/// stay constant, so the pin glides between states without a colour
/// change or pulse.
///
/// Tap behaviour:
///   - Single tap → [onTap] fires after the gesture-recogniser
///     resolves single vs double (~250 ms). Parent uses this to
///     show the floating profile card.
///   - Double tap → [onDoubleTap] fires immediately on the second
///     tap. Parent uses this to navigate straight to the gym
///     detail page (skipping the card overlay).
class GymPinMarker extends ConsumerWidget {
  const GymPinMarker({
    super.key,
    required this.gym,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final GymSummary gym;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gp = context.gp;
    // `tryByKey` returns null on any unknown / malformed tier string
    // — empty, whitespace, miscapitalised, or just absent. The
    // permissive `byKey` would have fallen back to a default tier
    // and rendered the pin in that default's brand colour, which
    // lies about which gym network the partner sits in. Strict
    // lookup here + neutral grey fallback below keep the map's
    // tier-colour cue truthful.
    final tier = GPTier.tryByKey(gym.tier);
    final accent = tier?.color ?? gp.muted;
    final apiBaseUrl = ref.watch(envProvider).apiBaseUrl;
    final initial = gymInitials(gym.nameEn);
    // Hard-coded pin geometry — see `_baseSize` / `_selectedScale`
    // notes below. Border thickness is fixed at 2 px regardless of
    // selection state so nothing involving colour ever animates.
    const baseSize = 38.0;
    const selectedScale = 42.0 / 38.0; // 1.105
    const ringWidth = 2.0;
    // 42 px max × DPR × 2 (Hero handoff into the detail page); capped
    // at 128 raw pixels so a hundred pins on screen don't keep a
    // hundred 1000-px JPEGs decoded in RAM.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final pixelSize = (42 * dpr * 2).round().clamp(64, 128);

    // The decoration is built ONCE per pin per build, never on a
    // colour-lerping animator. Earlier versions ran the whole
    // BoxDecoration through `AnimatedContainer.decoration`, which
    // re-creates a new Border instance each rebuild and tweens its
    // properties — even with identical start/end colours, the
    // intermediate raster passes anti-aliased differently, and
    // members read the sub-frame edge artifacts as "the pin
    // flashed." Pulling the decoration out and animating only the
    // scale removes that whole class of bug at the source.
    final pinDecoration = BoxDecoration(
      shape: BoxShape.circle,
      color: gp.bg2,
      border: Border.all(color: accent, width: ringWidth),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.40),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selection cue: **scale only**, no colour, no border
          // thickness change. AnimatedScale runs a Tween on the
          // matrix transform — the underlying widget tree (border
          // colour, box shadow, image) never re-rasterizes during
          // the animation, so there is literally no colour-channel
          // path that could blink. Members read the 5 % size bump
          // as "this one is selected"; switching between pins
          // shrinks the outgoing and grows the incoming in
          // parallel without any flash.
          AnimatedScale(
            scale: selected ? selectedScale : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Container(
            width: baseSize,
            height: baseSize,
            decoration: pinDecoration,
            clipBehavior: Clip.antiAlias,
            // Real partner logo when available; tier-coloured initial
            // disc when not. Cached + decoded-to-pin-size so panning a
            // map full of pins doesn't refetch logos every frame.
            // Sharing the same `CachedNetworkImageProvider` URL with
            // the gym detail Hero means the detail page's header logo
            // appears instantly when a member taps through from the map.
            //
            // Two deliberate divergences from the standard
            // `CachedNetworkImage` defaults, both targeting the
            // "yellow blink while switching pins" bug:
            //
            //   1. **`fadeInDuration: Duration.zero`** — kills the
            //      placeholder→image crossfade. The cached bitmap is
            //      already in memory (the home + detail pages
            //      pre-warm it via `GymLogo`), so the fade was 160 ms
            //      of unnecessary transition that the user read as a
            //      flash whenever the marker State rebuilt during a
            //      selection switch.
            //   2. **Neutral `bg3` placeholder** instead of the
            //      tier-coloured initials. Even an actual cache miss
            //      now lands on a quiet grey disc rather than a
            //      bright amber/cyan letter that flashes through the
            //      transition. The initials still show as the
            //      hard-error fallback (`errorWidget`) and as the
            //      no-logo branch below, where they're the *intended*
            //      visual — never as a transient state.
            child: gym.logoUrl != null && gym.logoUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: resolveMediaUrl(apiBaseUrl, gym.logoUrl!),
                    // `contain` (not `cover`) so the partner's
                    // entire logo always fits inside the pin
                    // circle. Cover *fills* the box and slices
                    // anything that doesn't fit — for partners
                    // who uploaded logos with built-in margin or
                    // non-square aspect, the result was cropped
                    // wordmarks and clipped icons. Contain
                    // letterboxes the image with a small grey
                    // band against `gp.bg2` if the aspect doesn't
                    // match, but the whole logo is always
                    // visible.
                    fit: BoxFit.contain,
                    memCacheWidth: pixelSize,
                    memCacheHeight: pixelSize,
                    maxWidthDiskCache: pixelSize,
                    maxHeightDiskCache: pixelSize,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (_, __) => Container(color: gp.bg3),
                    errorWidget: (_, __, ___) => Center(
                      child: Text(
                        initial,
                        style: GPText.display(
                          initial.characters.length >= 2 ? 12.0 : 16.0,
                          color: accent,
                          height: 1.0,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: GPText.display(
                        initial.characters.length >= 2 ? 12.0 : 16.0,
                        color: accent,
                        height: 1.0,
                      ),
                    ),
                  ),
            ),
          ),
          // Pin needle — a small tier-coloured triangle pointing at
          // the lat/lng under the logo. Just enough to read as a pin
          // instead of a floating circle.
          CustomPaint(
            size: const Size(10, 8),
            painter: _PinNeedlePainter(color: accent),
          ),
        ],
      ),
    );
  }
}

class _PinNeedlePainter extends CustomPainter {
  _PinNeedlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // Qualified `ui.Path` because flutter_map exports its own
    // `Path<LatLng>` from `flutter_map.dart` which collides with
    // `dart:ui`'s drawing Path. Using the alias is unambiguous.
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinNeedlePainter old) => old.color != color;
}
