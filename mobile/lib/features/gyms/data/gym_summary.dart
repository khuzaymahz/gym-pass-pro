class GymSummary {
  final String id;
  final String slug;
  final String nameEn;
  final String nameAr;
  final String? logoUrl;
  final String? category;
  final String? tier;
  final String? area;

  /// Lat/lng come from the backend as `Numeric(9,6)` strings — kept as
  /// `double` here because the only consumer (the Explore map) needs
  /// `LatLng(double, double)`. Null when the backend record is missing
  /// coordinates; the map filters those rows out before plotting.
  final double? lat;
  final double? lng;

  /// Amenity slugs the partner ticked in the gym-partner profile
  /// editor (`wifi`, `parking`, `showers`, `lockers`, `pool`,
  /// `sauna`, …). Same slug vocabulary the partner portal's
  /// `AmenitiesPicker` writes; mobile maps each slug to an icon +
  /// localized label in `gym_detail_page._amenityGrid`. Empty for
  /// gyms that haven't filled the field yet — the detail page
  /// hides the amenities row in that case.
  final List<String> amenities;

  const GymSummary({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.nameAr,
    this.logoUrl,
    this.category,
    this.tier,
    this.area,
    this.lat,
    this.lng,
    this.amenities = const <String>[],
  });

  factory GymSummary.fromJson(Map<String, dynamic> json) {
    return GymSummary(
      id: json['id'] as String,
      slug: json['slug'] as String,
      nameEn: (json['nameEn'] ?? json['name_en'] ?? '') as String,
      nameAr: (json['nameAr'] ?? json['name_ar'] ?? '') as String,
      logoUrl: (json['logoUrl'] ?? json['logo_url']) as String?,
      category: json['category'] as String?,
      tier: (json['requiredTier'] ?? json['required_tier']) as String?,
      area: json['area'] as String?,
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      amenities: _toStringList(json['amenities']),
    );
  }
}

List<String> _toStringList(dynamic raw) {
  if (raw is List) {
    return raw.whereType<String>().toList(growable: false);
  }
  return const <String>[];
}

/// Pydantic `Decimal` serialises to JSON as a string by default; older
/// JSON encoders coerce to number. Accept both so the mobile doesn't
/// fail on a backend serializer change.
double? _toDouble(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}
