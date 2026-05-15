import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../data/jordan_border.dart';
import 'resilient_tile_provider.dart';

/// Renders a labels-only tile layer clipped to Jordan's outline so
/// place names ONLY appear inside the country. The base layer (no-
/// labels) handles foreign terrain; this layer adds back the
/// Amman/Aqaba/Irbid/road-name labels for Jordan tiles only.
///
/// Implementation: a `ClipPath` around the labels TileLayer, with a
/// custom clipper that converts the (lat, lng) Jordan polygon to a
/// `Path` in screen coordinates using the live `MapCamera`. The
/// clipper re-runs on every camera change (pan, zoom) so the label
/// region tracks the country's screen footprint exactly — no jank,
/// no stale clip path.
///
/// Why this beats the previous polygon-mask approach: the mask had
/// to cover everything outside Jordan with a solid colour, which
/// meant foreign terrain disappeared too. With the clip, foreign
/// terrain renders normally from the base no-labels tile; only the
/// labels overlay is gated.
class JordanLabelsLayer extends StatelessWidget {
  const JordanLabelsLayer({super.key, required this.tileUrl});

  final String tileUrl;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return ClipPath(
      clipper: _JordanPathClipper(camera),
      child: TileLayer(
        urlTemplate: tileUrl,
        subdomains: const ['a', 'b', 'c', 'd'],
        retinaMode: false,
        userAgentPackageName: 'net.gympass.gympass',
        // Same resilient provider as the base layer — short timeout,
        // zero retries, silent failures. The labels overlay is a
        // nice-to-have on top of the base tiles, so when CARTO is
        // unreachable it just renders blank instead of cascading
        // into the same ANR pattern as the base layer used to.
        tileProvider: ResilientTileProvider(),
        keepBuffer: 1,
        panBuffer: 0,
      ),
    );
  }
}

/// Custom clipper that turns the Jordan polygon (lat/lng list) into
/// a closed Path in pixel coordinates using the current camera.
class _JordanPathClipper extends CustomClipper<ui.Path> {
  const _JordanPathClipper(this.camera);

  final MapCamera camera;

  @override
  ui.Path getClip(Size size) {
    final path = ui.Path();
    for (var i = 0; i < jordanPolygon.length; i++) {
      final p = camera.latLngToScreenPoint(jordanPolygon[i]);
      if (i == 0) {
        path.moveTo(p.x, p.y);
      } else {
        path.lineTo(p.x, p.y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _JordanPathClipper old) =>
      old.camera != camera;
}
