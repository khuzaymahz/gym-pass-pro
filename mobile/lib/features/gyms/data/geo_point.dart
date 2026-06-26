/// A plain latitude/longitude pair used by the explore map to track the
/// member's resolved position independently of any map-SDK type. Lives in
/// the data layer so the page widget doesn't own a model definition.
class GeoPoint {
  const GeoPoint({required this.lat, required this.lng});
  final double lat;
  final double lng;
}
