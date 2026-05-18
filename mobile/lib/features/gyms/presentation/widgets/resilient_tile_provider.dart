import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

/// Network-tile provider that recovers from transient tile-fetch
/// failures without re-introducing the ANR risk of flutter_map's
/// default retry policy, and that transparently falls back to
/// OpenStreetMap when CARTO is unreachable.
///
/// flutter_map's default `NetworkTileProvider` wraps a `RetryClient`
/// that retries each failed request three times with exponential
/// backoff, and uses dart:io's `HttpClient` which has no per-request
/// connection timeout. On a network where CARTO is blocked /
/// unreachable, every visible tile (~100 in a typical viewport)
/// would hold open a socket for ~30 s before failing, three times —
/// overwhelming the connection pool, blocking the image pipeline,
/// and triggering an ANR ("GymPass isn't responding").
///
/// This provider tightens four knobs:
///
///   * **`retries: 2`** — every tile gets up to three total attempts
///     against the primary URL (one initial + two retries). One retry
///     recovers from a transient 429 / packet loss (the "white square"
///     hole in an otherwise rendered map); the second covers a flaky
///     CDN edge that occasionally serves a 5xx then 200. The default
///     exponential delay (500ms → 1500ms) keeps the worst-case
///     wall-clock per tile to ~10 s — well under the platform ANR
///     threshold of 5 s of *main-thread* blocking, since these
///     fetches run off-thread.
///   * **Per-request timeout (default 4 s)** — wraps the underlying
///     `http.Client.send` so a stuck connection doesn't hold a
///     socket open until dart:io's idle timeout fires. Without this
///     a single hung tile would dominate the retry budget.
///   * **OSM fallback ([_CartoFallbackClient])** — after the primary
///     retry budget is exhausted (or the primary returns a 4xx the
///     RetryClient won't retry — e.g. 403 from CARTO bot detection),
///     the same `{z}/{x}/{y}.png` path is fetched from
///     `tile.openstreetmap.org`. The rewrite happens at the HTTP
///     layer so flutter_map still sees the original CARTO URL — its
///     `MapNetworkImageProvider` cache key is stable, and the
///     painting-binding image cache can dedupe re-paints of the same
///     tile coordinate. Using TileLayer.fallbackUrl instead would
///     have broken `MapNetworkImageProvider.operator==` (it explicitly
///     returns `false` whenever `fallbackUrl != null`), causing every
///     pan to re-fetch every visible tile.
///   * **`silenceExceptions: true`** — if BOTH primary AND fallback
///     fail (rare — implies the device has no working internet at
///     all), the failed tile renders as a transparent stub instead
///     of dumping a stack trace per tile into the log. The map's
///     existing `_tilesCeilingTimer` still dismisses the warm-up
///     overlay after 8 s when no tile ever paints, so the member
///     sees the (mostly) blank map and understands they are offline
///     rather than sitting on a spinner forever.
///
/// Originally shipped with `retries: 0` to escape the ANR; that
/// turned out to be too pessimistic — a single transient failure
/// permanently held a "white hole" in the middle of an otherwise
/// rendered map until the user panned. Then bumped to `retries: 2`
/// to plug the white-hole regression — but that still produced an
/// "empty canvas + pins" failure when CARTO was unreachable at the
/// network level. The HTTP-layer OSM fallback is what closes that
/// final gap: members see a real basemap (with embedded OSM labels)
/// even when CARTO is fully blocked.
class ResilientTileProvider extends NetworkTileProvider {
  ResilientTileProvider({
    super.headers,
    Duration timeout = const Duration(seconds: 4),
  }) : super(
          httpClient: _CartoFallbackClient(
            RetryClient(
              _TimeoutClient(http.Client(), timeout),
              retries: 2,
              // Retry only on transient errors / network exceptions —
              // never on a 404 (the tile genuinely doesn't exist; CARTO
              // returns 404 for tiles past the zoom range) or 4xx in
              // general (client error, retrying won't help). 403 from
              // CARTO bot-detection IS a client error — RetryClient
              // won't help, but `_CartoFallbackClient` (outer wrapper)
              // catches the 4xx and routes the next attempt to OSM.
              when: (response) =>
                  response.statusCode == 408 ||
                  response.statusCode == 429 ||
                  response.statusCode >= 500,
              whenError: (_, __) => true,
            ),
          ),
          silenceExceptions: true,
        );
}

