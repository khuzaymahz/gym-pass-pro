import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/di/providers.dart';

/// A latitude/longitude pair, persisted across app launches as the
/// member's "home base" — the location their map should default to
/// when the GPS isn't responding (denied permission, indoors, no
/// signal, etc.). Captured the first time GPS resolves to a real
/// position; survives reboots so a returning member sees Amman /
/// Zarqa / Irbid / wherever they were last placed, not the Amman
/// fallback.
class HomeLocation {
  const HomeLocation({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

/// Tiny secure-storage adapter for [HomeLocation]. Two keys, one
/// each for lat and lng — kept simple because the read/write path
/// runs once per session at most.
class HomeRegionStore {
  HomeRegionStore(this._storage);

  static const _kLat = 'home_lat';
  static const _kLng = 'home_lng';

  final FlutterSecureStorage _storage;

  Future<HomeLocation?> read() async {
    final lat = await _storage.read(key: _kLat);
    final lng = await _storage.read(key: _kLng);
    if (lat == null || lng == null) return null;
    final parsedLat = double.tryParse(lat);
    final parsedLng = double.tryParse(lng);
    if (parsedLat == null || parsedLng == null) return null;
    return HomeLocation(lat: parsedLat, lng: parsedLng);
  }

  Future<void> write(double lat, double lng) async {
    await _storage.write(key: _kLat, value: lat.toString());
    await _storage.write(key: _kLng, value: lng.toString());
  }

  Future<void> clear() async {
    await _storage.delete(key: _kLat);
    await _storage.delete(key: _kLng);
  }
}

final homeRegionStoreProvider = Provider<HomeRegionStore>((ref) {
  return HomeRegionStore(ref.read(secureStorageProvider));
});

/// Live (or last-known) GPS for the member, exposed app-wide so any
/// widget — gym detail, gym row, plans page, etc. — can compute a
/// real distance to a gym without re-asking the OS for permission.
///
/// Owner: [ExplorePage] writes here on every successful position
/// resolve (both from the persisted store and from a fresh GPS read).
/// Null when permission was never granted or no stored value exists;
/// consumers should fall back to "—" rather than 0 km, since 0 means
/// "you're literally at the gym."
final userPositionProvider = StateProvider<HomeLocation?>((_) => null);
