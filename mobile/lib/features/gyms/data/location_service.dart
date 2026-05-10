import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Result of a one-shot "where is the user?" query.
///
/// Five terminal states:
///   - `granted` + `position`: GPS came back, the map can centre on it.
///   - `denied`: user dismissed the prompt this round but can be
///     re-asked. UI prompts again on the next locate-me tap.
///   - `deniedForever`: user has flipped the OS-level toggle to
///     "never allow" — `requestPermission` will no-op until the
///     member opens system Settings. UI offers an "Open Settings"
///     action.
///   - `serviceDisabled`: location services are off at the device
///     level (airplane mode, no GPS hardware, etc.). UI offers a
///     deep-link to the location services screen.
///   - `unavailable`: granted, services on, but GPS didn't return
///     a fix in time (timeout, indoor, hardware error). UI shows
///     a "try again" message.
class LocationResult {
  const LocationResult({required this.status, this.position});

  final LocationStatus status;
  final Position? position;

  bool get hasPosition => status == LocationStatus.granted && position != null;
}

enum LocationStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
}

/// Thin wrapper over `geolocator` so the page doesn't have to know
/// about the permission state machine. Keeps three behaviours in
/// one place:
///
///   1. Permission first — never call `getCurrentPosition` blind, the
///      iOS prompt won't appear unless we call `requestPermission`.
///   2. Last-known-fix fast path — the OS caches the most recent
///      fix from any location-using app on the device. Returning
///      it instantly handles emulators (no real GPS), indoor /
///      weak-signal scenarios, and cold-start devices that haven't
///      acquired a fresh fix yet. Only freshness gate is "is it
///      recent enough" (5 min) — a member who walked half a block
///      doesn't need a brand-new fix to centre the map.
///   3. Bounded live read with graceful accuracy step-down — if the
///      cache miss falls through, try high accuracy briefly (4 s),
///      then drop to medium (8 s). The two-step beats the previous
///      single 6-second medium attempt: high+brief catches the easy
///      cases instantly, the medium fallback gives weak-signal
///      devices a real chance instead of failing flat.
class LocationService {
  const LocationService();

  /// How fresh a cached fix has to be for `currentPosition` to
  /// return it instead of triggering a live read. 5 minutes is
  /// conservative for "centre my map" UX — a member who's strolled
  /// the equivalent distance still wants the cached coords more
  /// than they want to wait on a fresh GPS lock. Anything older,
  /// fall through to the live attempt.
  static const _lastKnownFreshness = Duration(minutes: 5);

  Future<LocationResult> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(status: LocationStatus.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(status: LocationStatus.deniedForever);
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult(status: LocationStatus.denied);
    }

    // Fast path — last-known fix from the OS cache. Instant when
    // present, prefers a fresh fix but accepts a stale one over
    // failing entirely. Android emulators with mock locations set
    // often return positions with `timestamp == null` (the static
    // config doesn't write one) — earlier code rejected those and
    // fell through to live reads that the emulator never satisfies.
    Position? cachedFix;
    try {
      cachedFix = await Geolocator.getLastKnownPosition();
    } catch (_) {
      // `getLastKnownPosition` can throw on web / unsupported
      // platforms — fall through to live read.
    }
    if (cachedFix != null && _isFresh(cachedFix.timestamp)) {
      return LocationResult(
        status: LocationStatus.granted,
        position: cachedFix,
      );
    }

    // Two-step live attempt — high accuracy with a brief 4 s
    // window catches outdoor / strong-signal cases instantly;
    // dropping to medium with 8 s gives indoor / weak-signal
    // devices the budget they actually need.
    final firstAttempt = await _tryFix(
      accuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 4),
    );
    if (firstAttempt != null) {
      return LocationResult(
        status: LocationStatus.granted,
        position: firstAttempt,
      );
    }
    final secondAttempt = await _tryFix(
      accuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 8),
    );
    if (secondAttempt != null) {
      return LocationResult(
        status: LocationStatus.granted,
        position: secondAttempt,
      );
    }

    // Last resort — accept the OS-cached fix even if it failed the
    // freshness gate or has no timestamp. For "centre my map" UX a
    // position that's an hour old (or undated) is materially better
    // than no position at all; the member sees roughly where they
    // are and can pan if needed. This is what unblocks Android
    // emulators that expose a static mock location with a null
    // timestamp — without this branch every locate-me tap on the
    // emulator failed, regardless of whether a fix was actually
    // configured.
    if (cachedFix != null) {
      return LocationResult(
        status: LocationStatus.granted,
        position: cachedFix,
      );
    }

    // No cached fix, no live read — distinct from "denied" so the UI
    // can offer a "try again" message rather than asking the member
    // to re-grant permission they already gave.
    return const LocationResult(status: LocationStatus.unavailable);
  }

  Future<Position?> _tryFix({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  bool _isFresh(DateTime? timestamp) {
    if (timestamp == null) return false;
    final age = DateTime.now().toUtc().difference(timestamp.toUtc());
    return age >= Duration.zero && age <= _lastKnownFreshness;
  }

  /// Deep-link into the OS app-settings page so a member who flipped
  /// "never allow" can re-grant location permission. Returns true if
  /// the system honoured the open request. The corresponding system-
  /// settings screen for *services off* (airplane mode, GPS hardware
  /// disabled) is `openLocationSettings`.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Distance in metres between two points. Wraps `Geolocator`'s
  /// haversine helper so the explore page doesn't import the package
  /// directly for a single math call.
  double distanceMeters({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    return Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng);
  }
}

final locationServiceProvider = Provider<LocationService>((_) {
  return const LocationService();
});
