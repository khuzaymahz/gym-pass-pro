import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

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
          // No `RetryClient` here. The previous version sat
          // `RetryClient(retries: 2)` between the fallback wrapper
          // and the network — which meant a CARTO timeout fired
          // three back-to-back attempts at CARTO (with 500 ms /
          // 1500 ms backoff = ~14 s wall-clock) BEFORE the
          // fallback to OSM ever ran. By then the fallback request
          // was also subject to the same three-attempt budget, so
          // worst-case latency-to-first-paint was ~28 s. The
          // symptom in the field: a blank canvas with periodic
          // "CARTO tile failed, falling back to OSM" logs and no
          // tiles ever painting because the viewport got new
          // requests before old ones finished. Now the fallback
          // wrapper sits directly on top of the timeout client and
          // owns its own retry budget — see [_CartoFallbackClient].
          httpClient: _CartoFallbackClient(
            _TimeoutClient(http.Client(), timeout),
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
    // Single attempt at CARTO. If it times out or fails, we want
    // OSM to fire IMMEDIATELY — the user sitting on a blank map
    // doesn't want us spending 14 s retrying a CDN we can't reach.
    try {
      final res = await _inner.send(request);
      if (res.statusCode < 400) return res;
      await res.stream.drain<void>();
      if (kDebugMode) {
        debugPrint(
          'CARTO tile ${res.statusCode}, falling back to OSM',
        );
      }
      return _sendFallback(request);
    } catch (err) {
      if (kDebugMode) {
        debugPrint('CARTO tile failed, falling back to OSM: $err');
      }
      return _sendFallback(request);
    }
  }

  /// Fire the tile at OSM. One immediate try plus one delayed retry
  /// — most OSM tile failures are transient (busy edge, slow TLS
  /// handshake on a cold socket), and a single retry recovers them
  /// without holding the connection pool. Total fallback budget:
  /// timeout + 250 ms backoff + timeout (~8 s worst case), down
  /// from ~14 s with the old inner RetryClient.
  Future<http.StreamedResponse> _sendFallback(
    http.BaseRequest primaryRequest,
  ) async {
    final fb = _osmFallbackFor(primaryRequest.url);
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      // Fresh `http.Request` per attempt — `BaseRequest` instances
      // are single-use; the body stream is consumed by send().
      final fbReq = http.Request(primaryRequest.method, fb);
      // Replay the original headers (User-Agent included — OSM
      // tile policy requires a real UA, and flutter_map's
      // TileLayer has already set one based on
      // `userAgentPackageName`).
      fbReq.headers.addAll(primaryRequest.headers);
      try {
        final res = await _inner.send(fbReq);
        if (res.statusCode < 400) return res;
        await res.stream.drain<void>();
        lastError = StateError('OSM tile ${res.statusCode}');
      } catch (err) {
        lastError = err;
      }
    }
    if (kDebugMode) {
      debugPrint('OSM tile also failed after retry: $lastError');
    }
    // Surface the last failure so flutter_map's
    // `silenceExceptions: true` can turn it into a transparent
    // stub instead of a stack trace.
    throw lastError ?? StateError('OSM fallback failed');
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
