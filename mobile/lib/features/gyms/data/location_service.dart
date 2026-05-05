import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Result of a one-shot "where is the user?" query.
///
/// Three terminal states:
///   - `granted` + `position`: GPS came back, the map can centre on it.
///   - `denied`: user explicitly refused (or has the permission set
///     to "denied forever" at the OS level). The map falls back to
///     its default centre and never re-prompts during the session.
///   - `serviceDisabled`: location services are off at the device
///     level (airplane mode, no GPS hardware, etc.). Same fallback.
class LocationResult {
  const LocationResult({required this.status, this.position});

  final LocationStatus status;
  final Position? position;

  bool get hasPosition => status == LocationStatus.granted && position != null;
}

enum LocationStatus { granted, denied, serviceDisabled }

/// Thin wrapper over `geolocator` so the page doesn't have to know
/// about the permission state machine. Keeps two behaviours in one
/// place:
///
///   1. Permission first — never call `getCurrentPosition` blind, the
///      iOS prompt won't appear unless we call `requestPermission`.
///   2. Bounded wait — `getCurrentPosition` can hang on devices with
///      a slow GPS lock (especially indoors). A 6-second cap lets the
///      page move on with the fallback centre rather than leaving the
///      member staring at "Locating…" forever.
class LocationService {
  const LocationService();

  Future<LocationResult> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(status: LocationStatus.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const LocationResult(status: LocationStatus.denied);
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      return LocationResult(
        status: LocationStatus.granted,
        position: pos,
      );
    } catch (_) {
      // Timeout, hardware error, position-unavailable — treat as
      // denied for routing purposes. The page falls back to the
      // default centre and the member can pinch around as usual.
      return const LocationResult(status: LocationStatus.denied);
    }
  }

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
