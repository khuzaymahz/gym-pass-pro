import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

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
import 'gym_detail_page.dart' show favoritedGymsProvider;
import 'gyms_filter_state.dart';

/// Explore tab — **map-first**, Uber/Careem layout.
///
/// Layout (z-order, bottom up):
///   1. Full-screen [FlutterMap] as the hero surface. Tile renderer
///      is pure Flutter (no platform view, no native SDK init); tiles
///      come from CARTO basemaps — Voyager for light, Dark Matter for
///      dark — both designed for app UIs in a low-saturation,
///      Linear/Stripe register that doesn't fight the brand.
///   2. Tap-to-show gym card — when a logo pin is tapped, a profile
///      card slides up just above the bottom sheet's resting handle.
///      Tap the card → push gym detail. Tap anywhere else dismisses.
///   3. Locate-me FAB + custom zoom (+/-) on the trailing edge —
///      both stay in fixed positions relative to the viewport.
///   4. Top chrome — search pill + filter button, glass-blurred over
///      the map.
///   5. [DraggableScrollableSheet] at the bottom — minimized by
///      default (handle peek only); tap or drag to expand.
///
/// The earlier `google_maps_flutter` build is gone — see
/// `memory/project_explorer_map_requirements.md` for why we swapped
/// (logo pins are Flutter widgets here, not BitmapDescriptor work;
/// custom palette match is built into the tile style; no recurring
/// billing risk; lighter on cold start).
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage>
    with TickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// Map controller — flutter_map's controller is a plain object
  /// (no platform-view init, no Completer needed). Drives camera
  /// moves for locate-me and tap-to-pan-to-gym, plus the +/- zoom
  /// buttons.
  final MapController _mapCtrl = MapController();

  /// Currently-tapped gym, drives the floating profile card. Null
  /// when no pin is selected (card hidden). Updates on pin tap; map
  /// taps clear it.
  GymSummary? _selectedGym;

  /// Member's last-known position. Null until GPS resolves or the
  /// stored value is read. Drives distance pills + the locate-me
  /// camera target.
  GeoPoint? _userPosition;

  /// Debounce timer for the search box. Without it, every keystroke
  /// pushes a new query into the Riverpod state, which rebuilds the
  /// page → re-filters all gyms → recomputes the marker Set → and
  /// makes the platform-view diff its markers. Cheap individually,
  /// noticeable on a hot keyboard. 180 ms is below the threshold
  /// where typing feels laggy but high enough to coalesce a fast
  /// burst into a single recompute.
  Timer? _searchDebounce;
  static const _searchDebounceDuration = Duration(milliseconds: 180);

  /// Controller for the bottom sheet so a tap on the handle can
  /// programmatically expand it. The sheet starts at the smallest
  /// snap (handle peek only) so the map is the dominant surface;
  /// the user opens the list with either a tap or a drag.
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  /// Sheet snap heights, expressed as fractions of screen height.
  /// All three user-defined as of 2026-05-09:
  ///
  /// - **Min** — ONLY the rounded top + drag handle pill peek above
  ///   the bottom nav. The "6 GYMS" count strip and any list rows
  ///   are completely hidden; map fills the rest of the screen.
  ///   Tuned down from 0.055 → 0.04 because the earlier value was
  ///   tall enough to leak the count strip into view; the handle
  ///   row alone is 32 px (matches `_GymListSheet`'s SizedBox).
  /// - **Default** — sheet covers the lower ~45% — handle + "6 GYMS"
  ///   header + EXACTLY 3 list rows (Apex / Bedford / Core), with
  ///   the third card sitting just above the bottom nav and no
  ///   peek of a fourth card. Tuned down from 0.50 → 0.45 because
  ///   0.50 was tall enough to leak the fourth card's title into
  ///   the visible band, breaking the "exactly 3 cards" intent.
  ///   The auto-open triggers (search-field focus, search-text
  ///   typed, filter button tapped, handle tapped) animate here.
  /// - **Max** — sheet leaves a clear strip of map visible BELOW
  ///   the floating search bar (search bar floats over the map; a
  ///   ~30-40 px band of tiles + place labels reads between the
  ///   search bar's bottom edge and the sheet's top edge). Tuned
  ///   down from 0.88 → 0.84 because 0.88 had the sheet sitting
  ///   right under the search bar — the chrome read as one welded
  ///   block instead of "search bar floating over a map with the
  ///   list peeking up from below". Six cards still fit comfortably.
  ///
  /// Snapping is ON: drag-release snaps to the nearest of these
  /// three, mirroring Uber / Apple Maps.
  static const double _sheetMin = 0.04;
  static const double _sheetAutoOpen = 0.45;
  static const double _sheetMax = 0.84;

  /// Jordan country bounds for camera constraint. Sets the hard
  /// edges of the world the member can pan to — drag past the
  /// border and flutter_map clamps. Slightly padded out from the
  /// political border so regions hugging the edge (Aqaba on the
  /// south coast, Mafraq on the east) aren't visually clipped.
  ///
  /// Coordinates roughly:
  ///   SW corner ≈ Aqaba southern tip / Saudi border
  ///   NE corner ≈ Northeast border with Iraq / Syria
  static final LatLngBounds _jordanBounds = LatLngBounds(
    const LatLng(29.10, 34.85),
    const LatLng(33.45, 39.40),
  );

  /// High-resolution Jordan border polygon (~60 points). Used as a
  /// HOLE in the dark mask polygon, so tiles INSIDE the country
  /// render normally (with all their labels, roads, area names) and
  /// EVERYTHING outside renders solid black. Foreign place names —
  /// KAYSERI, ALEPPO, JERUSALEM, AS-SUWEIDA, AL WAJH — never
  /// appear, and there are no neighbour-country roads / borders
  /// peeking through.
  ///
  /// Earlier we tried this with ~20 points; the border was kinked
  /// enough that the cut-out shape looked broken at zoom 6-7.
  /// 60+ points spaced roughly every ~10-30 km gives a sub-pixel
  /// approximation at zoom 6 (where the country fits the screen)
  /// and reads as a clean border at every higher zoom. Pixel-
  /// perfect would need a real GeoJSON asset (~500 points); for
  /// now this resolution is the right trade-off between fidelity
  /// and binary size.
  ///
  /// Points trace clockwise from the NW corner. Order is
  /// load-bearing: reversing it inverts hole-vs-fill regions.
  static const List<LatLng> _jordanPolygon = [
    // ===== NW — Israel/Syria triangle (Yarmouk) =====
    LatLng(32.72, 35.55),
    LatLng(32.71, 35.62),
    LatLng(32.70, 35.72),
    // ===== N — Syrian border (Daraa belt) =====
    LatLng(32.66, 35.85),
    LatLng(32.69, 35.96),
    LatLng(32.74, 36.05),
    LatLng(32.78, 36.18),
    LatLng(32.74, 36.30),
    LatLng(32.65, 36.42),
    LatLng(32.55, 36.55),
    LatLng(32.48, 36.72),
    LatLng(32.43, 36.92),
    // ===== NE — approach to the Iraqi panhandle =====
    LatLng(32.40, 37.18),
    LatLng(32.42, 37.50),
    LatLng(32.46, 37.85),
    LatLng(32.52, 38.20),
    LatLng(32.60, 38.55),
    LatLng(32.85, 38.78),
    // ===== E — Iraqi border (north tip + east edge) =====
    LatLng(33.37, 38.78), // sharp north tip of the panhandle
    LatLng(33.20, 38.92),
    LatLng(33.05, 39.05),
    LatLng(32.85, 39.15),
    LatLng(32.55, 39.20),
    LatLng(32.30, 39.20),
    // ===== SE — Saudi border (long diagonal SW) =====
    LatLng(32.05, 39.10),
    LatLng(31.75, 38.90),
    LatLng(31.45, 38.65),
    LatLng(31.15, 38.40),
    LatLng(30.85, 38.18),
    LatLng(30.55, 37.95),
    LatLng(30.25, 37.75),
    LatLng(29.95, 37.50),
    LatLng(29.65, 37.20),
    LatLng(29.42, 36.85),
    LatLng(29.32, 36.45),
    LatLng(29.25, 35.95),
    LatLng(29.20, 35.45),
    // ===== S — Aqaba southern tip =====
    LatLng(29.18, 34.95),
    // ===== W — Israel / West Bank border, going north =====
    // Wadi Araba southern stretch
    LatLng(29.45, 35.00),
    LatLng(29.75, 35.05),
    LatLng(30.05, 35.10),
    LatLng(30.30, 35.15),
    LatLng(30.55, 35.20),
    LatLng(30.80, 35.30),
    // Dead Sea southern + middle (eastern shore is the border)
    LatLng(30.95, 35.38),
    LatLng(31.10, 35.42),
    LatLng(31.30, 35.45),
    LatLng(31.50, 35.48),
    LatLng(31.70, 35.50),
    LatLng(31.80, 35.52),
    // Jordan Valley going north
    LatLng(32.00, 35.55),
    LatLng(32.20, 35.55),
    LatLng(32.40, 35.55),
    LatLng(32.55, 35.55),
    // closes back to NW corner (32.72, 35.55) automatically
  ];

  /// Outer ring of the mask polygon — large rectangle around the
  /// camera's reachable envelope. Doesn't need to be world-scale;
  /// ~5° padded around Jordan keeps the polygon cheap to
  /// triangulate while still covering the entire viewport at
  /// every zoom level we allow.
  static const List<LatLng> _maskOuterRect = [
    LatLng(35.00, 30.00), // NW
    LatLng(35.00, 45.00), // NE
    LatLng(27.00, 45.00), // SE
    LatLng(27.00, 30.00), // SW
  ];


  @override
  void initState() {
    super.initState();
    _searchCtrl.text = ref.read(gymsSearchQueryProvider);
    _searchCtrl.addListener(_onSearchTextChanged);
    // Auto-open the sheet when the search field gets focus — the
    // member is asking to see results, so the list should already
    // be in front of them by the time they finish typing.
    _searchFocus.addListener(_onSearchFocusChanged);
    // Defer the GPS request past the first frame so the page paints
    // its skeleton before iOS's permission prompt fires — members see
    // the page appear, then the prompt, instead of a flash of grey
    // while the dialog is up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _locateUser());
  }

  void _onSearchTextChanged() {
    _searchDebounce?.cancel();
    final text = _searchCtrl.text;
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      ref.read(gymsSearchQueryProvider.notifier).state = text;
    });
    // Any non-empty query is a clear intent to see filtered
    // results — surface the list without making the member drag
    // the sheet up themselves.
    if (text.isNotEmpty) {
      _autoOpenSheet();
    }
  }

  void _onSearchFocusChanged() {
    if (_searchFocus.hasFocus) {
      _autoOpenSheet();
    }
  }

  /// Animate the sheet open when search / filter activity implies
  /// the member wants to see the gym list. No-op if the sheet is
  /// already at or above the auto-open size — never *closes* the
  /// sheet from this path, only opens it.
  void _autoOpenSheet() {
    if (!_sheetCtrl.isAttached) return;
    if (_sheetCtrl.size >= _sheetAutoOpen - 0.02) return;
    _sheetCtrl.animateTo(
      _sheetAutoOpen,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocus.removeListener(_onSearchFocusChanged);
    _searchFocus.dispose();
    _searchCtrl.removeListener(_onSearchTextChanged);
    _searchCtrl.dispose();
    _sheetCtrl.dispose();
    _cameraAnim?.dispose();
    super.dispose();
  }

  /// Tap on the handle toggles the sheet — drag is for "specific
  /// size", tap is for "open / close". Open target is the same one
  /// search / filter triggers use, so the affordances feel unified.
  Future<void> _expandSheet() async {
    if (!_sheetCtrl.isAttached) return;
    final current = _sheetCtrl.size;
    final target =
        current > _sheetMin + 0.05 ? _sheetMin : _sheetAutoOpen;
    await _sheetCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  /// Hydrate the user's last home location from secure storage (so
  /// the first paint has a real region) and fire a fresh GPS read in
  /// the background. The fresh read updates the cross-app
  /// `userPositionProvider` so distance-aware widgets elsewhere
  /// (home, gym detail) see it too.
  ///
  /// On initial detection (panMap=false) the map is framed to the
  /// user's region — Amman / Aqaba / Irbid / etc. — at an "eagle
  /// view" zoom that shows all the gyms in that region without
  /// requiring the member to pan or zoom. The detection cascade is
  /// stored-region-first (instant, from previous session) then
  /// fresh-GPS (more accurate, lands a few seconds later); both
  /// paths trigger the same fit-camera call so the camera ends up
  /// at the right region by the time the GPS fix finishes.
  ///
  /// On locate-me-button (panMap=true) the camera zooms into the
  /// user's exact lat/lng — street-level — because that's the
  /// member's intent when they tap the button.
  Future<void> _locateUser({bool panMap = false}) async {
    final regionStore = ref.read(homeRegionStoreProvider);
    final service = ref.read(locationServiceProvider);

    final stored = await regionStore.read();
    if (!mounted) return;
    if (stored != null && _userPosition == null) {
      setState(() {
        _userPosition = GeoPoint(lat: stored.lat, lng: stored.lng);
      });
      ref.read(userPositionProvider.notifier).state = stored;
      // Fit to stored region immediately so a returning member sees
      // their last-known city framed before the fresh GPS lands.
      if (!panMap) {
        _fitCameraToRegion(regionForPosition(stored.lat, stored.lng));
      }
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

    if (panMap) {
      // Locate-me intent — zoom in tight on the user's pin.
      unawaited(_animateCameraTo(LatLng(pos.latitude, pos.longitude), zoom: 14));
    } else {
      // Initial / auto detect — frame the user's region as an
      // eagle view (bounds-fit), so all gyms in that region are
      // visible without panning.
      _fitCameraToRegion(regionForPosition(pos.latitude, pos.longitude));
    }
  }

  /// Animate the camera to frame [region]'s bounds. The padding
  /// keeps gyms hugging the bounds' edge from rendering right up
  /// against the search bar / sheet / FAB. Wrapped in a try/catch
  /// because `fitCamera` can throw if it's called before the map's
  /// first layout pass — in that case, the `initialCenter` /
  /// `initialZoom` are still in effect and produce a reasonable
  /// fallback frame.
  void _fitCameraToRegion(JordanRegion region) {
    try {
      _mapCtrl.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(
              region.bounds.southwest.lat,
              region.bounds.southwest.lng,
            ),
            LatLng(
              region.bounds.northeast.lat,
              region.bounds.northeast.lng,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(40, 80, 40, 60),
        ),
      );
    } catch (_) {
      // Map not laid out yet; the next call (after fresh GPS lands)
      // will land cleanly. If both calls fire before mount, the
      // initialCenter/initialZoom still produce a sensible view.
    }
  }

  /// In-flight camera-animation controller, kept so a fresh tap
  /// (e.g. selecting a different gym while the camera is mid-move)
  /// cancels the previous tween instead of fighting it.
  AnimationController? _cameraAnim;

  /// Smooth camera move — tweens both centre and zoom over
  /// [_cameraAnimDuration] using a soft ease curve. Used for every
  /// user-triggered camera change (pin tap, list-row tap, locate-me).
  /// The animation is deliberately a touch slow (~650 ms) so the
  /// camera glide reads as a transition, not a jump cut, when the
  /// member switches between gyms.
  ///
  /// flutter_map's `MapController.move` is itself synchronous, so
  /// we drive the animation here by ticking `move` from a Tween on
  /// every animation frame. No external animation package needed.
  Future<void> _animateCameraTo(LatLng target, {double? zoom}) async {
    final startCenter = _mapCtrl.camera.center;
    final startZoom = _mapCtrl.camera.zoom;
    final endZoom = zoom ?? startZoom;

    // Same start = same end → no-op (avoid creating an animation
    // that has no work to do).
    if (startCenter.latitude == target.latitude &&
        startCenter.longitude == target.longitude &&
        startZoom == endZoom) {
      return;
    }

    // Cancel any in-flight tween before starting a new one.
    _cameraAnim?.dispose();

    final ctl = AnimationController(
      vsync: this,
      duration: _cameraAnimDuration,
    );
    _cameraAnim = ctl;

    final curved =
        CurvedAnimation(parent: ctl, curve: Curves.easeInOutCubic);
    final latTween = Tween<double>(
      begin: startCenter.latitude,
      end: target.latitude,
    );
    final lngTween = Tween<double>(
      begin: startCenter.longitude,
      end: target.longitude,
    );
    final zoomTween = Tween<double>(begin: startZoom, end: endZoom);

    void onTick() {
      _mapCtrl.move(
        LatLng(latTween.evaluate(curved), lngTween.evaluate(curved)),
        zoomTween.evaluate(curved),
      );
    }

    curved.addListener(onTick);
    try {
      await ctl.forward();
    } catch (_) {
      // Disposed mid-animation (e.g. user tapped a different gym);
      // the new tween is already taking over, nothing to do.
    } finally {
      curved.removeListener(onTick);
      if (identical(_cameraAnim, ctl)) {
        _cameraAnim = null;
      }
      ctl.dispose();
    }
  }

  /// Tween duration for user-triggered camera moves. ~650 ms with
  /// `easeInOutCubic` lands at the sweet spot — long enough that
  /// the eye reads the geographic relationship between the previous
  /// pin and the new one, short enough that nobody waits on it.
  static const _cameraAnimDuration = Duration(milliseconds: 650);

  /// Locate-me handler — pans to the cached GPS position, or kicks
  /// off a fresh permission + GPS read on first tap.
  Future<void> _onLocateMe() async {
    HapticFeedback.selectionClick();
    final cached = _userPosition;
    if (cached != null) {
      unawaited(_animateCameraTo(LatLng(cached.lat, cached.lng), zoom: 14));
      return;
    }
    await _locateUser(panMap: true);
  }

  /// Marker tap handler — pans the camera to centre the gym, opens
  /// its profile card, and gives a short haptic so the tap registers
  /// even when the camera move is small.
  void _onMarkerTap(GymSummary gym) {
    HapticFeedback.selectionClick();
    if (gym.lat != null && gym.lng != null) {
      unawaited(_animateCameraTo(LatLng(gym.lat!, gym.lng!), zoom: 15));
    }
    setState(() => _selectedGym = gym);
  }

  /// List-row tap handler — same affordance as a pin tap (camera
  /// glides to the gym + profile card slides in), plus an extra
  /// step: collapse the sheet to its minimum so the card is
  /// visible. Without the collapse, the card would render at the
  /// bottom of the screen *underneath* the still-expanded sheet
  /// and the member would never see it.
  ///
  /// Tapping the card itself routes to the gym detail page; this
  /// handler deliberately does NOT route, so a list-row tap and a
  /// pin tap end up at exactly the same intermediate state.
  void _selectGymFromList(GymSummary gym) {
    HapticFeedback.selectionClick();
    if (gym.lat != null && gym.lng != null) {
      unawaited(_animateCameraTo(LatLng(gym.lat!, gym.lng!), zoom: 15));
    }
    setState(() => _selectedGym = gym);
    if (_sheetCtrl.isAttached && _sheetCtrl.size > _sheetMin + 0.02) {
      _sheetCtrl.animateTo(
        _sheetMin,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
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
    // Tapping the filter button is a clear "I want to see and refine
    // results" intent — pop the gym-list sheet open in the background
    // so when the filter modal closes the member is looking at the
    // filtered list instead of having to drag the sheet up themselves.
    _autoOpenSheet();
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
    final asyncGyms = ref.watch(gymsListProvider);
    final category = ref.watch(gymsCategoryFilterProvider);
    final query = ref.watch(gymsSearchQueryProvider);
    final tiers = ref.watch(gymsTierFilterProvider);
    final favoritesOnly = ref.watch(gymsFavoritesOnlyProvider);
    final favorites = ref.watch(favoritedGymsProvider);
    final activeFilterCount =
        _activeFilterCount(category, tiers, favoritesOnly);

    // Member's region (Amman / Zarqa / Aqaba / ...) drives the map's
    // initial camera. Falls back to Amman until GPS resolves so the
    // first paint never centres on the wider region or null island.
    final user = _userPosition;
    final region = user == null
        ? jordanRegions.first
        : regionForPosition(user.lat, user.lng);

    // Resolve gyms to a concrete list, regardless of Riverpod's
    // async state. We deliberately render the map even while gyms
    // are still loading so the platform-view boots in parallel with
    // the network — the alternative (full-screen loader) wastes
    // ~300 ms on a cold open. Errors collapse to "no gyms"; the
    // bottom sheet's count strip surfaces them.
    final gyms = asyncGyms.maybeWhen(
      data: (g) => g,
      orElse: () => const <GymSummary>[],
    );
    final isLoadingGyms = asyncGyms.isLoading && gyms.isEmpty;
    final hasError = asyncGyms.hasError && gyms.isEmpty;

    return Scaffold(
      // The map is the body; bottom sheet floats over it. Edge-to-
      // edge so the map runs under the system status bar — chrome
      // is glass-blurred, so legibility is preserved.
      extendBodyBehindAppBar: true,
      body: Builder(
        builder: (context) {
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
          // Pins come from the *visible* set (after filters) so
          // toggling a category visibly thins the map — same
          // affordance every step of the way.
          final markerGyms =
              visible.where((g) => g.lat != null && g.lng != null).toList();
          final isDark = Theme.of(context).brightness == Brightness.dark;
          // CARTO basemaps — Voyager (light) and Dark Matter (dark).
          // Both are designed for app UIs in a low-saturation register.
          // Free under CC-BY 3.0 with the attribution rendered at the
          // bottom-leading corner.
          //
          // Path notes (load-bearing):
          //   - Voyager lives under `rastertiles/voyager` — a bare
          //     `/voyager/{z}/{x}/{y}.png` 404s on every CARTO host.
          //   - Dark Matter is at `/dark_all/{z}/{x}/{y}.png` — no
          //     prefix.
          //   - Light Positron is at `/light_all/...` if we ever want
          //     a higher-contrast light style.
          //
          // For higher volume / branded styling, swap the URL to a
          // Stadia/Mapbox style — single-line change.
          // Labeled tile variants — labels (city names, region
          // names, road names) render on top of every tile; the
          // polygon mask layer below cuts everything outside
          // Jordan's border so foreign labels never show. Jordan
          // itself reads with full place context.
          final tileUrl = isDark
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
          return Stack(
            children: [
              // 1. Full-screen tiled map (bottom of stack).
              FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter:
                      LatLng(region.centre.lat, region.centre.lng),
                  initialZoom: region.staticMapZoom.toDouble(),
                  // `containCenter` (NOT `contain`) — the camera
                  // CENTER must stay inside Jordan, but the viewport
                  // edges can extend beyond into the dark mask area.
                  // The stricter `contain` we tried first was so
                  // restrictive at low zoom that members couldn't
                  // pinch out to see the whole country — flutter_map
                  // forces the viewport to stay inside the bounds,
                  // which is impossible when the bounds are smaller
                  // than the viewport. `containCenter` lets the
                  // viewport be larger; the polygon mask handles
                  // making the out-of-Jordan area look right.
                  cameraConstraint: CameraConstraint.containCenter(
                    bounds: _jordanBounds,
                  ),
                  // minZoom 6 lets members pinch out to see all of
                  // Jordan with a small dark margin around it. 7 was
                  // tight enough that the country only just fit a
                  // phone width; 6 leaves enough room that the cut-
                  // out polygon's outline reads clearly.
                  minZoom: 6,
                  maxZoom: 18,
                  // Disable rotation — easy to trigger by accident on
                  // touch and members never need it. Pinch zoom + pan
                  // stay on by default.
                  interactionOptions: const InteractionOptions(
                    // pinchZoom = two-finger pinch
                    // doubleTapZoom = double-tap → step zoom in
                    // doubleTapDragZoom = double-tap-hold then drag
                    //   up/down to scrub zoom (Google Maps style)
                    // drag = single-finger pan
                    // flingAnimation = inertia after pan
                    // scrollWheelZoom = trackpad / web
                    // No rotation (members never need it; easy to
                    // trigger by accident on touch).
                    flags: InteractiveFlag.pinchZoom |
                        InteractiveFlag.drag |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.doubleTapDragZoom |
                        InteractiveFlag.flingAnimation |
                        InteractiveFlag.scrollWheelZoom,
                  ),
                  onTap: (_, __) {
                    // Tap on empty map dismisses the gym card +
                    // keyboard. Tap on a marker is captured by the
                    // marker's own GestureDetector first.
                    if (_selectedGym != null) {
                      setState(() => _selectedGym = null);
                    }
                    FocusScope.of(context).unfocus();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: tileUrl,
                    subdomains: const ['a', 'b', 'c', 'd'],
                    // Retina off for now — CARTO's free tier serves
                    // standard tiles reliably; @2x is patchy across
                    // their hosts and trades a small crispness win
                    // for failed-tile blanks. Re-enable once we move
                    // to a paid provider with consistent retina.
                    retinaMode: false,
                    userAgentPackageName: 'net.gympass.gympass',
                    // Surface tile failures in the debug console so a
                    // CARTO outage / blocked CDN doesn't silently leave
                    // the user with a grey rectangle. Without this, a
                    // 404 / DNS / TLS error reads identically to "no
                    // tiles configured" — extremely hard to diagnose
                    // from a screenshot.
                    errorTileCallback: (tile, error, stackTrace) {
                      debugPrint(
                        'TileLayer error coords=${tile.coordinates} err=$error',
                      );
                    },
                    // Tile cache lives in flutter_map's internal store;
                    // re-renders the same tile from cache on subsequent
                    // pans, so panning back to a recently-visited area
                    // is instant and doesn't re-fetch.
                  ),
                  // Out-of-Jordan mask. Renders a giant rectangle in
                  // solid background colour with Jordan's border as
                  // a hole — tiles inside the hole show through with
                  // their labels intact; outside the hole is filled
                  // dark, hiding all foreign tile content (roads,
                  // labels, terrain) without affecting Jordan's
                  // visibility. Border resolution is the dominant
                  // factor in how clean the cut-out reads — see the
                  // `_jordanPolygon` doc for why we use ~60 points.
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _maskOuterRect,
                        holePointsList: const [_jordanPolygon],
                        color: Colors.black,
                        borderColor: Colors.transparent,
                        borderStrokeWidth: 0,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      for (final g in markerGyms)
                        Marker(
                          point: LatLng(g.lat!, g.lng!),
                          width: 56,
                          height: 56,
                          // Anchor the bottom of the marker on the
                          // exact lat/lng — feels like a pin standing
                          // at the location, not a circle hovering at
                          // its centre.
                          alignment: Alignment.topCenter,
                          child: _GymPinMarker(
                            gym: g,
                            selected:
                                _selectedGym?.slug == g.slug,
                            onTap: () => _onMarkerTap(g),
                            // Double-tap on the pin = "I know which
                            // gym I want, take me there" — skips the
                            // intermediate card overlay and pushes
                            // the gym detail page directly.
                            onDoubleTap: () =>
                                context.push('/gyms/${g.slug}'),
                          ),
                        ),
                    ],
                  ),
                  // Required by CARTO's CC-BY 3.0 licence — small,
                  // unobtrusive, bottom-trailing corner.
                  const RichAttributionWidget(
                    alignment: AttributionAlignment.bottomLeft,
                    attributions: [
                      TextSourceAttribution(
                        '© OpenStreetMap, © CARTO',
                        prependCopyright: false,
                      ),
                    ],
                  ),
                ],
              ),
              // 2. Locate-me FAB — fixed position above the minimized
              //    sheet. Single-button trailing cluster: members
              //    zoom by pinching (two fingers) or by double-tap-
              //    and-drag (one finger up = zoom in, down = zoom
              //    out), so explicit `+/-` controls were redundant
              //    UI weight and were dropped.
              PositionedDirectional(
                bottom: MediaQuery.sizeOf(context).height * _sheetMin + 12,
                end: 16,
                child: _LocateMeButton(onTap: _onLocateMe),
              ),
              // 3. Selected-gym profile card — slides up from above
              //    the bottom sheet when a pin is tapped. Tapping it
              //    pushes the gym detail; tapping the map area
              //    dismisses (handled by MapOptions.onTap).
              if (_selectedGym != null)
                PositionedDirectional(
                  start: 12,
                  end: 12,
                  bottom: MediaQuery.sizeOf(context).height * _sheetMin + 12,
                  child: _SelectedGymCard(
                    gym: _selectedGym!,
                    distanceMeters: _distanceToGym(_selectedGym!),
                    onTap: () =>
                        context.push('/gyms/${_selectedGym!.slug}'),
                    onClose: () => setState(() => _selectedGym = null),
                  ),
                ),
              // 5. Top chrome — search + filter, glass-blurred over
              //    the live map.
              _ExploreTopBar(
                searchCtrl: _searchCtrl,
                searchFocus: _searchFocus,
                activeFilterCount: activeFilterCount,
                onOpenFilters: () => _openFiltersSheet(context),
              ),
              // 6. Bottom sheet — the "slider" with the gym list.
              _GymListSheet(
                controller: _sheetCtrl,
                onTapHandle: _expandSheet,
                gyms: visible,
                query: query,
                isLoading: isLoadingGyms,
                hasError: hasError,
                onGymSelect: _selectGymFromList,
                distanceFor: _distanceToGym,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Logo-as-pin marker. Renders the gym's circular logo (or
/// initials fallback) with a tier-coloured ring + drop shadow, and
/// a small needle below pointing at the actual lat/lng. The whole
/// pin is a Flutter widget — pinch zoom on the map scales the
/// ring/logo proportionally with the rest of the UI, so the result
/// looks like part of the app rather than a foreign SDK marker.
///
/// Tap behaviour:
///   - Single tap → [onTap] fires after the gesture-recogniser
///     resolves single vs double (~250 ms). Parent uses this to
///     show the floating profile card.
///   - Double tap → [onDoubleTap] fires immediately on the second
///     tap. Parent uses this to navigate straight to the gym
///     detail page (skipping the card overlay).
class _GymPinMarker extends ConsumerWidget {
  const _GymPinMarker({
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
    final tier = gym.tier == null ? null : GPTier.byKey(gym.tier!);
    final accent = tier?.color ?? gp.accentInk;
    final apiBaseUrl = ref.watch(envProvider).apiBaseUrl;
    final initial = gymInitials(gym.nameEn);
    final ring = selected ? 3.0 : 2.0;
    final size = selected ? 44.0 : 36.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gp.bg2,
              border: Border.all(color: accent, width: ring),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: selected ? 0.50 : 0.30),
                  blurRadius: selected ? 16 : 10,
                  spreadRadius: selected ? -2 : -3,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: gym.logoUrl != null && gym.logoUrl!.isNotEmpty
                ? Image.network(
                    resolveMediaUrl(apiBaseUrl, gym.logoUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
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
          // Pin needle — a small tier-coloured triangle pointing at
          // the lat/lng under the logo. Just enough to read as a
          // pin instead of a floating circle.
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
  bool shouldRepaint(covariant _PinNeedlePainter old) =>
      old.color != color;
}

/// Floating profile card shown when a marker is tapped. Slides in
/// just above the bottom sheet's resting handle, dismissed by
/// tapping the map (handled by MapOptions.onTap) or the close X.
class _SelectedGymCard extends ConsumerWidget {
  const _SelectedGymCard({
    required this.gym,
    required this.distanceMeters,
    required this.onTap,
    required this.onClose,
  });

  final GymSummary gym;
  final double? distanceMeters;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final name = isAr && gym.nameAr.isNotEmpty ? gym.nameAr : gym.nameEn;
    final tier = gym.tier == null ? null : GPTier.byKey(gym.tier!);
    final accent = tier?.color ?? gp.accentInk;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        // Slide in from below + fade. Captures the "card popped up
        // from the marker" feel.
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 24),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GPRadius.lg),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: gp.bg2.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(GPRadius.lg),
              border: Border.all(color: gp.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: GPText.body(
                          size: 16,
                          color: gp.fg,
                          weight: FontWeight.w700,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
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
                const SizedBox(width: 8),
                _HeroLogo(gym: gym, gp: gp, accent: accent),
                IconButton(
                  iconSize: 18,
                  splashRadius: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: gp.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Locate-me FAB. Sits over the map's trailing edge; hits
/// [_ExplorePageState._onLocateMe] which pans the camera to the
/// member's GPS position (or kicks off a fresh permission request +
/// GPS read on first tap).
class _LocateMeButton extends StatelessWidget {
  const _LocateMeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Material(
      color: gp.bg2.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: gp.line),
          ),
          child: Icon(Icons.my_location, size: 20, color: gp.fg),
        ),
      ),
    );
  }
}

/// Bottom sheet — the "slider" that holds the gym list. Floats over
/// the live map; drags between [minChildSize] (sheet just shows the
/// handle + count) and [maxChildSize] (sheet covers most of the map
/// for full-list browsing). Sheet content is the same gym list rows
/// the previous list-first explore page rendered, so all the
/// search-highlight + distance + tier-ring affordances carry over.
class _GymListSheet extends ConsumerWidget {
  const _GymListSheet({
    required this.controller,
    required this.onTapHandle,
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
  final List<GymSummary> gyms;
  final String query;
  final bool isLoading;
  final bool hasError;

  /// Called when a row is tapped. The parent decides what "select"
  /// means (animate camera, raise the floating profile card, snap
  /// the sheet down) — the row itself just reports the intent.
  final ValueChanged<GymSummary> onGymSelect;
  final double? Function(GymSummary) distanceFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    return DraggableScrollableSheet(
      controller: controller,
      // Initial state: minimized — only the handle peeks above the
      // bottom nav. Member sees the map first; opens the list with
      // a tap on the handle, a drag, or by interacting with the
      // search field / filter button (auto-open in those paths).
      initialChildSize: _ExplorePageState._sheetMin,
      minChildSize: _ExplorePageState._sheetMin,
      maxChildSize: _ExplorePageState._sheetMax,
      // Snap to the three user-defined sizes — drag-release lands
      // on whichever of min / default / max is closest, never an
      // in-between awkward size. Same affordance as Uber / Apple
      // Maps' bottom panel.
      snap: true,
      snapSizes: const [
        _ExplorePageState._sheetMin,
        _ExplorePageState._sheetAutoOpen,
        _ExplorePageState._sheetMax,
      ],
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
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTapHandle,
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
                            style:
                                GPText.body(size: 14, color: gp.muted),
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
                          // overlay + sheet collapse) — same end
                          // state as tapping the gym's pin on the
                          // map. The card itself routes to detail.
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

class GeoPoint {
  const GeoPoint({required this.lat, required this.lng});
  final double lat;
  final double lng;
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
                // No `onChanged` here — the controller listener in
                // `_ExplorePageState._onSearchTextChanged` already
                // pushes (debounced) into the search-query provider.
                // Wiring both fires the same update twice per
                // keystroke and doubles the rebuild work.
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
