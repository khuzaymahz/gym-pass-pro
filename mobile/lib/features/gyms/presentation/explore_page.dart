import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/gym_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../data/gym_repository.dart';
import '../data/gym_summary.dart';
import '../data/home_region_store.dart';
import '../data/jordan_regions.dart';
import '../data/location_service.dart';
import 'gym_detail_page.dart' show favoritedGymsProvider;
import 'gyms_filter_state.dart';
import 'widgets/explore_top_bar.dart';
import 'widgets/filters_sheet.dart';
import 'widgets/gym_list_sheet.dart';
import 'widgets/gym_pin_marker.dart';
import 'widgets/jordan_labels_layer.dart';
import 'widgets/locate_me_button.dart';
import 'widgets/selected_gym_card.dart';

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
///   3. Locate-me FAB on the trailing edge — stays in fixed position
///      relative to the viewport.
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
///
/// All the internal widgets (pin marker, profile card, list sheet,
/// filters sheet, top chrome, Jordan labels clipper) live under
/// `widgets/` alongside this file. Page state — controllers, GPS,
/// camera tweens, filter logic — stays here.
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
  /// moves for locate-me and tap-to-pan-to-gym.
  final MapController _mapCtrl = MapController();

  /// Currently-tapped gym, drives the floating profile card. Null
  /// when no pin is selected (card hidden). Updates on pin tap; map
  /// taps clear it.
  GymSummary? _selectedGym;

  /// Member's last-known position. Null until GPS resolves or the
  /// stored value is read. Drives distance pills + the locate-me
  /// camera target.
  GeoPoint? _userPosition;

  /// In-flight locate-me request. Disables the FAB while a fresh GPS
  /// read is pending so a tap-spam can't queue overlapping requests
  /// (and so the FAB can swap its icon for a small spinner — the
  /// member sees the tap was registered).
  bool _locating = false;

  /// First-paint warm-up gate. The base CARTO tile layer and the
  /// labels-only layer fetch independently, and on a slow network
  /// the labels (smaller PNG payloads) often land before the base
  /// tiles — so members briefly see floating Arabic place names on
  /// a blank canvas. Hold a loader overlay over the map until base
  /// tiles have actually painted AND the gym list is ready, then
  /// fade it out via `AnimatedOpacity`.
  ///
  /// Truthful "is the map loaded" signal — the previous fixed
  /// 1.4 s timer was a guess. Members on slow networks still saw
  /// the half-rendered map after the timer fired; members on warm
  /// caches sat through 1.4 s of loader for a map that was already
  /// painted at 200 ms. Tracking real tile-load completion fixes
  /// both: the loader holds exactly as long as the network says
  /// it needs to.
  ///
  /// State machine:
  ///   - `_firstTileLoaded` flips true the moment the base
  ///     `TileLayer`'s `tileBuilder` reports a tile with
  ///     `loadFinishedAt != null`.
  ///   - `_tilesGraceTimer` (300 ms) is armed on that first load
  ///     so neighbouring tiles in the visible viewport have time
  ///     to paint too — without this, the loader vanishes the
  ///     instant ONE tile lands and the rest of the screen is
  ///     still blank.
  ///   - `_tilesCeilingTimer` (8 s) is the offline / CARTO-down
  ///     safety: if no tile ever loads, the loader still dismisses
  ///     so the member can see the (empty / errored) map and
  ///     understand they're offline.
  ///
  /// `_tilesLoaded` is the consumer-facing flag, set when EITHER
  /// the grace timer or the ceiling timer fires.
  bool _firstTileLoaded = false;
  bool _tilesLoaded = false;
  Timer? _tilesGraceTimer;
  Timer? _tilesCeilingTimer;
  static const _tilesGraceDuration = Duration(milliseconds: 300);
  static const _tilesCeilingDuration = Duration(seconds: 8);

  /// Debounce timer for the search box. Without it, every keystroke
  /// pushes a new query into the Riverpod state, which rebuilds the
  /// page → re-filters all gyms → recomputes the marker set. Cheap
  /// individually, noticeable on a hot keyboard. 180 ms is below the
  /// threshold where typing feels laggy but high enough to coalesce
  /// a fast burst into a single recompute.
  Timer? _searchDebounce;
  static const _searchDebounceDuration = Duration(milliseconds: 180);

  /// Controller for the bottom sheet so a tap on the handle can
  /// programmatically expand it. The sheet starts at the smallest
  /// snap (handle peek only) so the map is the dominant surface;
  /// the user opens the list with either a tap or a drag.
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  /// Jordan country bounds for camera constraint. Sets the hard
  /// edges of the world the member can pan to — drag past the edge
  /// and flutter_map clamps. The southern edge sits ~0.5° below
  /// Aqaba's actual border so members at the pinch-out floor get
  /// a little extra map breathing room toward Saudi (per user
  /// preference "give a little extra access to go more from down
  /// map"); the labels-clip layer still hides any foreign place
  /// names that fall in that buffer.
  static final LatLngBounds _jordanBounds = LatLngBounds(
    const LatLng(28.65, 34.85),
    const LatLng(33.45, 39.40),
  );

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
    // Offline / CARTO-down ceiling — see `_firstTileLoaded` doc.
    // If no tile reports loaded inside this window, hide the loader
    // anyway so the member sees the empty/errored map state and
    // doesn't sit forever on a spinner.
    _tilesCeilingTimer = Timer(_tilesCeilingDuration, () {
      if (!mounted || _tilesLoaded) return;
      setState(() => _tilesLoaded = true);
    });
  }

  /// Called from the base `TileLayer`'s `tileBuilder` the first
  /// time a tile reports `loadFinishedAt != null`. Arms the grace
  /// timer; subsequent calls are no-ops because the tileBuilder
  /// fires per build for every visible tile and we only care
  /// about the first paint.
  void _onFirstTileLoaded() {
    if (_firstTileLoaded) return;
    _firstTileLoaded = true;
    _tilesGraceTimer = Timer(_tilesGraceDuration, () {
      if (!mounted || _tilesLoaded) return;
      setState(() => _tilesLoaded = true);
    });
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
    if (_sheetCtrl.size >= exploreSheetAutoOpen - 0.02) return;
    _sheetCtrl.animateTo(
      exploreSheetAutoOpen,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tilesGraceTimer?.cancel();
    _tilesCeilingTimer?.cancel();
    _searchFocus.removeListener(_onSearchFocusChanged);
    _searchFocus.dispose();
    _searchCtrl.removeListener(_onSearchTextChanged);
    _searchCtrl.dispose();
    _sheetCtrl.dispose();
    _cameraAnim?.dispose();
    super.dispose();
  }

  /// Map is ready to reveal once base tiles have actually painted
  /// (`_tilesLoaded`, set by either the grace timer after the first
  /// real tile load or the ceiling timer for offline cases) AND
  /// the gym list has resolved (data hydrated, regardless of empty
  /// or populated). Both are required: tiles alone leaves the
  /// member staring at a map with no pins for the network round-
  /// trip; data alone reveals while tiles are still painting.
  /// Together they give a stable first impression.
  bool _isMapReady(AsyncValue<List<GymSummary>> asyncGyms) {
    return _tilesLoaded && asyncGyms.hasValue;
  }

  /// Single tap on the handle. Divides the sheet's vertical range
  /// at the **mid** snap so the policy is robust to in-between
  /// drag stops and animation tails:
  ///   - Above mid (max, near-max, or any upper drag stop) → drop
  ///     to mid. Gentle step-down regardless of how exactly the
  ///     sheet sits at the moment of the tap.
  ///   - Between min and mid → close to min. The everyday
  ///     "hide the list".
  ///   - At min → open to mid. The everyday "show me the list".
  ///
  /// Pairs with [_expandSheetMax] (double-tap) which does the
  /// fast big-jumps: any-position → max, max → min.
  Future<void> _expandSheet() async {
    if (!_sheetCtrl.isAttached) return;
    final current = _sheetCtrl.size;
    double target;
    if (current >= exploreSheetAutoOpen + 0.02) {
      // Anywhere above the mid snap (max, near-max, or any drag
      // stop in the upper half) → drop to mid. Robust to a sheet
      // that's at 0.799 instead of exactly 0.80, or a drag
      // released at 0.65 — the previous "max - 0.02" threshold
      // missed both cases and sent them straight to min.
      target = exploreSheetAutoOpen;
    } else if (current > exploreSheetMin + 0.05) {
      // Lower half above min → close to min.
      target = exploreSheetMin;
    } else {
      // At min → open to mid.
      target = exploreSheetAutoOpen;
    }
    await _sheetCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  /// Double tap on the handle is a max-or-close toggle. From any
  /// position below max, jumps to `exploreSheetMax`; from max,
  /// closes the sheet all the way to `exploreSheetMin`. That gives
  /// a fast in-out gesture: double-tap once to fully open, again
  /// to fully close — no third tap needed to dismiss the sheet.
  /// Single tap (`_expandSheet`) still handles the everyday
  /// min ↔ mid toggle.
  Future<void> _expandSheetMax() async {
    if (!_sheetCtrl.isAttached) return;
    final current = _sheetCtrl.size;
    final target = current >= exploreSheetMax - 0.02
        ? exploreSheetMin
        : exploreSheetMax;
    await _sheetCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// Hydrate the user's last home location from secure storage (so
  /// the first paint has a real region) and fire a fresh GPS read in
  /// the background. The fresh read updates the cross-app
  /// `userPositionProvider` so distance-aware widgets elsewhere
  /// (home, gym detail) see it too.
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
  Future<void> _animateCameraTo(LatLng target, {double? zoom}) async {
    final startCenter = _mapCtrl.camera.center;
    final startZoom = _mapCtrl.camera.zoom;
    final endZoom = zoom ?? startZoom;

    if (startCenter.latitude == target.latitude &&
        startCenter.longitude == target.longitude &&
        startZoom == endZoom) {
      return;
    }

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

  /// Single tap on the locate-me FAB — resolves the user's position
  /// and frames their region with surrounding gyms ("eagle view").
  /// Always re-reads GPS (skipping the cached position is
  /// intentional — the cached value is from the last session and
  /// may be hundreds of km from where the member actually is, so a
  /// "return to me" affordance that flies to the wrong city reads
  /// as broken). Surfaces a snackbar on failure so the silent "did
  /// anything happen?" experience is gone:
  ///
  ///   - serviceDisabled → "Turn on Location Services" + Settings deep-link.
  ///   - deniedForever   → "Permission denied. Tap Settings to enable."
  ///   - denied          → simple toast, the next tap will re-prompt.
  ///   - unavailable     → "Couldn't get location, try again."
  Future<void> _onLocateMe() => _resolveAndFrame(close: false);

  /// Double tap on the locate-me FAB — progressively zooms the
  /// camera in toward the user dot. Each successive double-tap
  /// steps by +2 zoom levels from the current camera, so the
  /// progression goes eagle → district → block → street as the
  /// member keeps tapping, capped at the map's `maxZoom` (18).
  ///
  /// Two paths:
  ///   - **First tap of the session** (no cached `_userPosition`):
  ///     resolve via the full GPS flow, then frame at a moderate
  ///     close zoom (13) so the very first double-tap doesn't slam
  ///     all the way to street level. The member can keep double-
  ///     tapping for tighter framing.
  ///   - **Subsequent taps** (`_userPosition != null`): skip the
  ///     GPS round-trip entirely — the position hasn't changed in
  ///     milliseconds — and just step the camera in by +2 zoom
  ///     from wherever it is right now. Keeps the gesture snappy
  ///     and progressive.
  Future<void> _onLocateMeClose() async {
    if (_locating) return;
    // Subsequent-tap fast path — cached position, no GPS call.
    if (_userPosition != null) {
      HapticFeedback.selectionClick();
      final currentZoom = _mapCtrl.camera.zoom;
      final nextZoom = (currentZoom + 2).clamp(7.0, 18.0);
      if (nextZoom <= currentZoom) return; // already at max
      unawaited(
        _animateCameraTo(
          LatLng(_userPosition!.lat, _userPosition!.lng),
          zoom: nextZoom,
        ),
      );
      return;
    }
    // First tap of the session — fall back to the full GPS
    // resolve, frame at a moderate close zoom rather than the
    // eagle view.
    return _resolveAndFrame(close: true);
  }

  Future<void> _resolveAndFrame({required bool close}) async {
    if (_locating) return;
    HapticFeedback.selectionClick();
    setState(() => _locating = true);
    try {
      final service = ref.read(locationServiceProvider);
      final result = await service.currentPosition();
      if (!mounted) return;
      switch (result.status) {
        case LocationStatus.granted:
          final pos = result.position!;
          setState(() {
            _userPosition = GeoPoint(lat: pos.latitude, lng: pos.longitude);
          });
          ref.read(userPositionProvider.notifier).state =
              HomeLocation(lat: pos.latitude, lng: pos.longitude);
          unawaited(
            ref
                .read(homeRegionStoreProvider)
                .write(pos.latitude, pos.longitude),
          );
          // Two camera modes for the same gesture:
          //   - `close == false` (single tap): region-fit eagle
          //     view so the user dot is centred among neighbouring
          //     partner gyms. Default affordance — members usually
          //     want to see what's near them, not exactly where
          //     they're standing.
          //   - `close == true` (first double tap of the session):
          //     zoom-13 pan to the dot. Moderate close — visible
          //     streets and a few city blocks, not street-level.
          //     Subsequent double-taps step in +2 each time
          //     (handled in `_onLocateMeClose`), so the member
          //     can keep tapping for tighter framing.
          if (close) {
            unawaited(
              _animateCameraTo(
                LatLng(pos.latitude, pos.longitude),
                zoom: 13,
              ),
            );
          } else {
            _fitCameraToRegion(
              regionForPosition(pos.latitude, pos.longitude),
            );
          }
          break;
        case LocationStatus.serviceDisabled:
          _showLocateError(
            AppLocalizations.of(context).exploreLocateServiceDisabled,
            actionLabel: AppLocalizations.of(context).exploreLocateOpenSettings,
            onAction: () => service.openLocationSettings(),
          );
          break;
        case LocationStatus.deniedForever:
          _showLocateError(
            AppLocalizations.of(context).exploreLocatePermissionDeniedForever,
            actionLabel: AppLocalizations.of(context).exploreLocateOpenSettings,
            onAction: () => service.openAppSettings(),
          );
          break;
        case LocationStatus.denied:
          _showLocateError(
            AppLocalizations.of(context).exploreLocatePermissionDenied,
          );
          break;
        case LocationStatus.unavailable:
          _showLocateError(
            AppLocalizations.of(context).exploreLocateUnavailable,
          );
          break;
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  /// Surface a snackbar with optional trailing action. Centralised so
  /// every locate-me failure path uses the same look and dismissal
  /// rules — replaces the previous silent return that left the member
  /// wondering whether the tap registered.
  void _showLocateError(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }

  void _onMarkerTap(GymSummary gym) {
    HapticFeedback.selectionClick();
    if (gym.lat != null && gym.lng != null) {
      unawaited(_animateCameraTo(LatLng(gym.lat!, gym.lng!), zoom: 15));
    }
    setState(() => _selectedGym = gym);
  }

  /// List-row tap handler — same affordance as a pin tap (camera
  /// glides to the gym + profile card slides in), plus an extra
  /// step: collapse the sheet to its minimum so the card is visible.
  /// Without the collapse, the card would render at the bottom of
  /// the screen *underneath* the still-expanded sheet and the
  /// member would never see it.
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
    if (_sheetCtrl.isAttached && _sheetCtrl.size > exploreSheetMin + 0.02) {
      _sheetCtrl.animateTo(
        exploreSheetMin,
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
      builder: (_) => const FiltersSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Auto-clear the favourites-only filter the moment the
    // favourites set drops to empty (e.g. member opens a gym and
    // un-favourites it from there). Without this, the next time
    // they open the filters sheet they'd see "Favourites only"
    // toggled ON but with count = 0 — and because the toggle row
    // was disabled when count = 0, the only way out was hitting
    // Reset.
    ref.listen<Set<String>>(favoritedGymsProvider, (previous, next) {
      if (next.isEmpty && ref.read(gymsFavoritesOnlyProvider)) {
        ref.read(gymsFavoritesOnlyProvider.notifier).state = false;
      }
    });

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
          // Two-layer tile strategy: base layer (no labels) renders
          // everywhere; labels layer is clipped to Jordan's polygon
          // (see [JordanLabelsLayer]) so foreign place names never
          // appear.
          final tileUrlBase = isDark
              ? 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}.png'
              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png';
          final tileUrlLabels = isDark
              ? 'https://{s}.basemaps.cartocdn.com/dark_only_labels/{z}/{x}/{y}.png'
              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}.png';
          return Stack(
            children: [
              // 1. Full-screen tiled map (bottom of stack).
              FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: LatLng(region.centre.lat, region.centre.lng),
                  initialZoom: region.staticMapZoom.toDouble(),
                  // `contain` — the entire camera VIEWPORT must stay
                  // within Jordan's bounding rectangle. minZoom 7 is
                  // the user-defined "pinch-out floor" where Jordan
                  // fits the screen with a small strip of
                  // neighbouring terrain above and below.
                  cameraConstraint: CameraConstraint.contain(
                    bounds: _jordanBounds,
                  ),
                  minZoom: 7,
                  maxZoom: 18,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom |
                        InteractiveFlag.drag |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.doubleTapDragZoom |
                        InteractiveFlag.flingAnimation |
                        InteractiveFlag.scrollWheelZoom,
                  ),
                  onTap: (_, __) {
                    // Tap on empty map dismisses three things at
                    // once — selected-gym card, keyboard, and an
                    // expanded gym-list bottom sheet. Tap on a
                    // marker is captured by the marker's own
                    // GestureDetector before this onTap fires, so
                    // selecting a pin still pops the card and
                    // doesn't collapse the sheet.
                    if (_selectedGym != null) {
                      setState(() => _selectedGym = null);
                    }
                    FocusScope.of(context).unfocus();
                    // Collapse the sheet if it's expanded above the
                    // resting-handle position. The 0.02 epsilon
                    // matters because the user might be holding the
                    // sheet at exactly `exploreSheetMin` and a
                    // micro-overshoot would otherwise trigger an
                    // animation back to the same place.
                    if (_sheetCtrl.isAttached &&
                        _sheetCtrl.size > exploreSheetMin + 0.02) {
                      _sheetCtrl.animateTo(
                        exploreSheetMin,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                ),
                children: [
                  // Base — terrain only, no labels, rendered globally.
                  TileLayer(
                    urlTemplate: tileUrlBase,
                    subdomains: const ['a', 'b', 'c', 'd'],
                    retinaMode: false,
                    userAgentPackageName: 'net.gympass.gympass',
                    // tileBuilder fires per build for every tile in
                    // the visible viewport. The `tile.loadFinishedAt`
                    // field is non-null once flutter_map has finished
                    // decoding that tile's PNG into a paintable
                    // texture — the exact moment the pixels are
                    // about to land on screen. We forward that to
                    // `_onFirstTileLoaded` (which guards itself
                    // against repeated calls) so the warm-up overlay
                    // dismisses on real tile paint, not a fixed
                    // timer guess. Defer the setState to the next
                    // frame because the build phase is mid-flight
                    // here. `tileWidget` is the unmodified tile —
                    // we just inspect, never wrap.
                    tileBuilder: (context, tileWidget, tile) {
                      if (tile.loadFinishedAt != null && !_firstTileLoaded) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          _onFirstTileLoaded();
                        });
                      }
                      return tileWidget;
                    },
                    errorTileCallback: (tile, error, stackTrace) {
                      debugPrint(
                        'TileLayer base error coords=${tile.coordinates} err=$error',
                      );
                    },
                  ),
                  // Labels overlay — text-only tile clipped to Jordan.
                  JordanLabelsLayer(tileUrl: tileUrlLabels),
                  MarkerLayer(
                    markers: [
                      // User-position marker — classic blue accuracy
                      // dot, distinct from gym pins so the eye reads
                      // "this is YOU" vs "this is a club". Renders
                      // only when we've actually resolved a position;
                      // before that the locate-me FAB is the only
                      // affordance pointing at the absent dot.
                      if (_userPosition != null)
                        Marker(
                          point: LatLng(
                            _userPosition!.lat,
                            _userPosition!.lng,
                          ),
                          width: 28,
                          height: 28,
                          child: const _UserPositionMarker(),
                        ),
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
                          child: GymPinMarker(
                            gym: g,
                            selected: _selectedGym?.slug == g.slug,
                            onTap: () => _onMarkerTap(g),
                            // Double-tap on the pin = "I know which
                            // gym I want, take me there" — skips the
                            // intermediate card overlay and pushes
                            // the gym detail page directly.
                            onDoubleTap: () => context.push('/gyms/${g.slug}'),
                          ),
                        ),
                    ],
                  ),
                  // Required by CARTO's CC-BY 3.0 licence.
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
              // 1.5. Map warm-up overlay — frosted-glass blur over the
              //      live map + GymLoader on top. Without this, members
              //      briefly see the half-rendered map: the labels-only
              //      layer paints faster than the base CARTO tile layer
              //      on a cold network, leaving Arabic place names
              //      floating over a blank canvas until the streets
              //      paint in.
              //
              //      The blur deliberately keeps the map *visible*
              //      underneath — members see "something is loading
              //      back there" rather than a flat opaque block, which
              //      reads as the page being stuck. A semi-transparent
              //      tint on top of the blur keeps the dumbbell loader
              //      readable. Same vocabulary as the bottom sheet
              //      uses for its glass effect, just heavier on the
              //      blur and lighter on the tint.
              //
              //      `AnimatedSwitcher` (not `AnimatedOpacity`) so the
              //      `BackdropFilter` actually *unmounts* once the map
              //      reveals — `BackdropFilter` is expensive to
              //      composite every frame, and `AnimatedOpacity` would
              //      keep it alive at opacity 0.0 forever. With
              //      `AnimatedSwitcher` the filter is gone after the
              //      280 ms crossfade.
              //
              //      `Positioned.fill` is required — the parent Stack
              //      uses `StackFit.loose`, so a non-Positioned child
              //      would shrink to the loader's intrinsic size
              //      (~56 px) rather than covering the map.
              //
              //      `ClipRect` around the BackdropFilter is required
              //      by Flutter — the filter needs a clip boundary to
              //      know which region to sample from the layer below.
              //
              //      Hidden once base tiles have actually painted AND
              //      the gym list has resolved (see `_isMapReady`).
              //      `IgnorePointer` while visible so taps don't
              //      accidentally hit the map underneath.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: _isMapReady(asyncGyms),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _isMapReady(asyncGyms)
                        ? const SizedBox.shrink(
                            key: ValueKey('map-overlay-ready'),
                          )
                        : ClipRect(
                            key: const ValueKey('map-overlay-loading'),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: 16,
                                sigmaY: 16,
                              ),
                              child: ColoredBox(
                                // Theme-aware tint at ~45 % alpha —
                                // dark surface in dark mode, off-white
                                // in light. Heavy enough that the
                                // dumbbell loader stays high-contrast
                                // and readable; light enough that the
                                // blurred map shapes show through and
                                // members read "the map is loading"
                                // instead of "the screen is blocked."
                                color: Theme.of(context)
                                    .scaffoldBackgroundColor
                                    .withValues(alpha: 0.45),
                                child: const Center(
                                  child: GymLoader(
                                    size: GymLoaderSize.large,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              // 2. Locate-me FAB — fixed position above the minimized
              //    sheet.
              PositionedDirectional(
                bottom: MediaQuery.sizeOf(context).height * exploreSheetMin + 12,
                end: 16,
                child: LocateMeButton(
                  onTap: _onLocateMe,
                  onDoubleTap: _onLocateMeClose,
                  loading: _locating,
                ),
              ),
              // 3. Selected-gym profile card — slides up from above
              //    the bottom sheet when a pin is tapped.
              if (_selectedGym != null)
                PositionedDirectional(
                  start: 12,
                  end: 12,
                  bottom:
                      MediaQuery.sizeOf(context).height * exploreSheetMin + 12,
                  child: SelectedGymCard(
                    gym: _selectedGym!,
                    distanceMeters: _distanceToGym(_selectedGym!),
                    onTap: () => context.push('/gyms/${_selectedGym!.slug}'),
                    onClose: () => setState(() => _selectedGym = null),
                  ),
                ),
              // 4. Top chrome — search + filter, glass-blurred over
              //    the live map.
              ExploreTopBar(
                searchCtrl: _searchCtrl,
                searchFocus: _searchFocus,
                activeFilterCount: activeFilterCount,
                onOpenFilters: () => _openFiltersSheet(context),
              ),
              // 5. Bottom sheet — the "slider" with the gym list.
              GymListSheet(
                controller: _sheetCtrl,
                onTapHandle: _expandSheet,
                onDoubleTapHandle: _expandSheetMax,
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

class GeoPoint {
  const GeoPoint({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

/// "You are here" dot rendered on the explore map at the member's
/// resolved position. Three layers of the classic Google-Maps user
/// pin pattern:
///
///   - **Outer halo** at low alpha — a soft 28-px circle that
///     hints at GPS accuracy without claiming a precise radius.
///   - **White ring** — a 16-px disc that separates the inner dot
///     from the halo + tile texture so the marker reads on any
///     map background (the dark CARTO basemap, the warm-paper
///     light basemap, green parks, yellow roads).
///   - **Inner dot** — the saturated blue centre, 10 px.
///
/// Hard-coded blue (`#1A73E8`) rather than a tier colour so the
/// member never confuses "you are here" with a gym pin. Static
/// — no pulse, no animation. The locate-me FAB animation is
/// where the "found you" feedback lives; the dot itself stays
/// quiet so the eye registers it as a location, not as something
/// that wants attention.
class _UserPositionMarker extends StatelessWidget {
  const _UserPositionMarker();

  static const _userBlue = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _userBlue.withValues(alpha: 0.22),
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _userBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