/// `{z}/{x}/{y}.png` path extractor — used to rewrite CARTO basemap
/// tile URLs into OSM equivalents while preserving the tile's
/// coordinate identity. The regex anchors at the end of the URL path
/// so it matches CARTO's `/rastertiles/voyager_nolabels/{z}/{x}/{y}.png`
/// and `/dark_nolabels/{z}/{x}/{y}.png` paths identically.
final _zxyPathRe = RegExp(r'/(\d+)/(\d+)/(\d+)\.png$');

/// HTTP client wrapper that, on CARTO failure (response 4xx/5xx or
/// thrown exception), re-issues the same tile request against
/// `tile.openstreetmap.org`. Only fires for hosts ending in
/// `basemaps.cartocdn.com`, so non-CARTO requests pass through
/// unchanged. Skips the rewrite for `_only_labels` paths (OSM has
/// no labels-only variant — falling back would double-paint city
/// names on top of the OSM base layer's already-embedded labels).
class _CartoFallbackClient extends http.BaseClient {
  _CartoFallbackClient(this._inner);

  final http.Client _inner;

  bool _shouldFallback(Uri uri) {
    if (!uri.host.endsWith('basemaps.cartocdn.com')) return false;
    if (uri.path.contains('only_labels')) return false;
    return _zxyPathRe.hasMatch(uri.path);
  }

  Uri _osmFallbackFor(Uri primary) {
    final m = _zxyPathRe.firstMatch(primary.path)!;
    return Uri.parse(
      'https://tile.openstreetmap.org/${m.group(1)}/${m.group(2)}/${m.group(3)}.png',
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_shouldFallback(request.url)) {
      return _inner.send(request);
    }
    try {
      final res = await _inner.send(request);
      if (res.statusCode < 400) return res;
      // Primary returned 4xx/5xx after exhausting retries. Drain
      // the body so the socket is returned to the pool, then route
      // to OSM. (Streaming responses leak the connection if not
      // drained; even a 1-byte error body keeps the socket open
      // until GC, which we can't afford on a 16-tile viewport.)
      await res.stream.drain<void>();
      return _sendFallback(request);
    } catch (err, st) {
      if (kDebugMode) {
        debugPrint('CARTO tile failed, falling back to OSM: $err');
        debugPrintStack(stackTrace: st, maxFrames: 3);
      }
      return _sendFallback(request);
    }
  }

  Future<http.StreamedResponse> _sendFallback(
    http.BaseRequest primaryRequest,
  ) {
    final fb = _osmFallbackFor(primaryRequest.url);
    final fbReq = http.Request(primaryRequest.method, fb);
    // Replay the original headers (User-Agent included — OSM tile
    // policy requires a real UA, and flutter_map's TileLayer has
    // already set one based on `userAgentPackageName`).
    fbReq.headers.addAll(primaryRequest.headers);
    return _inner.send(fbReq);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Tiny `BaseClient` decorator that enforces a hard timeout on the
/// `send` future. dart:io's `HttpClient` doesn't expose a per-request
/// connection-establish timeout, so without this a tile fetch can
/// hang for ~30 s on a blocked CDN before the OS gives up.
class _TimeoutClient extends http.BaseClient {
  _TimeoutClient(this._inner, this._timeout);

  final http.Client _inner;
  final Duration _timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(
      _timeout,
      onTimeout: () => throw TimeoutException(
        'Tile fetch timed out',
        _timeout,
      ),
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
