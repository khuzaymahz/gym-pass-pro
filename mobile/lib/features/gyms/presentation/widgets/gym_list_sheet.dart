import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../core/widgets/gym_loader.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/gym_initials.dart';
import '../../data/gym_summary.dart';
import '../../data/media_url.dart';
import 'explore_format.dart';

/// Snap heights for the explore bottom sheet (fractions of screen
/// height). Kept here so [GymListSheet] is self-contained — the
/// caller passes in a controller and these constants drive the snap
/// behaviour. See `ExplorePage` for the full design rationale.
const double exploreSheetMin = 0.066;
const double exploreSheetAutoOpen = 0.45;
// Tuned through user feedback: 0.84 was too tall (almost no map
// visible at full open), 0.74 was too short. 0.80 keeps a clear
// strip of map up top — enough to read the city you're in — while
// giving the gym list comfortable scroll height. The "edge-to-
// edge" intent is still served by drag (no snap, sheet can
// settle anywhere up to `maxChildSize`).
const double exploreSheetMax = 0.80;

/// Bottom sheet — the "slider" that holds the gym list. Floats over
/// the live map; drags between [exploreSheetMin] (sheet just shows
/// the handle + count) and [exploreSheetMax] (sheet covers most of
/// the map for full-list browsing). Sheet content is the same gym
/// list rows the previous list-first explore page rendered, so all
/// the search-highlight + distance + tier-ring affordances carry
/// over.
class GymListSheet extends ConsumerWidget {
  const GymListSheet({
    super.key,
    required this.controller,
    required this.onTapHandle,
    this.onDoubleTapHandle,
    required this.gyms,
    required this.query,
    required this.isLoading,
    required this.hasError,
    required this.onGymSelect,
    required this.distanceFor,
  });

  /// Drives programmatic snap animations from outside (e.g. tapping
  /// the handle to open the sheet without dragging).
  final DraggableScrollableController controller;
  final VoidCallback onTapHandle;

  /// Optional power-user shortcut. Single tap toggles
  /// min ↔ auto-open; double tap jumps the sheet to its max
  /// extent. Falls through to single-tap-only behaviour if the
  /// parent doesn't wire a handler.
  final VoidCallback? onDoubleTapHandle;
  final List<GymSummary> gyms;
  final String query;
  final bool isLoading;
  final bool hasError;

