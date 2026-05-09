import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/providers.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/gym_logo.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/tier_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../../subscription/data/subscription_state.dart';
import '../data/gym_photo.dart';
import '../data/gym_photos_repository.dart';
import '../data/gym_repository.dart';
import '../data/gym_summary.dart';
import '../data/home_region_store.dart';

final favoritedGymsProvider = StateProvider<Set<String>>((_) => <String>{});

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

  GPGym get gym => _seedGym() ?? GPGym.seed.first;

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
    final included = gym.tierObj.rank <= userRank;
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
    final mediaBase = ref.watch(envProvider).apiBaseUrl;
    final gymSummaryAsync = ref.watch(gymBySlugProvider(slug));
    final gymSummary = gymSummaryAsync.valueOrNull;
    // Stale push / typo'd deep link / deleted gym: the slug doesn't
    // resolve in the seed AND the backend lookup either errored or
    // came back null. Render a clean "not found" surface with a
    // back-to-explore CTA instead of silently swapping to the first
    // seed gym (which used to send members to the wrong gym page).
    final isUnknownSlug = _seedGym() == null &&
        gymSummaryAsync.hasValue &&
        gymSummary == null;
    if (isUnknownSlug) {
      return _NotFound(slug: slug);
    }
    final remoteLogo = gymSummary?.logoUrl;
    final logoUrl =
        remoteLogo == null ? null : _resolvePhotoUrl(mediaBase, remoteLogo);
    final favorites = ref.watch(favoritedGymsProvider);
    final isFav = favorites.contains(slug);

    return _RealtimeBridge(
      slug: slug,
      gymId: gymSummary?.id,
      child: Scaffold(
        backgroundColor: gp.bg,
        body: Stack(
        children: [
          SizedBox(
            height: 400,
            child: photosAsync.when(
              data: (photos) => photos.isEmpty
                  ? _heroFallback(gp)
                  : _PhotoSlider(
                      photos: photos,
                      isAr: isAr,
                      fadeColor: gp.bg,
                      mediaBase: mediaBase,
                    ),
              loading: () => _heroFallback(gp),
              error: (_, __) => _heroFallback(gp),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [gp.bg.withValues(alpha: 0.85), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  // Drop the forced LTR — back / fav / share follow
                  // the locale's reading order so the back button
                  // anchors visually-left in EN and visually-right
                  // in AR (BackBtn already flips its arrow icon).
                  child: Row(
                    children: [
                      const BackBtn(fallback: '/explore'),
                      const Spacer(),
                      IconBtn(
                        icon: isFav ? Icons.favorite : Icons.favorite_border,
                        onPressed: () {
                          final current =
                              ref.read(favoritedGymsProvider.notifier).state;
                          final next = Set<String>.from(current);
                          final added = next.add(slug);
                          if (!added) next.remove(slug);
                          ref.read(favoritedGymsProvider.notifier).state = next;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(added
                                    ? l.favAddedMessage
                                    : l.favRemovedMessage,),
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
                            // Native share sheet — pre-fills the OS
                            // chooser with the gym's display name plus
                            // its public URL so a member can drop the
                            // gym into WhatsApp / Messages / Mail in
                            // one gesture. Replaces the previous
                            // snackbar-only stub. The gym name
                            // resolves from the backend summary when
                            // available, falling back to the seed
                            // entry for offline / pre-hydrate cases.
                            onPressed: () => _shareGym(
                              context: btnCtx,
                              webBase: ref.read(envProvider).webBaseUrl,
                              nameAr: gymSummary?.nameAr ?? gym.name,
                              nameEn: gymSummary?.nameEn ?? gym.name,
                              slug: slug,
                              isAr: isAr,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: gp.bg,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(GPRadius.xl2),),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Hero(
                              tag: 'gym-logo-${gym.slug}',
                              child: GymLogo(
                                gym: gym,
                                logoUrl: logoUrl,
                                size: 56,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Overline(
                                '${_categoryLabel(l, gym.category)} · ${gym.area.toUpperCase()}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(gym.name.toUpperCase(),
                            style: GPText.display(34, color: gp.fg, height: 0.9),),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(color: gp.accentInk, shape: BoxShape.circle),),
                            const SizedBox(width: 6),
                            Text(l.gymOpen247,
                                style: GPText.mono(size: 10, letterSpacing: 1.4, color: gp.mutedSoft),),
                            // Live distance from the member's GPS to
                            // the gym, computed via haversine on the
                            // backend coords (preferred) or the seed
                            // coords (fallback). Hidden entirely when
                            // the GPS hasn't resolved yet — a "—"
                            // would just add chrome with no signal.
                            ..._buildDistanceRow(ref, gp, l, gymSummary),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _accessBanner(context, l, gp, gym, included),
                        const SizedBox(height: 18),
                        _amenityGrid(
                          context,
                          l,
                          gp,
                          gymSummary?.amenities ?? const <String>[],
                        ),
                        const SizedBox(height: 18),
                        Text(l.gymAbout.toUpperCase(),
                            style: GPText.mono(size: 10, letterSpacing: 1.8, color: gp.muted),),
                        const SizedBox(height: 10),
                        Text(
                          l.gymDescriptionFallback(gym.area),
                          style: GPText.body(size: 13, color: gp.mutedSoft, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        if (justCheckedIn)
                          _checkedInBadge(l, gp)
                        else if (included)
                          PillButton(
                            label: l.gymCheckInHere,
                            trailingIcon: Icons.qr_code_scanner,
                            // /checkin lives inside the bottom-nav ShellRoute.
                            // Pushing it from this top-level route would stack
                            // the shell on top of the current route and trip
                            // the navigator's duplicate-page-key assertion.
                            // `go` swaps into the scan tab cleanly.
                            onPressed: () => context.go('/checkin'),
                          )
                        else
                          PillButton(
                            label: l.gymUpgradeTo(gym.tierObj.name),
                            trailingIcon: Icons.lock_outline,
                            onPressed: () => context.push('/plans'),
                          ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _heroFallback(GpColors gp) {
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
                    _categoryIcon(),
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

  IconData _categoryIcon() {
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

  Widget _accessBanner(BuildContext context, AppLocalizations l, GpColors gp,
      GPGym gym, bool included,) {
    final color = included ? gp.accentInk : GP.danger;
    final bg = included
        ? gp.accentInk.withValues(alpha: 0.12)
        : GP.danger.withValues(alpha: 0.12);
    final border = included
        ? gp.accentInk.withValues(alpha: 0.44)
        : GP.danger.withValues(alpha: 0.5);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(GPRadius.md),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(included ? Icons.check_circle : Icons.lock_outline, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              included
                  ? l.gymAccessIncluded
                  : l.gymAccessRequiresTier(gym.tierObj.name),
              style: GPText.body(size: 13, color: gp.fg, weight: FontWeight.w500),
            ),
          ),
          TierChip(tier: gym.tierObj),
        ],
      ),
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
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final it = items[i];
          return Container(
            width: tileWidth,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: gp.bg2,
              borderRadius: BorderRadius.circular(GPRadius.md),
              border: Border.all(color: gp.line),
              boxShadow: gp.cardShadows,
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

String _resolvePhotoUrl(String mediaBase, String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '$mediaBase$url';
}

/// Subscribes the realtime client to this gym's channels for the
/// lifetime of the detail page, then invalidates the relevant
/// Riverpod providers each time the server pushes a matching event.
/// Result: a partner saving a profile / logo / photo change is
/// reflected on this page within a frame, no pull-to-refresh needed.
///
/// Stays a thin wrapper rather than refactoring the whole detail
/// page to ConsumerStatefulWidget — minimal blast radius, the
/// build tree above is unchanged.
class _RealtimeBridge extends ConsumerStatefulWidget {
  const _RealtimeBridge({
    required this.slug,
    required this.gymId,
    required this.child,
  });

  final String slug;

  /// Backend gym UUID. Null while `gymBySlugProvider` is still
  /// hydrating — the bridge defers subscribing until we know it,
  /// since the channel name is `gym/<id>`.
  final String? gymId;
  final Widget child;

  @override
  ConsumerState<_RealtimeBridge> createState() => _RealtimeBridgeState();
}

class _RealtimeBridgeState extends ConsumerState<_RealtimeBridge> {
  StreamSubscription<RealtimeEvent>? _sub;
  String? _activeGymId;
  // Cache the client at initState so dispose() doesn't have to touch
  // `ref` — Riverpod throws "Cannot use ref after the widget was
  // disposed" if a late-arriving stream event or our own dispose()
  // accesses ref after super.dispose has run. Holding the client
  // directly sidesteps that whole class of races.
  RealtimeClient? _client;

  @override
  void initState() {
    super.initState();
    _client = ref.read(realtimeClientProvider);
    _refreshSubscription();
  }

  @override
  void didUpdateWidget(covariant _RealtimeBridge old) {
    super.didUpdateWidget(old);
    if (old.gymId != widget.gymId) {
      _refreshSubscription();
    }
  }

  void _refreshSubscription() {
    final id = widget.gymId;
    if (id == _activeGymId) return;
    _activeGymId = id;
    _sub?.cancel();
    _sub = null;
    if (id == null) return;

    final client = _client;
    if (client == null) return;
    client.setChannels(['gym/$id', 'gym/$id/photos']);
    _sub = client.events.listen((event) {
      // Stream events can land mid-teardown — the subscription
      // cancel is async, so an event already in flight will still
      // fire its listener. Without the `mounted` guard we'd hit
      // "Cannot use ref after the widget was disposed" the moment
      // a partner edited their gym while a member was navigating
      // away. Cheap check, eliminates the race entirely.
      if (!mounted) return;
      if (!event.channel.startsWith('gym/$id')) return;
      // Any of the published gym events (`gym.updated`,
      // `gym.logo.set`, `gym.logo.cleared`, `gym.photo.added`,
      // `gym.photo.removed`) means at least one of these two
      // providers is now stale — re-fetch them. Riverpod's
      // invalidate is cheap (just clears the cached value); the
      // page will rebuild and the page already handles the
      // "loading" branch.
      ref.invalidate(gymBySlugProvider(widget.slug));
      ref.invalidate(gymPhotosProvider(widget.slug));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    // Use the cached client instead of ref — see the field comment.
    // Keep the realtimeClient alive (other pages might subscribe
    // next), but clear its channel set so we're not paying for an
    // event stream we no longer consume.
    _client?.setChannels(const []);
    _client = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
  required String nameAr,
  required String nameEn,
  required String slug,
  required bool isAr,
}) async {
  final displayName = isAr && nameAr.isNotEmpty ? nameAr : nameEn;
  final url = '$webBase/gyms/$slug';
  final body = '$displayName\n$url';
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  await Share.share(
    body,
    subject: displayName,
    sharePositionOrigin: origin,
  );
}

class _PhotoSlider extends StatefulWidget {
  const _PhotoSlider({
    required this.photos,
    required this.isAr,
    required this.fadeColor,
    required this.mediaBase,
  });
  final List<GymPhoto> photos;
  final bool isAr;
  final Color fadeColor;
  final String mediaBase;

  @override
  State<_PhotoSlider> createState() => _PhotoSliderState();
}

class _PhotoSliderState extends State<_PhotoSlider> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _firstPrefetchDone = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Decoded-bitmap target width. The page hero is the device width
  /// rendered at the device pixel ratio — anything bigger than that
  /// is wasted RAM and decode time. Capped at 1600 px so a 4K phone
  /// with 3.5× DPR (≈1400 logical × 3.5 = 4900 raw) doesn't try to
  /// keep a 50 MB bitmap in cache; the cap is well above any sane
  /// hero JPEG.
  int _targetCacheWidth(BuildContext context) {
    final mq = MediaQuery.of(context);
    final raw = (mq.size.width * mq.devicePixelRatio).round();
    return raw.clamp(360, 1600);
  }

  /// `precacheImage` decodes the JPEG into the image-cache so when
  /// `PageView` builds the neighbour child, the bitmap is already
  /// ready and the swipe doesn't wait on network → decode. We do
  /// this on first frame for the visible page + the next one, then
  /// chase the user as they swipe.
  void _prefetchNeighbours(BuildContext context, int center) {
    final w = _targetCacheWidth(context);
    final candidates = <int>{center - 1, center + 1};
    for (final i in candidates) {
      if (i < 0 || i >= widget.photos.length) continue;
      final url = _resolvePhotoUrl(widget.mediaBase, widget.photos[i].url);
      final provider = ResizeImage(
        CachedNetworkImageProvider(url),
        width: w,
      );
      // `precacheImage` is a no-op if the provider is already in the
      // cache, so calling it on every page change is cheap.
      precacheImage(provider, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cacheW = _targetCacheWidth(context);
    if (!_firstPrefetchDone) {
      _firstPrefetchDone = true;
      // Defer to post-frame so the surrounding Scaffold has a chance
      // to lay out — `precacheImage` reads the size from MediaQuery,
      // which is stable by then.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _prefetchNeighbours(context, _index);
      });
    }
    return Stack(
      children: [
        Positioned.fill(
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0.0, 0.6, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                _prefetchNeighbours(context, i);
              },
              itemBuilder: (_, i) {
                final photo = widget.photos[i];
                final alt = widget.isAr
                    ? (photo.altTextAr ?? photo.altTextEn ?? '')
                    : (photo.altTextEn ?? photo.altTextAr ?? '');
                return Semantics(
                  label: alt,
                  image: true,
                  // `CachedNetworkImage` adds three things `Image.network`
                  // doesn't:
                  //   1. `flutter_cache_manager`-backed disk cache —
                  //      cold launches no longer re-fetch every photo.
                  //   2. `memCacheWidth` — the JPEG decodes to the
                  //      display width, not the source width, so a
                  //      4000-px hero doesn't sit in RAM as a
                  //      4000×3000 ARGB bitmap (≈48 MB) for a
                  //      400-px slot.
                  //   3. `fadeInDuration` — the new photo crossfades
                  //      from the placeholder, which masks the brief
                  //      decode pause when paging.
                  child: CachedNetworkImage(
                    imageUrl: _resolvePhotoUrl(widget.mediaBase, photo.url),
                    fit: BoxFit.cover,
                    memCacheWidth: cacheW,
                    maxWidthDiskCache: cacheW,
                    fadeInDuration: const Duration(milliseconds: 200),
                    fadeOutDuration: const Duration(milliseconds: 80),
                    placeholder: (_, __) => Container(color: widget.fadeColor),
                    errorWidget: (_, __, ___) =>
                        Container(color: widget.fadeColor),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 76,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.photos.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? GP.lime : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: gp.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_outlined, size: 56, color: gp.muted),
                  const SizedBox(height: 16),
                  Text(
                    l.gymNotFoundTitle,
                    textAlign: TextAlign.center,
                    style: GPText.display(24, color: gp.fg, height: 1.0),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.gymNotFoundBody(slug),
                    textAlign: TextAlign.center,
                    style: GPText.body(size: 14, color: gp.mutedSoft, height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  PillButton(
                    label: l.gymNotFoundBackToExplore,
                    trailingIcon: Icons.arrow_forward,
                    onPressed: () => context.go('/explore'),
                  ),
                ],
              ),
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

