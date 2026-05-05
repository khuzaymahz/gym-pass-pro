/// Plain `(lat, lng)` pair. Defined locally so this file no longer
/// drags in `package:google_maps_flutter` — the explore flow renders
/// a static-map PNG and doesn't need the interactive SDK's types.
class GeoLatLng {
  const GeoLatLng(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Axis-aligned lat/lng box, southwest + northeast corners. Used to
/// pick a Static Maps zoom level that frames the populated area of a
/// region without panning hardware.
class GeoBounds {
  const GeoBounds({required this.southwest, required this.northeast});
  final GeoLatLng southwest;
  final GeoLatLng northeast;

  double get latSpan => (northeast.lat - southwest.lat).abs();
  double get lngSpan => (northeast.lng - southwest.lng).abs();
}

/// One of Jordan's governorates / metropolitan areas, used to frame
/// the explore static-map preview at "your region" rather than "your
/// exact street".
///
/// Bounds are deliberately loose — they don't need to align with the
/// administrative line on the ground, they just need to *frame the
/// city* a member would say they're from.
class JordanRegion {
  const JordanRegion({
    required this.key,
    required this.nameEn,
    required this.nameAr,
    required this.centre,
    required this.bounds,
    required this.staticMapZoom,
  });

  final String key;
  final String nameEn;
  final String nameAr;
  final GeoLatLng centre;
  final GeoBounds bounds;

  /// Google Static Maps zoom level that frames `bounds` at roughly the
  /// preview-strip aspect ratio (~16:9, ~360×200 logical px). Picked
  /// per region so a small town like Madaba isn't washed out at the
  /// same zoom as Greater Amman.
  final int staticMapZoom;
}

/// All the regions we'll resolve a member to. Listed in rough order
/// of population — not load-bearing, but if two regions are equally
/// distant from a point we'd rather pick the bigger one (more gyms
/// likely there).
const List<JordanRegion> jordanRegions = [
  JordanRegion(
    key: 'amman',
    nameEn: 'Amman',
    nameAr: 'عمّان',
    centre: GeoLatLng(31.96, 35.92),
    bounds: GeoBounds(
      southwest: GeoLatLng(31.88, 35.81),
      northeast: GeoLatLng(32.04, 36.03),
    ),
    staticMapZoom: 12,
  ),
  JordanRegion(
    key: 'zarqa',
    nameEn: 'Zarqa',
    nameAr: 'الزرقاء',
    centre: GeoLatLng(32.07, 36.09),
    bounds: GeoBounds(
      southwest: GeoLatLng(32.00, 36.02),
      northeast: GeoLatLng(32.14, 36.18),
    ),
    staticMapZoom: 12,
  ),
  JordanRegion(
    key: 'irbid',
    nameEn: 'Irbid',
    nameAr: 'إربد',
    centre: GeoLatLng(32.55, 35.85),
    bounds: GeoBounds(
      southwest: GeoLatLng(32.46, 35.78),
      northeast: GeoLatLng(32.62, 35.95),
    ),
    staticMapZoom: 12,
  ),
  JordanRegion(
    key: 'mafraq',
    nameEn: 'Mafraq',
    nameAr: 'المفرق',
    centre: GeoLatLng(32.34, 36.21),
    bounds: GeoBounds(
      southwest: GeoLatLng(32.30, 36.16),
      northeast: GeoLatLng(32.40, 36.26),
    ),
    staticMapZoom: 13,
  ),
  JordanRegion(
    key: 'balqa',
    nameEn: 'Balqa',
    nameAr: 'البلقاء',
    centre: GeoLatLng(32.04, 35.73),
    bounds: GeoBounds(
      southwest: GeoLatLng(31.96, 35.66),
      northeast: GeoLatLng(32.10, 35.80),
    ),
    staticMapZoom: 12,
  ),
  JordanRegion(
    key: 'madaba',
    nameEn: 'Madaba',
    nameAr: 'مادبا',
    centre: GeoLatLng(31.72, 35.79),
    bounds: GeoBounds(
      southwest: GeoLatLng(31.68, 35.74),
      northeast: GeoLatLng(31.78, 35.85),
    ),
    staticMapZoom: 13,
  ),
  JordanRegion(
    key: 'ajloun',
    nameEn: 'Ajloun',
    nameAr: 'عجلون',
    centre: GeoLatLng(32.33, 35.75),
    bounds: GeoBounds(
      southwest: GeoLatLng(32.29, 35.71),
      northeast: GeoLatLng(32.38, 35.80),
    ),
    staticMapZoom: 13,
  ),
  JordanRegion(
    key: 'jerash',
    nameEn: 'Jerash',
    nameAr: 'جرش',
    centre: GeoLatLng(32.28, 35.90),
    bounds: GeoBounds(
      southwest: GeoLatLng(32.24, 35.85),
      northeast: GeoLatLng(32.32, 35.95),
    ),
    staticMapZoom: 13,
  ),
  JordanRegion(
    key: 'karak',
    nameEn: 'Karak',
    nameAr: 'الكرك',
    centre: GeoLatLng(31.18, 35.70),
    bounds: GeoBounds(
      southwest: GeoLatLng(31.14, 35.65),
      northeast: GeoLatLng(31.22, 35.75),
    ),
    staticMapZoom: 13,
  ),
  JordanRegion(
    key: 'tafileh',
    nameEn: 'Tafileh',
    nameAr: 'الطفيلة',
    centre: GeoLatLng(30.84, 35.60),
    bounds: GeoBounds(
      southwest: GeoLatLng(30.81, 35.57),
      northeast: GeoLatLng(30.88, 35.64),
    ),
    staticMapZoom: 14,
  ),
  JordanRegion(
    key: 'maan',
    nameEn: 'Maan',
    nameAr: 'معان',
    centre: GeoLatLng(30.20, 35.73),
    bounds: GeoBounds(
      southwest: GeoLatLng(30.16, 35.69),
      northeast: GeoLatLng(30.24, 35.78),
    ),
    staticMapZoom: 13,
  ),
  JordanRegion(
    key: 'aqaba',
    nameEn: 'Aqaba',
    nameAr: 'العقبة',
    centre: GeoLatLng(29.53, 35.00),
    bounds: GeoBounds(
      southwest: GeoLatLng(29.46, 34.96),
      northeast: GeoLatLng(29.62, 35.05),
    ),
    staticMapZoom: 13,
  ),
];

/// Pick the [JordanRegion] closest to [position] by squared-degree
/// distance. Cheap, fine for ~12 widely-separated centres in a small
/// country. Falls back to Amman if the list is somehow empty.
JordanRegion regionForPosition(double lat, double lng) {
  var best = jordanRegions.first;
  var bestDistSq = double.infinity;
  for (final r in jordanRegions) {
    final dLat = r.centre.lat - lat;
    final dLng = r.centre.lng - lng;
    final distSq = dLat * dLat + dLng * dLng;
    if (distSq < bestDistSq) {
      bestDistSq = distSq;
      best = r;
    }
  }
  return best;
}