  /// Called when a row is tapped. The parent decides what "select"
  /// means (animate camera, raise the floating profile card, snap the
  /// sheet down) — the row itself just reports the intent.
  final ValueChanged<GymSummary> onGymSelect;
  final double? Function(GymSummary) distanceFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    return DraggableScrollableSheet(
      controller: controller,
      // Initial state: minimized — only the handle peeks above the
      // bottom nav. Member sees the map first; opens the list with a
      // tap on the handle, a drag, or by interacting with the search
      // field / filter button (auto-open in those paths).
      initialChildSize: exploreSheetMin,
      minChildSize: exploreSheetMin,
      maxChildSize: exploreSheetMax,
      // Free drag — no snap points. Members asked for the sheet
      // to settle wherever they release it, not slam to one of
      // three fixed sizes. The Uber-style three-snap model felt
      // clipped on this map UI: a member who wanted the list
      // 70 % open kept getting bounced to 84 % (max) or 45 %
      // (auto-open). The min / max bounds still constrain the
      // drag (so the sheet can't disappear or eat the screen),
      // but anything between those is now a valid resting size.
      // The named constants stay because programmatic moves
      // (tap-to-expand on the handle, search-focus auto-open,
      // map-tap collapse) still snap to those targets — only
      // the *drag* is free.
      snap: false,
      builder: (context, scrollCtrl) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: gp.bg2.withValues(alpha: 0.92),
                border: Border(top: BorderSide(color: gp.line, width: 0.5)),
              ),
              child: CustomScrollView(
                controller: scrollCtrl,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  // Tappable handle row — gives the operator a fast
                  // affordance to open the sheet without dragging.
                  // The pill graphic gets a wider hit-target around
                  // it (the whole 32-px tall row) so a thumb tap on
                  // the general area registers; tap toggles between
                  // peek and half-open snaps.
                  SliverToBoxAdapter(
                    child: _FastTapHandle(
                      onTap: onTapHandle,
                      onDoubleTap: onDoubleTapHandle,
                      child: SizedBox(
                        height: 32,
                        child: Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: gp.line2,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!isLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                        child: Text(
                          gyms.length == 1
                              ? l.exploreOneGymCount
                              : l.exploreGymCount(gyms.length),
                          style: GPText.mono(
                            size: 11,
                            letterSpacing: 1.4,
                            color: gp.muted,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: GymLoader(size: GymLoaderSize.regular),
                        ),
                      ),
                    )
                  else if (hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 40,
                        ),
                        child: Center(
                          child: Text(
                            l.snackErrorGeneric,
                            textAlign: TextAlign.center,
                            style: GPText.body(size: 14, color: gp.muted),
                          ),
                        ),
                      ),
                    )
                  else if (gyms.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 40,
                        ),
                        child: Center(
                          child: Text(
                            l.exploreNoMatches,
                            textAlign: TextAlign.center,
                            style: GPText.body(size: 14, color: gp.muted),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: gyms.length,
                      itemBuilder: (context, i) {
                        final gym = gyms[i];
                        return _GymListRow(
                          gym: gym,
                          distanceMeters: distanceFor(gym),
                          query: query,
                          // Tap selects the gym (camera move + card
                          // overlay + sheet collapse) — same end state
                          // as tapping the gym's pin on the map. The
                          // card itself routes to detail.
                          onTap: () => onGymSelect(gym),
                        );
                      },
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 16 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Single row in the explore list. Tier-ringed logo on the trailing
/// edge, name + meta on the leading. Tap = push gym detail.
class _GymListRow extends ConsumerWidget {
  const _GymListRow({
    required this.gym,
    required this.distanceMeters,
    required this.onTap,
    required this.query,
  });

  final GymSummary gym;
  final double? distanceMeters;
  final VoidCallback onTap;

  /// Active search query. When non-empty, the matching substring
  /// inside the gym name is painted in the brand accent.
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final name = isAr && gym.nameAr.isNotEmpty ? gym.nameAr : gym.nameEn;
    // Strict tier lookup — see the matching pattern in
    // `GymPinMarker`. The list-row hero ring is the same
    // tier-colour cue the map pin uses, and the same rule applies:
    // never fake a tier colour for a partner whose
    // `required_tier` field is missing or doesn't decode cleanly.
    final tier = GPTier.tryByKey(gym.tier);
    final accent = tier?.color ?? gp.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GPRadius.lg),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: gp.bg3.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(GPRadius.lg),
              border: Border.all(color: gp.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: HighlightedName(
                              text: name,
                              query: query,
                              base: GPText.body(
                                size: 16,
                                color: gp.fg,
                                weight: FontWeight.w700,
                                height: 1.1,
                              ),
                              highlight: GPText.body(
                                size: 16,
                                color: gp.accentInk,
                                weight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              size: 16, color: gp.muted,),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (distanceMeters != null) ...[
                            Icon(Icons.directions_walk,
                                size: 13, color: gp.mutedSoft,),
                            const SizedBox(width: 4),
                            Text(
                              formatDistance(distanceMeters!, l),
                              style: GPText.body(
                                size: 12,
                                color: gp.mutedSoft,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (gym.area != null && gym.area!.isNotEmpty) ...[
                            Icon(Icons.place_outlined,
                                size: 13, color: gp.mutedSoft,),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                gym.area!,
                                style: GPText.body(
                                  size: 12,
                                  color: gp.mutedSoft,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (gym.category != null &&
                          gym.category!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          localizedCategory(l, gym.category!),
                          style: GPText.body(size: 12, color: gp.mutedSoft),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                HeroLogo(gym: gym, gp: gp, accent: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders the gym name with the active search query highlighted in
/// the brand accent. Empty query falls back to a plain Text widget.
class HighlightedName extends StatelessWidget {
  const HighlightedName({
    super.key,
    required this.text,
    required this.query,
    required this.base,
    required this.highlight,
  });

  final String text;
  final String query;
  final TextStyle base;
  final TextStyle highlight;

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) {
      return Text(
        text,
        style: base,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final lower = text.toLowerCase();
    final lowerQ = q.toLowerCase();
    final spans = <TextSpan>[];
    var cursor = 0;
    while (cursor < text.length) {
      final hit = lower.indexOf(lowerQ, cursor);
      if (hit < 0) {
        spans.add(TextSpan(text: text.substring(cursor), style: base));
        break;
      }
      if (hit > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, hit), style: base));
      }
      spans.add(
        TextSpan(
          text: text.substring(hit, hit + q.length),
          style: highlight,
        ),
      );
      cursor = hit + q.length;
    }
    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Tier-ringed circular logo with a soft accent glow shadow. Used by
/// both the floating selected-gym card (above the sheet) and the
/// list rows inside the sheet, so the same affordance reads at every
/// surface.
class HeroLogo extends ConsumerWidget {
  const HeroLogo({
    super.key,
    required this.gym,
    required this.gp,
    required this.accent,
  });

  final GymSummary gym;
  final GpColors gp;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = gymInitials(gym.nameEn);
    final apiBaseUrl = ref.watch(envProvider).apiBaseUrl;
    // 72-px disc × DPR × 2 (Hero scale-up into the gym detail header,
    // which is 56-px but animates from this 72-px source). Capped at
    // 256 px raw so we don't keep a 4 MB partner JPEG decoded for a
    // floating card.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final pixelSize = (72 * dpr * 2).round().clamp(96, 256);
    final hasLogo = gym.logoUrl != null && gym.logoUrl!.isNotEmpty;
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // White interior when the partner has a real logo —
        // matches their typical baked-in white background so the
        // mark appears to fill the disc instead of sitting as a
        // smaller "card inside a card." See `GymLogo` for the
        // matching pattern. Fallback `gp.bg3` carries the
        // initials monogram, where a hard-coded white would clash
        // with the dark theme.
        color: hasLogo ? Colors.white : gp.bg3,
        border: Border.all(color: accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 26,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
          ...gp.cardShadows,
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // Same "no transient yellow on switch" rule as `GymPinMarker`:
      // when the member taps a different pin, this card's `gym` prop
      // changes, the inner `CachedNetworkImage` sees a new URL, and
      // would otherwise replay its placeholder→image fade — flashing
      // the tier-coloured initials (amber for Gold, etc.) for the
      // duration of the fade. Cached bitmaps land instantly, so:
      //   - `fadeInDuration: Zero` kills the flash window
      //   - placeholder is a neutral grey disc; the tier-coloured
      //     initials only render in the explicit no-logo and
      //     hard-error branches, never as a transient state.
      child: hasLogo
          ? CachedNetworkImage(
              imageUrl: resolveMediaUrl(apiBaseUrl, gym.logoUrl!),
              // `contain` so the entire logo always fits inside
              // the floating-card disc — see the matching note in
              // `GymPinMarker`. Cover would slice padded or
              // non-square uploads.
              fit: BoxFit.contain,
              memCacheWidth: pixelSize,
              memCacheHeight: pixelSize,
              maxWidthDiskCache: pixelSize,
              maxHeightDiskCache: pixelSize,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              // White placeholder matches the new white disc bg
              // so there's no flash from grey to white when the
              // cached bitmap lands.
              placeholder: (_, __) => Container(color: Colors.white),
              errorWidget: (_, __, ___) => _initialFallback(initial, accent),
            )
          : _initialFallback(initial, accent),
    );
  }

  Widget _initialFallback(String initial, Color accent) {
    final size = initial.characters.length >= 2 ? 24.0 : 32.0;
    return Center(
      child: Text(
        initial,
        style: GPText.display(size, color: accent, height: 1.0),
      ),
    );
  }
}

/// Tap recogniser that delays single-tap execution by a short
/// window so a follow-up tap can be recognised as a true
/// double-tap. Flutter's stock `GestureDetector` does this too,
/// but with a `kDoubleTapTimeout` of ~300 ms — long enough to
/// read as laggy on a control where the action is a quick
/// animation. We tighten the window to **180 ms**: at the edge
/// of perceptual "instant" (under 200 ms is the standard
/// snappy-response threshold) while still long enough for a
/// natural double-tap rhythm to register reliably.
///
/// Flow:
///   - First tap → start a 180 ms timer; nothing animates yet.
///   - Second tap lands inside the window → cancel timer, fire
///     `onDoubleTap` immediately. The "skipped" single-tap
///     animation never plays so there's no override-mid-flight.
///   - Timer expires with no second tap → fire `onTap`. The
///     180 ms wait is short enough that members read it as
///     "tap, then sheet moves" rather than "tap, wait, then
///     sheet moves".
///
/// If `onDoubleTap` is null, fire `onTap` immediately — no
/// reason to debounce when there's no double-tap path.
///
/// Earlier iterations tried "fire single instantly + override
/// in-flight on double" — felt snappier on single tap but never
/// gave the user enough room to reliably trigger a double. The
/// wait-then-fire model gives both gestures a clean lane.
class _FastTapHandle extends StatefulWidget {
  const _FastTapHandle({
    required this.onTap,
    required this.child,
    this.onDoubleTap,
  });

  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final Widget child;

  @override
  State<_FastTapHandle> createState() => _FastTapHandleState();
}

class _FastTapHandleState extends State<_FastTapHandle> {
  static const _doubleTapWindow = Duration(milliseconds: 180);
  Timer? _pendingTap;

  void _handleTap() {
    // No double-tap handler → fire single immediately. There's
    // no reason to debounce when there's no double-tap path to
    // wait for.
    if (widget.onDoubleTap == null) {
      widget.onTap();
      return;
    }

    // Second tap inside the window → cancel the pending single,
    // fire double right away. The single-tap animation never
    // started so there's no need to override anything.
    final pending = _pendingTap;
    if (pending != null && pending.isActive) {
      pending.cancel();
      _pendingTap = null;
      widget.onDoubleTap!.call();
      return;
    }

    // First tap → schedule the single. Member sees a 180 ms
    // pause before the sheet begins animating; if they tap
    // again within that window, the single is cancelled in
    // favour of the double.
    _pendingTap = Timer(_doubleTapWindow, () {
      _pendingTap = null;
      if (!mounted) return;
      widget.onTap();
    });
  }

  @override
  void dispose() {
    _pendingTap?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: widget.child,
    );
  }
}
