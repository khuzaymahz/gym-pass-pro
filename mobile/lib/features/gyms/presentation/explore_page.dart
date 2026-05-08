import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/gym_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../data/gym_initials.dart';
import '../data/gym_repository.dart';
import '../data/gym_summary.dart';
import '../data/home_region_store.dart';
import '../data/jordan_regions.dart';
import '../data/location_service.dart';
import '../data/media_url.dart';
import '../data/static_map_url.dart';
import '../../../core/widgets/top_bounce_physics.dart';
import 'gym_detail_page.dart' show favoritedGymsProvider;
import 'gyms_filter_state.dart';

/// Explore tab — **list-first**. The previous version embedded a full
/// `GoogleMap` widget; we replaced it with a static-image preview at
/// the top because gyms don't move and the live SDK was overkill for
/// "where are the gyms in my city". The static map loads in one HTTP
/// round-trip (Google Static Maps API), costs ~7× less per render on
/// the Maps Platform bill, and lets the rest of the page be a plain
/// scroll view — no platform-view lag, no marker bitmap factory, no
/// camera state machine to keep in sync with the list.
///
/// Layout from top to bottom:
///   - Floating top bar (search pill + filter button), unchanged.
///   - Static map preview card showing the member's region with a pin
///     per visible gym; tapping it expands the same image fullscreen.
///   - Count strip ("12 GYMS").
///   - Vertical list of gyms, sorted by distance when GPS is available,
///     by name otherwise. Each row pushes `/gyms/<slug>` on tap.
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// Member's last-known position. Null until GPS resolves or the
  /// stored value is read. Drives distance pills + region selection
  /// for the static map.
  GeoPoint? _userPosition;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = ref.read(gymsSearchQueryProvider);
    _searchCtrl.addListener(_onSearchTextChanged);
    // Defer the GPS request past the first frame so the page paints
    // its skeleton before iOS's permission prompt fires — members see
    // the page appear, then the prompt, instead of a flash of grey
    // while the dialog is up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _locateUser());
  }

  void _onSearchTextChanged() {
    ref.read(gymsSearchQueryProvider.notifier).state = _searchCtrl.text;
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchCtrl.removeListener(_onSearchTextChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Hydrate the user's last home location from secure storage (so
  /// the first paint has a real region) and fire a fresh GPS read in
  /// the background. The fresh read updates the cross-app
  /// `userPositionProvider` so distance-aware widgets elsewhere
  /// (home, gym detail) see it too.
  Future<void> _locateUser() async {
    final regionStore = ref.read(homeRegionStoreProvider);
    final service = ref.read(locationServiceProvider);

    final stored = await regionStore.read();
    if (!mounted) return;
    if (stored != null && _userPosition == null) {
      setState(() {
        _userPosition = GeoPoint(lat: stored.lat, lng: stored.lng);
      });
      ref.read(userPositionProvider.notifier).state = stored;
    }

    final result = await service.currentPosition();
    if (!mounted || !result.hasPosition) return;
    final pos = result.position!;
    setState(() {
      _userPosition = GeoPoint(lat: pos.latitude, lng: pos.longitude);
    });
    ref.read(userPositionProvider.notifier).state =
        HomeLocation(lat: pos.latitude, lng: pos.longitude);
    unawaited(regionStore.write(pos.latitude, pos.longitude));
  }

  bool _matches(
    GymSummary gym,
    String category,
    Set<String> tiers,
    String query, {
    bool favoritesOnly = false,
    Set<String> favorites = const <String>{},
  }) {
    if (favoritesOnly && !favorites.contains(gym.slug)) return false;
    if (category != 'all' && gym.category != category) return false;
    if (tiers.isNotEmpty && (gym.tier == null || !tiers.contains(gym.tier))) {
      return false;
    }
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return gym.nameEn.toLowerCase().contains(q) ||
        gym.nameAr.contains(q) ||
        (gym.area?.toLowerCase().contains(q) ?? false);
  }

  /// Distance from the user's last-known position to a gym, in metres.
  /// Null when the position or gym coords aren't available.
  double? _distanceToGym(GymSummary gym) {
    final me = _userPosition;
    final gymLat = gym.lat;
    final gymLng = gym.lng;
    if (me == null || gymLat == null || gymLng == null) return null;
    return ref.read(locationServiceProvider).distanceMeters(
          fromLat: me.lat,
          fromLng: me.lng,
          toLat: gymLat,
          toLng: gymLng,
        );
  }

  int _activeFilterCount(
    String category,
    Set<String> tiers,
    bool favoritesOnly,
  ) {
    var n = 0;
    if (category != 'all') n++;
    if (tiers.isNotEmpty) n++;
    if (favoritesOnly) n++;
    return n;
  }

  Future<void> _openFiltersSheet(BuildContext context) async {
    HapticFeedback.selectionClick();
    final controller = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 280),
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionAnimationController: controller,
      builder: (_) => const _FiltersSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final asyncGyms = ref.watch(gymsListProvider);
    final category = ref.watch(gymsCategoryFilterProvider);
    final query = ref.watch(gymsSearchQueryProvider);
    final tiers = ref.watch(gymsTierFilterProvider);
    final favoritesOnly = ref.watch(gymsFavoritesOnlyProvider);
    final favorites = ref.watch(favoritedGymsProvider);
    final activeFilterCount =
        _activeFilterCount(category, tiers, favoritesOnly);
    final topInset = MediaQuery.viewPaddingOf(context).top;

    // Member's region (Amman / Zarqa / Aqaba / ...) drives the static
    // map's centre + zoom. Falls back to Amman until GPS resolves so
    // the preview never renders an empty country-wide overview.
    final user = _userPosition;
    final region = user == null
        ? jordanRegions.first
        : regionForPosition(user.lat, user.lng);

    return Scaffold(
      body: asyncGyms.when(
        loading: () => Container(
          color: gp.bg,
          alignment: Alignment.center,
          child: const GymLoader(size: GymLoaderSize.large),
        ),
        error: (e, _) => Container(
          color: gp.bg,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          child: Text(
            l.snackErrorGeneric,
            textAlign: TextAlign.center,
            style: GPText.body(size: 14, color: gp.muted),
          ),
        ),
        data: (gyms) {
          final visible = gyms
              .where(
                (g) => _matches(
                  g,
                  category,
                  tiers,
                  query,
                  favoritesOnly: favoritesOnly,
                  favorites: favorites,
                ),
              )
              .toList()
            ..sort((a, b) {
              final da = _distanceToGym(a);
              final db = _distanceToGym(b);
              if (da == null && db == null) {
                return a.nameEn.compareTo(b.nameEn);
              }
              if (da == null) return 1;
              if (db == null) return -1;
              return da.compareTo(db);
            });
          // Map markers come from the *visible* set (after filters)
          // so toggling a category visibly thins the preview's pins
          // — same affordance the live map provided.
          final mapMarkers = visible
              .where((g) => g.lat != null && g.lng != null)
              .map(
                (g) => StaticMapMarker(
                  lat: g.lat!,
                  lng: g.lng!,
                  colorHex: _colorHexForGym(g),
                ),
              )
              .toList();
          return Stack(
            children: [
              // Plain scroll view — no DraggableScrollableSheet, no
              // platform map underneath, just a standard list.
              CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: TopBouncePhysics(),
                ),
                slivers: [
                  // Top inset + chrome height so the static map starts
                  // below the floating search bar.
                  SliverToBoxAdapter(
                    child: SizedBox(height: topInset + 72),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                      child: _StaticMapPreview(
                        region: region,
                        markers: mapMarkers,
                        userPosition: user,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                      child: Row(
                        children: [
                          Text(
                            visible.length == 1
                                ? l.exploreOneGymCount
                                : l.exploreGymCount(visible.length),
                            style: GPText.mono(
                              size: 11,
                              letterSpacing: 1.4,
                              color: gp.muted,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 60,
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
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final gym = visible[i];
                        return _GymListRow(
                          gym: gym,
                          distanceMeters: _distanceToGym(gym),
                          query: query,
                          onTap: () => context.push('/gyms/${gym.slug}'),
                        );
                      },
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 24 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                  ),
                ],
              ),
              _ExploreTopBar(
                searchCtrl: _searchCtrl,
                searchFocus: _searchFocus,
                activeFilterCount: activeFilterCount,
                onOpenFilters: () => _openFiltersSheet(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Pull a 6-digit hex (no `#`) from a gym's tier so its pin on the
/// static map matches the row's tier ring. Falls back to the brand
/// lime when the gym has no tier yet.
String _colorHexForGym(GymSummary gym) {
  final tierKey = gym.tier;
  if (tierKey == null) return 'c8ff00';
  final colour = GPTier.byKey(tierKey).color;
  return _argbToHex6(colour);
}

String _argbToHex6(Color c) {
  // Color stores channels as 0–1 doubles in Flutter 3.27+; round to int.
  final r = (c.r * 255).round() & 0xff;
  final g = (c.g * 255).round() & 0xff;
  final b = (c.b * 255).round() & 0xff;
  return '${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}';
}

class GeoPoint {
  const GeoPoint({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

/// Static-map preview card. Renders a single Google Static Maps PNG
/// for the member's region with one pin per visible gym. Tapping it
/// pops a fullscreen viewer (same image, larger). Replaces the live
/// `GoogleMap` widget — see the page-level docstring for why.
class _StaticMapPreview extends ConsumerWidget {
  const _StaticMapPreview({
    required this.region,
    required this.markers,
    required this.userPosition,
  });

  final JordanRegion region;
  final List<StaticMapMarker> markers;
  final GeoPoint? userPosition;

  /// Card height in logical pixels. Roughly 16:9 on a typical phone
  /// width — wide enough that pins are legible, short enough that
  /// the gym list below is the dominant surface.
  static const double _height = 180;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gp = context.gp;
    final apiKey = ref.watch(envProvider).googleMapsKey;
    final localeTag = Localizations.localeOf(context).languageCode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(GPRadius.lg),
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: gp.bg2,
          borderRadius: BorderRadius.circular(GPRadius.lg),
          border: Border.all(color: gp.line),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (apiKey.isEmpty) {
              return _ConfigPlaceholder(region: region, gp: gp);
            }
            final dpr = MediaQuery.devicePixelRatioOf(context);
            final url = StaticMapUrl.build(
              centre: (lat: region.centre.lat, lng: region.centre.lng),
              zoom: region.staticMapZoom,
              size: Size(constraints.maxWidth, _height),
              devicePixelRatio: dpr,
              markers: markers,
              apiKey: apiKey,
              language: localeTag == 'ar' ? 'ar' : 'en',
            );
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openFullScreen(context, url),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      url.toString(),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: gp.bg2,
                          alignment: Alignment.center,
                          child: const GymLoader(size: GymLoaderSize.small),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: gp.bg2,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.map_outlined,
                          size: 32,
                          color: gp.mutedSoft,
                        ),
                      ),
                    ),
                    // Region label ribbon. Sits over the bottom-left
                    // of the map so the eye lands on "this is YOUR
                    // city" without searching the map for a label.
                    PositionedDirectional(
                      bottom: 10,
                      start: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius:
                              BorderRadius.circular(GPRadius.pill),
                        ),
                        child: Text(
                          localeTag == 'ar' ? region.nameAr : region.nameEn,
                          style: GPText.mono(
                            size: 10,
                            letterSpacing: 1.4,
                            color: Colors.white,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, Uri url) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.78),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, anim, __) {
          return FadeTransition(
            opacity: anim,
            child: _FullScreenMapView(url: url),
          );
        },
      ),
    );
  }
}

/// Placeholder card shown when `GOOGLE_MAPS_KEY` isn't passed via
/// `--dart-define`. Keeps the page from rendering a broken image
/// during scaffolding/CI; in normal builds the key is set and this
/// branch never fires.
class _ConfigPlaceholder extends StatelessWidget {
  const _ConfigPlaceholder({required this.region, required this.gp});

  final JordanRegion region;
  final GpColors gp;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 28, color: gp.mutedSoft),
          const SizedBox(height: 8),
          Text(
            region.nameEn,
            style: GPText.body(
              size: 14,
              color: gp.fg,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Map preview unavailable',
            style: GPText.body(size: 11, color: gp.mutedSoft),
          ),
        ],
      ),
    );
  }
}

/// Fullscreen viewer the preview pushes when tapped. Re-fetches the
/// static image at near-screen size so pins are crisp; the preview's
/// smaller image is kept separately because re-using it would stretch
/// blurry. A close button + tap-to-dismiss handle the only two ways
/// out — no zoom controls, no pan; if the member needs that, the
/// "Open in Maps" button on the gym detail page handles it.
class _FullScreenMapView extends ConsumerWidget {
  const _FullScreenMapView({required this.url});

  final Uri url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gp = context.gp;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(GPRadius.lg),
                  child: Image.network(
                    url.toString(),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Container(
                      color: gp.bg2,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.map_outlined,
                        size: 40,
                        color: gp.mutedSoft,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: MediaQuery.viewPaddingOf(context).top + 12,
              end: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.55),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating top chrome — search pill on the left, filter button on
/// the right. Kept verbatim from the previous map-based explore page
/// because the affordance hasn't changed: it's just an input + a
/// pop-up filters sheet.
class _ExploreTopBar extends StatelessWidget {
  const _ExploreTopBar({
    required this.searchCtrl,
    required this.searchFocus,
    required this.activeFilterCount,
    required this.onOpenFilters,
  });

  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final int activeFilterCount;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Positioned(
      top: topInset + 8,
      left: 12,
      right: 12,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(GPRadius.pill),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: _SearchField(
                  controller: searchCtrl,
                  focusNode: searchFocus,
                  hint: l.exploreSearchHint,
                  gp: gp,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(GPRadius.pill),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: _FilterIconButton(
                activeCount: activeFilterCount,
                onTap: onOpenFilters,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.gp,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final GpColors gp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: gp.bg2.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(GPRadius.pill),
          border: Border.all(color: gp.line),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 6, 0),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: gp.muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                cursorColor: gp.accentInk,
                cursorWidth: 1.4,
                style: GPText.body(size: 14, color: gp.fg),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: hint,
                  hintStyle: GPText.body(size: 14, color: gp.muted),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  ref.read(gymsSearchQueryProvider.notifier).state = value;
                },
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  controller.clear();
                  ref.read(gymsSearchQueryProvider.notifier).state = '';
                },
                iconSize: 16,
                splashRadius: 18,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(Icons.close_rounded, color: gp.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({
    required this.activeCount,
    required this.onTap,
  });

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final hasActive = activeCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GPRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: 48,
          padding: EdgeInsets.symmetric(
            horizontal: hasActive ? 14 : 12,
          ),
          decoration: BoxDecoration(
            color: hasActive ? gp.accent : gp.bg2.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(GPRadius.pill),
            border: Border.all(
              color: hasActive ? gp.accent : gp.line,
            ),
            boxShadow: hasActive
                ? [
                    BoxShadow(
                      color: gp.accent.withValues(alpha: 0.32),
                      blurRadius: 18,
                      spreadRadius: -4,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: hasActive ? gp.onLime : gp.fg,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: hasActive
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(start: 6),
                        child: Text(
                          '$activeCount',
                          style: GPText.mono(
                            size: 13,
                            letterSpacing: 0.5,
                            color: gp.onLime,
                            weight: FontWeight.w800,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FiltersSheet extends ConsumerWidget {
  const _FiltersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final category = ref.watch(gymsCategoryFilterProvider);
    final tiers = ref.watch(gymsTierFilterProvider);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: gp.bg2.withValues(alpha: 0.96),
            border: Border(top: BorderSide(color: gp.line, width: 0.5)),
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 22),
                    decoration: BoxDecoration(
                      color: gp.line2,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      l.exploreFiltersTitle,
                      style: GPText.display(24, color: gp.fg, height: 1.0),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref.read(gymsCategoryFilterProvider.notifier).state =
                            'all';
                        ref.read(gymsTierFilterProvider.notifier).state =
                            const <String>{};
                        ref.read(gymsFavoritesOnlyProvider.notifier).state =
                            false;
                      },
                      child: Text(
                        l.exploreFiltersReset,
                        style: GPText.mono(
                          size: 11,
                          letterSpacing: 1.4,
                          color: gp.accentInk,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _FavoritesToggleRow(
                  active: ref.watch(gymsFavoritesOnlyProvider),
                  count: ref.watch(favoritedGymsProvider).length,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    ref.read(gymsFavoritesOnlyProvider.notifier).state = v;
                  },
                  l: l,
                  gp: gp,
                ),
                const SizedBox(height: 22),
                _SectionLabel(text: l.exploreFiltersCategorySection),
                const SizedBox(height: 10),
                _CategoryWrap(
                  active: category,
                  onChange: (v) {
                    HapticFeedback.selectionClick();
                    ref.read(gymsCategoryFilterProvider.notifier).state = v;
                  },
                  l: l,
                  gp: gp,
                ),
                const SizedBox(height: 22),
                _SectionLabel(text: l.exploreFiltersTierSection),
                const SizedBox(height: 10),
                _TierWrap(
                  active: tiers,
                  onToggle: (key) {
                    HapticFeedback.selectionClick();
                    final next = Set<String>.from(tiers);
                    if (next.contains(key)) {
                      next.remove(key);
                    } else {
                      next.add(key);
                    }
                    ref.read(gymsTierFilterProvider.notifier).state = next;
                  },
                  l: l,
                  gp: gp,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gp.accent,
                      foregroundColor: gp.onLime,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GPRadius.pill),
                      ),
                    ),
                    child: Text(
                      l.exploreFiltersDone,
                      style: GPText.body(
                        size: 15,
                        color: gp.onLime,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Text(
      text.toUpperCase(),
      style: GPText.mono(
        size: 10,
        letterSpacing: 1.6,
        color: gp.muted,
        weight: FontWeight.w700,
      ),
    );
  }
}

class _FavoritesToggleRow extends StatelessWidget {
  const _FavoritesToggleRow({
    required this.active,
    required this.count,
    required this.onChanged,
    required this.l,
    required this.gp,
  });

  final bool active;
  final int count;
  final ValueChanged<bool> onChanged;
  final AppLocalizations l;
  final GpColors gp;

  @override
  Widget build(BuildContext context) {
    final disabled = count == 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.lg),
        onTap: disabled ? null : () => onChanged(!active),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: active ? GP.lime22 : gp.bg3,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(
              color: active ? gp.accentInk.withValues(alpha: 0.55) : gp.line,
            ),
          ),
          child: Row(
            children: [
              Icon(
                active ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: active ? gp.accentInk : (disabled ? gp.muted : gp.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.exploreFiltersFavoritesLabel,
                  style: GPText.body(
                    size: 14,
                    color: disabled ? gp.muted : gp.fg,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$count',
                style: GPText.mono(
                  size: 11,
                  letterSpacing: 1.2,
                  color: disabled ? gp.muted : gp.mutedSoft,
                ),
              ),
              const SizedBox(width: 6),
              Switch.adaptive(
                value: active,
                onChanged: disabled ? null : onChanged,
                activeThumbColor: gp.accentInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryWrap extends StatelessWidget {
  const _CategoryWrap({
    required this.active,
    required this.onChange,
    required this.l,
    required this.gp,
  });

  final String active;
  final ValueChanged<String> onChange;
  final AppLocalizations l;
  final GpColors gp;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String, IconData)>[
      ('all', l.gymsCategoryAll, Icons.public),
      ('gym', l.gymsCategoryGym, Icons.fitness_center),
      ('crossfit', l.gymsCategoryCrossfit, Icons.bolt_outlined),
      ('martial', l.gymsCategoryMartial, Icons.sports_mma_outlined),
      ('yoga', l.gymsCategoryYoga, Icons.self_improvement_outlined),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in entries)
          _SheetChip(
            label: e.$2,
            icon: e.$3,
            active: active == e.$1,
            tint: e.$1 == 'all' ? gp.accentInk : GPCategory.color(e.$1),
            onTap: () => onChange(e.$1),
          ),
      ],
    );
  }
}

class _TierWrap extends StatelessWidget {
  const _TierWrap({
    required this.active,
    required this.onToggle,
    required this.l,
    required this.gp,
  });

  final Set<String> active;
  final ValueChanged<String> onToggle;
  final AppLocalizations l;
  final GpColors gp;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      ('silver', l.tierSilver),
      ('gold', l.tierGold),
      ('platinum', l.tierPlatinum),
      ('diamond', l.tierDiamond),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in entries)
          _SheetChip(
            label: e.$2,
            dotColor: GPTier.byKey(e.$1).color,
            active: active.contains(e.$1),
            tint: GPTier.byKey(e.$1).color,
            onTap: () => onToggle(e.$1),
          ),
      ],
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.active,
    required this.tint,
    required this.onTap,
    this.icon,
    this.dotColor,
  });

  final String label;
  final bool active;
  final Color tint;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GPRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? tint.withValues(alpha: 0.18) : gp.bg3,
            borderRadius: BorderRadius.circular(GPRadius.pill),
            border: Border.all(
              color: active ? tint.withValues(alpha: 0.6) : gp.line,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: active ? tint : gp.mutedSoft,
                ),
                const SizedBox(width: 6),
              ] else if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GPText.body(
                  size: 13,
                  color: active ? tint : gp.fg,
                  weight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
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
    final tier = gym.tier == null ? null : GPTier.byKey(gym.tier!);
    final accent = tier?.color ?? gp.accentInk;
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
                            child: _HighlightedName(
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
                              _formatDistance(distanceMeters!, l),
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
                          _localizedCategory(l, gym.category!),
                          style: GPText.body(size: 12, color: gp.mutedSoft),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _HeroLogo(gym: gym, gp: gp, accent: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightedName extends StatelessWidget {
  const _HighlightedName({
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

String _localizedCategory(AppLocalizations l, String key) {
  switch (key) {
    case 'gym':
      return l.gymsCategoryGym;
    case 'crossfit':
      return l.gymsCategoryCrossfit;
    case 'martial':
      return l.gymsCategoryMartial;
    case 'yoga':
      return l.gymsCategoryYoga;
    default:
      return key;
  }
}

String _formatDistance(double meters, AppLocalizations l) {
  if (meters < 1000) {
    final km = (meters / 1000).toStringAsFixed(1);
    return l.exploreDistanceKm(km);
  }
  final km =
      meters >= 10000 ? meters ~/ 1000 : (meters / 1000).round();
  return l.exploreDistanceKm('$km');
}

class _HeroLogo extends ConsumerWidget {
  const _HeroLogo({
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
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gp.bg3,
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
      child: gym.logoUrl != null && gym.logoUrl!.isNotEmpty
          ? Image.network(
              resolveMediaUrl(apiBaseUrl, gym.logoUrl!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialFallback(initial, accent),
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
