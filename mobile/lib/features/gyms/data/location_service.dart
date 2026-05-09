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
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(status: LocationStatus.deniedForever);
    }
    if (permission == LocationPermission.denied) {
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
      // Timeout, hardware error, position-unavailable — distinct
      // from "denied" so the UI can offer a "try again" message
      // rather than asking the member to re-grant permission they
      // already gave.
      return const LocationResult(status: LocationStatus.unavailable);
    }
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
