import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/gym_logo.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/tier_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../../day_pass/data/day_pass.dart';
import '../../day_pass/data/day_pass_repository.dart';
import '../../day_pass/presentation/buy_day_pass_sheet.dart';
import '../../subscription/data/subscription_state.dart';
import '../data/favorited_gyms.dart';
import '../data/gym_photo.dart';
import '../data/gym_photos_repository.dart';
import '../data/gym_repository.dart';
import '../data/gym_summary.dart';
import '../data/home_region_store.dart';
import '../data/opening_hours.dart';
import 'gym_detail/audience_badge.dart';
import 'gym_detail/day_pass_cta.dart';
import 'gym_detail/gym_detail_helpers.dart';
import 'gym_detail/hours_section.dart';
import 'gym_detail/how_to_check_in.dart';
import 'gym_detail/loading_detail_skeleton.dart';
import 'gym_detail/location_section.dart';
import 'gym_detail/not_found.dart';
import 'gym_detail/photo_slider.dart';
import 'gym_detail/photo_viewer_screen.dart';
import 'gym_detail/realtime_bridge.dart';

class GymDetailPage extends ConsumerWidget {
  final String slug;
  const GymDetailPage({super.key, required this.slug});

  /// Resolve the seed gym for this slug. Returns null when the slug
  /// doesn't match any seed entry — the page falls back to a clean
  /// "not found" surface rather than silently swapping to Iron Forge
  /// (which is what `orElse: () => seed.first` used to do, and led
  /// to members tapping a stale push notification and landing on
  /// the wrong gym wondering why their visit didn't burn).
  GPGym? _seedGym() {
    for (final g in GPGym.seed) {
      if (g.slug == slug) return g;
    }
    return null;
  }

