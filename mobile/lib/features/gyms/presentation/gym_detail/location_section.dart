import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/static_map_url.dart';
import 'gym_detail_helpers.dart';

/// Location block: a tappable static-map preview, the street address,
/// and a "Get directions" button that hands off to the OS maps app.
/// The preview image is only rendered when a Maps Static key is
/// configured; without one we still show the address + directions
/// button (the directions deep-link needs no key).
class LocationSection extends StatelessWidget {
  const LocationSection({
    super.key,
    required this.lat,
    required this.lng,
    required this.address,
    required this.areaFallback,
    required this.label,
    required this.mapsKey,
    required this.isAr,
  });

  final double lat;
  final double lng;
  final String address;
  final String areaFallback;
  final String label;
  final String mapsKey;
  final bool isAr;

  /// Hand off to the OS maps app with a directions request. The
  /// `dir/?api=1&destination=` form is the documented cross-platform
  /// Google Maps URL — it resolves to the native app on Android/iOS
  /// and the web client otherwise. Failures are swallowed: a member
  /// without any maps handler simply sees nothing happen, which beats
  /// crashing the page.
  Future<void> _openDirections() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No maps handler — nothing actionable to show the member.
    }
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    final shownAddress = address.isNotEmpty ? address : areaFallback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(gp, l.gymLocationTitle),
        const SizedBox(height: 10),
        if (mapsKey.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(GPRadius.md),
            child: InkWell(
              onTap: _openDirections,
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final url = StaticMapUrl.build(
                      centre: (lat: lat, lng: lng),
                      zoom: 15,
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                      markers: [
                        // Brand-amber pin. The hex is a Static Maps API
                        // wire value, not a UI fill — it can't read the
                        // theme token, so it mirrors GP.lime by hand.
                        StaticMapMarker(
                          lat: lat,
                          lng: lng,
                          colorHex: 'eab308',
                        ),
                      ],
                      apiKey: mapsKey,
                      language: isAr ? 'ar' : 'en',
                    );
                    return CachedNetworkImage(
                      imageUrl: url.toString(),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: gp.bg2),
                      errorWidget: (_, __, ___) => Container(
                        color: gp.bg2,
                        alignment: Alignment.center,
                        child: Icon(Icons.map_outlined, color: gp.muted),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        if (mapsKey.isNotEmpty) const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.place_outlined, size: 18, color: gp.accentInk),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                shownAddress,
                style: GPText.body(size: 13, color: gp.fg, height: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Outline directions button — secondary weight so it doesn't
        // compete with the primary check-in / day-pass CTA below.
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(GPRadius.pill),
            onTap: _openDirections,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GPRadius.pill),
                border: Border.all(color: gp.line2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_outlined,
                    size: 18,
                    color: gp.accentInk,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.gymGetDirections,
                    style: GPText.body(
                      size: 14,
                      color: gp.fg,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
