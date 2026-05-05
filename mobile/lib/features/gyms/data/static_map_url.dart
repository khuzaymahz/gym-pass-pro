import 'dart:ui' show Size;

/// Builds Google Static Maps API URLs.
///
/// We use the Static Maps endpoint (HTTPS image GET) instead of the
/// interactive Maps SDK because the explore flow only needs to *show*
/// where gyms are, not let the member pan/zoom around them. A static
/// PNG loads in a single round-trip, has no platform-view overhead,
/// costs ~7× less per load on the Maps Platform bill, and lets the
/// rest of the page be a normal Flutter scroll view.
///
/// Reference: https://developers.google.com/maps/documentation/maps-static
class StaticMapUrl {
  const StaticMapUrl._();

  /// Maximum size the Static Maps API will render in a single call.
  /// Anything larger needs a paid premium plan; for our preview
  /// strip 640×400 at scale=2 (1280×800 effective) is plenty.
  static const _maxDimension = 640;

  /// Build the URL for a static map preview.
  ///
  /// [centre] — `(lat, lng)` the camera centres on.
  /// [zoom] — Google zoom level (0 world, 21 building). 11–13 is good
  /// for a city overview, 15–16 for a neighbourhood, 17+ for a single
  /// gym pin.
  /// [size] — pixel size in logical pixels of the rendered image. Caller
  /// should pass `Size(constraints.maxWidth, constraints.maxHeight)`
  /// from a `LayoutBuilder` so the static image matches the slot. The
  /// helper clamps to the API's 640px limit.
  /// [devicePixelRatio] — typically `MediaQuery.devicePixelRatioOf(ctx)`.
  /// Sent as `scale=` so the image is crisp on retina screens.
  /// [markers] — gym pins. Each carries lat/lng + a pin colour. The
  /// helper groups markers by colour so the URL only repeats the
  /// `markers=color:...` prefix once per colour group (the API's wire
  /// format), keeping URLs short enough to stay under the ~8 KB limit.
  /// [apiKey] — Google Cloud project key with the Static Maps API
  /// enabled. Pass via `--dart-define=GOOGLE_MAPS_KEY=...` at build
  /// time; never hardcode.
  /// [mapType] — defaults to `roadmap`; no styling JSON support on
  /// Static Maps so this is the closest we get.
  /// [language] — `en` or `ar`. Drives map labels.
  static Uri build({
    required ({double lat, double lng}) centre,
    required int zoom,
    required Size size,
    required double devicePixelRatio,
    required List<StaticMapMarker> markers,
    required String apiKey,
    String mapType = 'roadmap',
    String language = 'en',
  }) {
    // scale=2 doubles the rendered resolution. The Static Maps API
    // accepts 1, 2 (and 4 for premium); we cap at 2 since that's the
    // free tier and matches every modern phone's pixel density.
    final scale = devicePixelRatio >= 1.5 ? 2 : 1;
    final width = size.width.round().clamp(1, _maxDimension);
    final height = size.height.round().clamp(1, _maxDimension);

    final params = <String, String>{
      'center': '${centre.lat.toStringAsFixed(6)},${centre.lng.toStringAsFixed(6)}',
      'zoom': zoom.toString(),
      'size': '${width}x$height',
      'scale': scale.toString(),
      'maptype': mapType,
      'language': language,
      'key': apiKey,
    };

    // Markers are repeated query params, not a single key=value, so
    // we build the query string by hand. `Uri.replace(queryParameters:)`
    // would collapse duplicates onto a single key.
    final query = StringBuffer();
    void appendParam(String key, String value) {
      if (query.isNotEmpty) query.write('&');
      query
        ..write(Uri.encodeQueryComponent(key))
        ..write('=')
        ..write(Uri.encodeQueryComponent(value));
    }

    params.forEach(appendParam);

    // Group markers by colour so each colour is one `markers=` entry
    // with all coords pipe-separated — keeps the URL short.
    final byColour = <String, List<StaticMapMarker>>{};
    for (final m in markers) {
      byColour.putIfAbsent(m.colorSpec, () => []).add(m);
    }
    byColour.forEach((colorSpec, group) {
      final coords = group
          .map((m) => '${m.lat.toStringAsFixed(6)},${m.lng.toStringAsFixed(6)}')
          .join('|');
      appendParam('markers', '$colorSpec|$coords');
    });

    return Uri.parse('https://maps.googleapis.com/maps/api/staticmap?$query');
  }
}

/// One pin on a static map. The Static Maps API supports a small
/// fixed palette plus `0xRRGGBB` hex; we pass the hex through as-is
/// since our brand colours don't match the named set.
class StaticMapMarker {
  const StaticMapMarker({
    required this.lat,
    required this.lng,
    required this.colorHex,
    this.size = 'small',
    this.label,
  });

  final double lat;
  final double lng;

  /// 6-digit hex without a leading `#`, e.g. `c8ff00`. Use the gym's
  /// tier colour so the preview map is glanceable.
  final String colorHex;

  /// `tiny`, `mid`, `small`, or `normal`. Smaller markers fit more
  /// pins in a city-scale preview without overlapping.
  final String size;

  /// Single uppercase A–Z or 0–9. Only renders on `mid` and larger.
  final String? label;

  /// Wire format for the `markers=` prefix: `color:0xRRGGBB|size:small`
  /// (and optional `label:X`). All markers sharing this prefix can be
  /// concatenated with `|lat,lng|lat,lng` after it.
  String get colorSpec {
    final parts = <String>['color:0x$colorHex', 'size:$size'];
    if (label != null) parts.add('label:$label');
    return parts.join('|');
  }
}