  /// View-model for this page. Resolution order:
  ///   1. The live `gymSummary` from the backend — authoritative for
  ///      every gym in the DB (the 18 curated + the 47 OSM-imported
  ///      + anything an admin onboards later). This is the only
  ///      path that reflects real, current state.
  ///   2. The 6-entry hardcoded `GPGym.seed` (rendered as an
  ///      *initial placeholder only*, while the backend response is
  ///      in flight, for the original demo slugs).
  ///   3. `GPGym.seed.first` as the absolute last-resort placeholder.
  ///      The `isUnknownSlug` guard below bails out before this can
  ///      surface in any persistent state.
  ///
  /// The previous shape — `_seedGym() ?? GPGym.seed.first` — silently
  /// fell to the placeholder for every non-seed slug, which made
  /// every OSM-imported gym page render as Iron Forge.
  GPGym _resolveGym(GymSummary? summary) {
    if (summary != null) {
      return GPGym(
        slug: summary.slug,
        name: summary.nameEn,
        area: summary.area ?? '',
        category: summary.category ?? 'gym',
        tier: summary.tier ?? 'silver',
        lat: summary.lat ?? 0,
        lng: summary.lng ?? 0,
      );
    }
    return _seedGym() ?? GPGym.seed.first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rank 0 is the "no subscription" sentinel — every gym's tier rank is
    // >= 1, so an unsubscribed member fails the inclusion check and sees
    // the "Upgrade to <tier>" CTA that routes into /plans. This is what
    // makes the checkin → gym-profile → /plans funnel work: a member who
    // scans a gym QR without a subscription lands here and the unlock
    // path is the only primary action.
    final userRank = ref.watch(
      subscriptionProvider.select((s) => s.tier?.rank ?? 0),
    );
    // Suppress the scan CTA right after the member has actually checked in
    // here — the pass was just used, so a second tap inside the same training
    // window would only invite a duplicate scan and a wasted visit.
    final justCheckedIn = ref.watch(
      subscriptionProvider.select((s) => s.hasFreshCheckinAt(slug)),
    );
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final photosAsync = ref.watch(gymPhotosProvider(slug));
    // Resolved photo list for the tap-to-open fullscreen viewer (empty
    // until the fetch lands or when the gym has none → tap is a no-op).
    final photos = photosAsync.valueOrNull ?? const <GymPhoto>[];
    final mediaBase = ref.watch(envProvider).apiBaseUrl;
    final gymSummaryAsync = ref.watch(gymBySlugProvider(slug));
    final gymSummary = gymSummaryAsync.valueOrNull;
    // Stale push / typo'd deep link / deleted gym: the slug doesn't
    // resolve in the seed AND the backend lookup either errored or
    // came back null. Render a clean "not found" surface with a
    // back-to-explore CTA instead of silently swapping to the first
    // seed gym (which used to send members to the wrong gym page).
    final isUnknownSlug =
        _seedGym() == null && gymSummaryAsync.hasValue && gymSummary == null;
    if (isUnknownSlug) {
      return NotFound(slug: slug);
    }
    // Loading state: the slug isn't in the hardcoded `GPGym.seed` and
    // the backend response hasn't landed yet. Render a skeleton
    // instead of falling through to `_resolveGym` — without this
    // branch the page would render the seed-first fallback (Iron
    // Forge) for ~one frame while the network request was in flight,
    // producing an obvious "wrong gym flashes for a second" bug
    // every time a member tapped any non-seed gym.
    if (_seedGym() == null && !gymSummaryAsync.hasValue) {
      return LoadingDetailSkeleton(slug: slug);
    }
    // Authoritative view-model: prefer the live backend summary so
    // every OSM-imported gym renders its own name / category / tier
    // instead of falling back to Iron Forge.
    final gym = _resolveGym(gymSummary);
    final included = gym.tierObj.rank <= userRank;
    // Day-pass surfaces. Both providers auto-dispose; the gym-detail
    // page is the only consumer of `dayPassOfferingProvider(slug)`,
    // and `myDayPassesProvider` is shared with the Profile screen
    // (Riverpod dedupes the in-flight fetch).
    final offeringAsync = ref.watch(dayPassOfferingProvider(slug));
    final passesAsync = ref.watch(myDayPassesProvider);
    final offering = offeringAsync.valueOrNull ?? DayPassOffering.disabled;
    final activePassForThisGym = passesAsync.valueOrNull
        ?.where((p) => p.gymSlug == slug && p.isActive(DateTime.now().toUtc()))
        .firstOrNull;
    final remoteLogo = gymSummary?.logoUrl;
    final logoUrl =
        remoteLogo == null ? null : resolvePhotoUrl(mediaBase, remoteLogo);
    final favorites = ref.watch(favoritedGymsProvider);
    final isFav = favorites.contains(slug);

    // Real opening hours, parsed from the backend payload. `unknown`
    // when the partner never filled hours in — the header then shows
    // no status line rather than the old hardcoded "OPEN 24/7" lie.
    final hours = OpeningHours.fromJson(gymSummary?.openingHours);
    final openStatus = hours.statusAt(DateTime.now());
    // Coordinates for the Location section + directions. Backend wins;
    // falls back to seed coords; null disables the whole section.
    final gymLat = gymSummary?.lat ?? (gym.lat == 0 ? null : gym.lat);
    final gymLng = gymSummary?.lng ?? (gym.lng == 0 ? null : gym.lng);
    final mapsKey = ref.watch(envProvider).googleMapsKey;
    // Localized street address; falls back to the coarse area label.
    final address =
        (isAr ? (gymSummary?.addressAr ?? '') : (gymSummary?.addressEn ?? ''))
            .trim();
    // Locked = neither the plan nor an active day-pass unlocks this gym.
    final locked = !included && activePassForThisGym == null;

    return RealtimeBridge(
      slug: slug,
      gymId: gymSummary?.id,
      child: Scaffold(
        backgroundColor: gp.bg,
        body: Stack(
          children: [
            // Photo header — pinned at 20% of screen so it stays visible
            // while you scroll, stretches/zooms on pull-down overscroll,
            // and tap-opens the fullscreen viewer. The app bar's `shape`
            // rounds its bottom corners (even when collapsed/pinned) so
            // the card's flush rounded top nests cleanly with no overlap
            // (overlap is what bled the photo through the card before).
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  expandedHeight: 400,
                  collapsedHeight: MediaQuery.sizeOf(context).height * 0.07,
                  pinned: true,
                  stretch: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: gp.bg,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(GPRadius.xl2),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: GestureDetector(
                      onTap: () =>
                          _openPhotoViewer(context, photos, mediaBase, isAr),
                      child: SizedBox(
                        height: 400,
                        // Crossfade the loading-state gradient → real photo slider
                        // (and back, on error). Without this the swap is a hard cut
                        // from the placeholder gradient to the slider the moment
                        // `photosAsync` resolves — read by members as "something
                        // else loaded first, *then* the gym profile appeared."
                        // 280 ms is long enough to feel like a single hand-off,
                        // short enough that it doesn't delay reading the page.
                        //
                        // Keys matter: `AnimatedSwitcher` diffs by key. Same key
                        // for fallback in loading / error / empty branches keeps
                        // the gradient *steady* across those non-data states; a
                        // distinct key for the slider triggers the crossfade only
                        // when real photos land.
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          // Default layoutBuilder centers children, which collapses
                          // the gradient (no intrinsic size). `StackFit.expand`
                          // forces both children to fill the 400-px slot so they
                          // overlap pixel-for-pixel during the fade.
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              fit: StackFit.expand,
                              alignment: Alignment.center,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          child: photosAsync.when(
                            data: (photos) => photos.isEmpty
                                ? KeyedSubtree(
                                    key: const ValueKey('hero-fallback'),
                                    child: _heroFallback(gp, gym),
                                  )
                                : KeyedSubtree(
                                    key: const ValueKey('hero-slider'),
                                    child: PhotoSlider(
                                      photos: photos,
                                      isAr: isAr,
                                      fadeColor: gp.bg,
                                      mediaBase: mediaBase,
                                    ),
                                  ),
                            // Loading + error + empty all share the same
                            // gradient placeholder. No loader on top — the
                            // gradient + faint category icon already reads
                            // as "we have a hero slot, content is filling
                            // it"; a centered dumbbell on top made the page
                            // feel like it was *blocked* on a fetch instead
                            // of progressively painting. Same key across
                            // these three states so AnimatedSwitcher holds
                            // the gradient stable until real photos arrive.
                            loading: () => KeyedSubtree(
                              key: const ValueKey('hero-fallback'),
                              child: _heroFallback(gp, gym),
                            ),
                            error: (_, __) => KeyedSubtree(
                              key: const ValueKey('hero-fallback'),
                              child: _heroFallback(gp, gym),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  // Card sits flush below the pinned photo — no overlap,
                  // so it never paints over the app bar and nothing
                  // bleeds through. The app bar's rounded-bottom shape
                  // meets this rounded top cleanly.
                  child: Container(
                    decoration: BoxDecoration(
                      color: gp.bg,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(GPRadius.xl2),
                      ),
                    ),
                    child: Padding(
                      // Bottom inset clears the system nav bar — the
                      // card is no longer wrapped in a SafeArea now
                      // that it scrolls inside the CustomScrollView.
                      padding: EdgeInsets.fromLTRB(
                        22,
                        22,
                        22,
                        20 + MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Identity card: logo on the left, all gym
                          // details (eyebrow + name + open/distance) in
                          // a column to the right. Previously these
                          // stacked vertically (logo+eyebrow on row 1,
                          // name on row 2, open/distance on row 3),
                          // which left the logo looking isolated. The
                          // single-row layout reads as one cohesive
                          // identity block.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Hero(
                                tag: 'gym-logo-${gym.slug}',
                                // 64 px (up from 56) so the logo
                                // visually balances the three-line
                                // text column to its right.
                                child: GymLogo(
                                  gym: gym,
                                  logoUrl: logoUrl,
                                  size: 64,
                                  shape: GymLogoShape.circle,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Overline(
                                      '${_categoryLabel(l, gym.category)} · ${gym.area.toUpperCase()}',
                                    ),
                                    const SizedBox(height: 4),
                                    // Name. display 22 (down from 34)
                                    // so it fits in the constrained
                                    // column next to the logo. Still
                                    // big enough to read as the
                                    // identity statement.
                                    DisplayText(
                                      gym.name,
                                      size: 22,
                                      color: gp.fg,
                                      height: 1.0,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        // Real open/closed status from the
                                        // backend `opening_hours`. Empty
                                        // (no dot, no text) when the gym
                                        // never set hours — better an
                                        // honest blank than the old
                                        // hardcoded "OPEN 24/7".
                                        ..._headerStatusChildren(
                                          l,
                                          gp,
                                          openStatus,
                                        ),
                                        // Live distance from the
                                        // member's GPS, hidden when
                                        // the GPS hasn't resolved yet
                                        // — a "—" would add chrome
                                        // with no signal.
                                        ..._buildDistanceRow(
                                          ref,
                                          gp,
                                          l,
                                          gymSummary,
                                          gym,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Audience badge — surfaces who the venue is
                          // for so a member who lands here from a deep
                          // link / share sees the policy before they try
                          // to scan in. Single-sex gyms get the loud
                          // pink/blue pill; "mixed" gets a calm neutral
                          // "Everyone welcome" row (previously mixed
                          // rendered nothing, leaving members unsure
                          // whether the gym was open to them at all).
                          if (gymSummary?.audienceGender == 'female_only' ||
                              gymSummary?.audienceGender == 'male_only' ||
                              gymSummary?.audienceGender == 'mixed') ...[
                            const SizedBox(height: 12),
                            AudienceBadge(
                              audience: gymSummary!.audienceGender!,
                            ),
                          ],
                          const SizedBox(height: 18),
                          _accessBanner(context, l, gp, gym, included),
                          const SizedBox(height: 18),
                          _amenityGrid(
                            context,
                            l,
                            gp,
                            gymSummary?.amenities ?? const <String>[],
                          ),
                          // Opening hours — the full per-day schedule,
                          // expandable from the live status line. Hidden
                          // entirely when the gym never set hours.
                          if (hours.isKnown) ...[
                            const SizedBox(height: 18),
                            HoursSection(
                              hours: hours,
                              status: openStatus,
                            ),
                          ],
                          // Location — address + tappable static-map
                          // preview + "Get directions" deep-linking to
                          // Google Maps. Skipped when we have no coords
                          // (can't point anywhere useful).
                          if (gymLat != null && gymLng != null) ...[
                            const SizedBox(height: 18),
                            LocationSection(
                              lat: gymLat,
                              lng: gymLng,
                              address: address,
                              areaFallback: gym.area,
                              label: gym.name,
                              mapsKey: mapsKey,
                              isAr: isAr,
                            ),
                          ],
                          // How to check in — the 3-step QR flow. Adapts
                          // its subtitle when the gym is still locked.
                          const SizedBox(height: 18),
                          HowToCheckIn(locked: locked),
                          const SizedBox(height: 18),
                          Text(
                            l.gymAbout.toUpperCase(),
                            style: GPText.mono(
                              size: 10,
                              letterSpacing: 1.8,
                              color: gp.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l.gymDescriptionFallback(gym.area),
                            style: GPText.body(
                              size: 13,
                              color: gp.mutedSoft,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (justCheckedIn)
                            _checkedInBadge(l, gp)
                          // Active day-pass for THIS gym — same "Check
                          // in here" affordance as the subscription
                          // path, because both unlock the QR scanner.
                          else if (activePassForThisGym != null)
                            PillButton(
                              label: l.gymCheckInHere,
                              trailingIcon: Icons.qr_code_scanner,
                              onPressed: () => context.go('/checkin'),
                            )
                          else if (included)
                            PillButton(
                              label: l.gymCheckInHere,
                              trailingIcon: Icons.qr_code_scanner,
                              // /checkin lives inside the bottom-nav ShellRoute.
                              // Pushing from this top-level route stacks
                              // the shell on top and trips the navigator
                              // duplicate-page-key assertion. `go` swaps
                              // to the scan tab cleanly.
                              onPressed: () => context.go('/checkin'),
                            )
                          // Locked-tier branch. When the gym sells day
                          // passes, the day-pass CTA is the primary
                          // call to action — a one-off pass is a much
                          // lower friction than a plan upgrade, and
                          // converts a "I'm just curious about this
                          // place" into a real visit. The upgrade
                          // path is preserved via the red "Requires
                          // <tier>" banner above, which is now
                          // tappable and routes to /plans.
                          //
                          // Day-pass works for both unsubscribed
                          // members and subscribers locked out by
                          // tier (e.g. Silver looking at a Platinum
                          // gym). The backend refuses only when the
                          // active subscription ALREADY covers the
                          // gym — handled there, not gated here.
                          else if (offering.isEnabled)
                            DayPassCta(
                              priceJod: offering.priceJod,
                              validityHours: offering.validityHours,
                              onPressed: () async {
                                await showBuyDayPassSheet(
                                  context: context,
                                  gymSlug: slug,
                                  gymName: gym.name,
                                  offering: offering,
                                  gym: gym,
                                  gymLogoUrl: logoUrl,
                                );
                              },
                            ),
                          // No CTA when the gym is locked AND has
                          // no day-pass offering: the red "Requires
                          // <tier>" banner above is already the
                          // upgrade affordance (tappable, routes to
                          // /plans). A second "Upgrade to <tier>"
                          // pill at the bottom was redundant.
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Subtle top vignette so the floating back / fav /
            // share buttons stay legible over any hero photo — a
            // gentle ~28% black wash for the top 96 px.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 96,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x47000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            // Floating action row (back / favourite / share),
            // pinned over the hero so the back button stays
            // reachable even after the photo scrolls away.
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Row(
                  children: [
                    const BackBtn(fallback: '/explore'),
                    const Spacer(),
                    IconBtn(
                      icon: isFav ? Icons.favorite : Icons.favorite_border,
                      onPressed: () {
                        final added = ref
                            .read(favoritedGymsProvider.notifier)
                            .toggle(slug);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                added ? l.favAddedMessage : l.favRemovedMessage,
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                      },
                    ),
                    const SizedBox(width: 10),
                    Builder(
                      builder: (btnCtx) {
                        return IconBtn(
                          icon: Icons.ios_share,
                          onPressed: () => _shareGym(
                            context: btnCtx,
                            webBase: ref.read(envProvider).webBaseUrl,
                            nameEn: gymSummary?.nameEn ?? gym.name,
                            slug: slug,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroFallback(GpColors gp, GPGym gym) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0.0, 0.65, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gym.color.withValues(alpha: 0.4), gp.bg],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.12,
                child: Align(
                  alignment: Alignment.center,
                  child: Icon(
                    _categoryIcon(gym),
                    size: 220,
                    color: gym.color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(GPGym gym) {
    switch (gym.category) {
      case 'yoga':
        return Icons.self_improvement;
      case 'martial':
        return Icons.sports_martial_arts;
      case 'crossfit':
        return Icons.bolt;
      default:
        return Icons.fitness_center;
    }
  }

  String _categoryLabel(AppLocalizations l, String category) {
    switch (category) {
      case 'yoga':
        return l.categoryYoga;
      case 'martial':
        return l.categoryMartial;
      case 'crossfit':
        return l.categoryCross;
      default:
        return l.categoryGym;
    }
  }

  Widget _dot(GpColors gp) => Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(color: gp.muted, shape: BoxShape.circle),
      );

  /// The leading "● Open now · closes 23:00" cluster in the gym
  /// header. Returns an empty list when hours are unknown so the row
  /// collapses to just the distance (or nothing) — no hardcoded
  /// fallback. The bullet is brand-tinted when open, muted when shut.
  List<Widget> _headerStatusChildren(
    AppLocalizations l,
    GpColors gp,
    OpenStatus status,
  ) {
    final label = openStatusLine(l, status);
    if (label == null) return const [];
    final open = status.isOpen || status.always;
    return [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: open ? gp.accentInk : gp.muted,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GPText.mono(
            size: 10,
            letterSpacing: 1.4,
            color: open ? gp.accentInk : gp.mutedSoft,
          ),
        ),
      ),
    ];
  }

  /// Build the "· N.N KM" suffix that follows "OPEN 24/7" in the
  /// gym header. Backend coords win; falls back to seed coords;
  /// returns no widgets when the user GPS hasn't resolved or
  /// coordinates are missing — better an honest blank than a
  /// confident-but-wrong number.
  List<Widget> _buildDistanceRow(
    WidgetRef ref,
    GpColors gp,
    AppLocalizations l,
    GymSummary? summary,
    GPGym gym,
  ) {
    final user = ref.watch(userPositionProvider);
    if (user == null) return const [];
    final lat = summary?.lat ?? (gym.lat == 0 ? null : gym.lat);
    final lng = summary?.lng ?? (gym.lng == 0 ? null : gym.lng);
    if (lat == null || lng == null) return const [];
    final km = haversineKm(user.lat, user.lng, lat, lng);
    return [
      const SizedBox(width: 10),
      _dot(gp),
      const SizedBox(width: 10),
      Text(
        l.gymKmAway(km.toStringAsFixed(1)),
        style: GPText.mono(size: 10, letterSpacing: 1.4, color: gp.mutedSoft),
      ),
    ];
  }

  Widget _accessBanner(
    BuildContext context,
    AppLocalizations l,
    GpColors gp,
    GPGym gym,
    bool included,
  ) {
    final color = included ? gp.accentInk : GP.danger;
    final bg = color.withValues(alpha: 0.12);
    final border = color.withValues(alpha: included ? 0.44 : 0.5);
    final banner = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(GPRadius.md),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            included ? Icons.check_circle : Icons.lock_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              included
                  ? l.gymAccessIncluded
                  : l.gymAccessRequiresTier(gym.tierObj.name),
              style: GPText.body(
                size: 13,
                color: gp.fg,
                weight: FontWeight.w500,
              ),
            ),
          ),
          TierChip(tier: gym.tierObj),
        ],
      ),
    );
    // When the gym is locked behind a higher tier, the banner is the
    // secondary path to /plans — it stays the canonical "what tier
    // do I need?" affordance, but the bottom-of-page CTA may now
    // surface a day-pass alternative instead of the upgrade path.
    // Making the banner tappable preserves the upgrade route without
    // crowding the bottom of the screen with two competing CTAs.
    if (included) return banner;
    return InkWell(
      onTap: () => context.push('/plans'),
      borderRadius: BorderRadius.circular(GPRadius.md),
      child: banner,
    );
  }

  Widget _checkedInBadge(AppLocalizations l, GpColors gp) {
    const color = GP.lime;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.44)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            l.gymCheckedInRecently,
            style: GPText.body(size: 14, color: gp.fg, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Renders the gym's amenities as a horizontal scroll strip of
  /// icon + label tiles. Driven by `gym.amenities` from the backend
  /// (`/api/v1/gyms/by-slug/{slug}` → `GymRead.amenities`). Slugs
  /// come from the partner portal's `AmenitiesPicker` preset list
  /// (`wifi`, `parking`, `showers`, `lockers`, `pool`, `sauna`, …);
  /// each known slug maps to a Material icon + an ARB-localised
  /// label. Unknown slugs (custom entries the partner typed in)
  /// render with a generic check icon and the slug as the label
  /// fallback.
  ///
  /// Layout is a horizontal `ListView` so the strip stays one row
  /// tall regardless of count — members swipe left/right to see
  /// the rest. Keeps the page's vertical rhythm stable whether a
  /// gym has 3 amenities or 20. Direction follows the locale
  /// (RTL flips automatically via the surrounding `Directionality`).
  ///
  /// Empty list → entire section is skipped (no header, no padding)
  /// so a freshly-seeded gym with no amenities filled out doesn't
  /// render an empty box.
  Widget _amenityGrid(
    BuildContext context,
    AppLocalizations l,
    GpColors gp,
    List<String> amenities,
  ) {
    if (amenities.isEmpty) return const SizedBox.shrink();
    final items = amenities.map((slug) => _amenityFor(slug, l)).toList();
    // Fixed tile width keeps every chip the same size regardless of
    // label length. 88 px ≈ four-up at the previous 360 px-ish content
    // width, so the visual matches the old static row when there are
    // few amenities — the strip just grows scrollable as more are
    // added.
    const tileWidth = 88.0;
    const tileHeight = 76.0;
    return SizedBox(
      height: tileHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Bouncing physics so the swipe feels native; clamping at the
        // edges would read as "stuck" on a short list.
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        // 14 px between tiles. Was 8 — felt cramped per user
        // feedback; the chips visually merged into a horizontal
        // band rather than reading as discrete amenity cards.
        // 14 gives each tile its own silhouette without
        // pushing the four-up first row off-screen.
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final it = items[i];
          return Container(
            width: tileWidth,
            padding: const EdgeInsets.symmetric(vertical: 14),
            // Border stepped up from `gp.line` → `gp.line2` (the
            // stronger divider token) and the card shadow dropped.
            // In light mode the previous chrome made the tiles read
            // as one merged strip: `gp.line` is too subtle to
            // delimit each tile against the white surface, and the
            // shared `gp.cardShadows` formed a continuous band
            // along the bottom of the row that visually connected
            // them. Stronger flat border + no shadow gives each
            // tile a discrete chip silhouette in both themes.
            decoration: BoxDecoration(
              color: gp.bg2,
              borderRadius: BorderRadius.circular(GPRadius.md),
              border: Border.all(color: gp.line2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(it.$1, color: gp.fg, size: 18),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    it.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GPText.mono(
                      size: 8.5,
                      letterSpacing: 1.4,
                      color: gp.mutedSoft,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Map a backend amenity slug to (icon, localised label). Slug
  /// vocabulary mirrors `gym-partner/src/components/AmenitiesPicker.tsx`
  /// — keep the two in sync when adding new presets.
  (IconData, String) _amenityFor(String slug, AppLocalizations l) {
    switch (slug) {
      case 'wifi':
        return (Icons.wifi, l.gymAmenityWifi);
      case 'parking':
        return (Icons.local_parking, l.gymAmenityParking);
      case 'showers':
        return (Icons.shower, l.gymAmenityShowers);
      case 'lockers':
        return (Icons.lock_outline, l.gymAmenityLockers);
      case 'changing_rooms':
        return (Icons.checkroom, l.gymAmenityChangingRooms);
      case 'towels':
        return (Icons.dry_cleaning, l.gymAmenityTowels);
      case 'water_fountain':
        return (Icons.water_drop_outlined, l.gymAmenityWaterFountain);
      case 'ac':
        return (Icons.ac_unit, l.gymAmenityAc);
      case 'free_weights':
        return (Icons.fitness_center, l.gymAmenityFreeWeights);
      case 'cardio_machines':
        return (Icons.directions_run, l.gymAmenityCardioMachines);
      case 'sauna':
        return (Icons.hot_tub, l.gymAmenitySauna);
      case 'pool':
        return (Icons.pool, l.gymAmenityPool);
      case 'steam_room':
        return (Icons.cloud, l.gymAmenitySteamRoom);
      case 'group_classes':
        return (Icons.groups, l.gymAmenityGroupClasses);
      case 'personal_training':
        return (Icons.person, l.gymAmenityPersonalTraining);
      case 'kids_area':
        return (Icons.child_care, l.gymAmenityKidsArea);
      case 'women_only_area':
        return (Icons.female, l.gymAmenityWomenOnlyArea);
      case 'prayer_room':
        return (Icons.mosque, l.gymAmenityPrayerRoom);
      case 'juice_bar':
        return (Icons.local_drink_outlined, l.gymAmenityJuiceBar);
      case 'wheelchair_access':
        return (Icons.accessible, l.gymAmenityWheelchairAccess);
      default:
        // Unknown / custom slug — partner typed something in the
        // free-form box. Show the slug as-is (uppercase) with a
        // generic check icon. Better than hiding it; partner's
        // intent shipped, mobile renders it.
        return (Icons.check_circle_outline, slug.toUpperCase());
    }
  }
}

/// Push a fullscreen, swipeable, pinch-zoomable photo gallery. No-op
/// when the gym has no photos (the hero shows the gradient fallback,
/// so there's nothing to open).
void _openPhotoViewer(
  BuildContext context,
  List<GymPhoto> photos,
  String mediaBase,
  bool isAr, {
  int initialIndex = 0,
}) {
  if (photos.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PhotoViewerScreen(
        photos: photos,
        mediaBase: mediaBase,
        isAr: isAr,
        initialIndex: initialIndex,
      ),
    ),
  );
}

/// Pop the OS share sheet with the gym's name and a public URL the
/// recipient can open in any browser. The URL shape mirrors the web
/// router's gym-detail path so a deep link from WhatsApp lands on the
/// same page if/when the web app catches up — for now it just opens
/// the marketing landing with the slug as a fragment, which is a
/// reasonable fallback. iPad anchors the popover to the page bounds
/// (passed as `sharePositionOrigin`); other devices ignore that arg.
Future<void> _shareGym({
  required BuildContext context,
  required String webBase,
  required String nameEn,
  required String slug,
}) async {
  final url = '$webBase/gyms/$slug';
  final body = '$nameEn\n$url';
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  await Share.share(
    body,
    subject: nameEn,
    sharePositionOrigin: origin,
  );
}
