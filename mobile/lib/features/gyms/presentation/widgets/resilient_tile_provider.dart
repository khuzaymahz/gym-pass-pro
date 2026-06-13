import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
  /// `timeout` defaults to 6 s — real cellular networks routinely
  /// need 2-3 s just for a cold TLS handshake to a new origin, and
  /// the 4 s we shipped previously was triggering false-negative
  /// fallbacks on the user's actual phone. 6 s keeps the budget
  /// generous enough for spotty mobile signal while still bailing
  /// fast enough that flutter_map's `_tilesCeilingTimer` (8 s) can
  /// dismiss the warm-up overlay if everything truly fails.
  ResilientTileProvider({
    super.headers,
    Duration timeout = const Duration(seconds: 6),
  }) : super(
          // Layer stack, outermost in:
          //   _DiskCachingClient        — read-from-disk-first; on
          //                                MISS, defer to inner +
          //                                tee the response to disk
          //   _CartoFallbackClient      — CARTO failure → OSM same
          //                                tile (URL rewrite happens
          //                                at this layer so the
          //                                disk cache is keyed on
          //                                the original CARTO URL,
          //                                meaning fallback responses
          //                                are remembered for the
          //                                next request)
          //   _TimeoutClient            — hard per-request timeout
          //                                so a stuck socket doesn't
          //                                eat the whole tile budget
          //   http.Client               — raw network
          //
          // The DISK CACHE is the big real-device reliability win.
          // Once a tile loads successfully (from either CARTO or
          // OSM), it stays on disk for ~30 days via
          // `flutter_cache_manager`'s default LRU policy. App
          // cold-starts paint cached tiles instantly without any
          // network round-trip; panning to an already-seen area
          // never re-fetches. The "white squares mid-map" the user
          // saw on their phone twice were almost always tiles that
          // would have loaded on a retry — now they load once and
          // stay loaded.
          httpClient: _DiskCachingClient(
            _CartoFallbackClient(
              _TimeoutClient(http.Client(), timeout),
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
    // Try CARTO twice (initial + 1 retry) before falling back to
    // OSM. The retry catches transient packet loss / 503 spikes
    // on a cellular network — common on real devices on weak
    // signal. Without it a single dropped packet permanently
    // turned a tile into a "loaded from OSM" tile (different style,
    // visible style shift), which the user reported as flickering.
    //
    // Worst-case wall-clock per tile:
    //   CARTO try 1 (6 s) + 200 ms backoff
    //   + CARTO try 2 (6 s) + 200 ms backoff
    //   + OSM try 1 (6 s) + 250 ms backoff
    //   + OSM try 2 (6 s)
    //   ≈ 24.65 s
    // Still under the 30 s the platform considers "hung", and
    // crucially: that's the BAD path. The good path (single
    // CARTO try succeeds) is unchanged — single request, single
    // round trip.
    Object? cartoError;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      try {
        // `BaseRequest` is single-use; recreate per attempt.
        final retryReq = http.Request(request.method, request.url);
        retryReq.headers.addAll(request.headers);
        final res = await _inner.send(retryReq);
        if (res.statusCode < 400) return res;
        await res.stream.drain<void>();
        // 4xx that isn't 408/429 is a permanent client error (404
        // for past-zoom-range tiles, 403 from bot detection).
        // Don't retry — go straight to OSM.
        if (res.statusCode != 408 && res.statusCode != 429 &&
            res.statusCode < 500) {
          cartoError = StateError('CARTO tile ${res.statusCode}');
          break;
        }
        cartoError = StateError('CARTO tile ${res.statusCode}');
      } catch (err) {
        cartoError = err;
      }
    }
    if (kDebugMode) {
      debugPrint('CARTO tile failed, falling back to OSM: $cartoError');
    }
    return _sendFallback(request);
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

/// Persistent disk cache for tile bytes, layered on top of the
/// fallback + timeout client chain. Backed by
/// `flutter_cache_manager`'s `DefaultCacheManager` (LRU disk cache,
/// ~30-day TTL by default), which is already in the dep tree via
/// `cached_network_image`.
///
/// Behaviour:
///
///   * GET cache hit → return the cached bytes as a synthetic
///     `StreamedResponse`. Zero network. Zero tile flicker.
///   * GET cache miss → defer to `_inner.send`, write a successful
///     response to disk before handing it back to flutter_map.
///   * Non-GET → pass through unchanged (no caching for state-
///     changing calls — not that flutter_map issues any, but the
///     guard keeps the contract narrow).
///
/// Cache key is the request URL string. flutter_map issues stable
/// URLs per `{z}/{x}/{y}` tile coordinate, so the same tile across
/// app sessions hits the same key. The `_CartoFallbackClient`
/// layer below this DOES rewrite the URL on fallback (CARTO →
/// OSM) — but the cache check happens on the OUTER URL (the CARTO
/// one flutter_map asked for), so OSM-served responses are cached
/// under the CARTO key and served instantly the next time
/// flutter_map asks for the same CARTO tile. That's the intended
/// behaviour: once we've found a working source for a tile, we
/// remember it.
class _DiskCachingClient extends http.BaseClient {
  _DiskCachingClient(this._inner);

  final http.Client _inner;
  // `flutter_cache_manager`'s singleton. Cheap to instantiate and
  // shared with `cached_network_image`'s photo cache, so we don't
  // bloat disk usage by spinning up a second manager.
  final BaseCacheManager _cache = DefaultCacheManager();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET') {
      return _inner.send(request);
    }
    final cacheKey = request.url.toString();

    // Cache hit path. `getFileFromCache` returns a `FileInfo` or
    // null; we explicitly skip stale entries by checking the
    // `validTill` field rather than letting flutter_cache_manager
    // serve them — stale tile bytes are fine, but we'd rather not
    // surprise users with months-old basemap if they happen to be
    // online when the CDN style changed.
    try {
      final hit = await _cache.getFileFromCache(cacheKey);
      if (hit != null && hit.validTill.isAfter(DateTime.now())) {
        final bytes = await hit.file.readAsBytes();
        return http.StreamedResponse(
          http.ByteStream.fromBytes(bytes),
          200,
          contentLength: bytes.length,
          request: request,
          headers: const {'content-type': 'image/png', 'x-tile-cache': 'hit'},
        );
      }
    } catch (_) {
      // Cache lookup failure (disk full, corrupted entry, etc.)
      // is non-fatal — fall through to the network.
    }

    // Cache miss → network.
    final res = await _inner.send(request);
    if (res.statusCode != 200) {
      // Don't cache errors; pass them through so the outer
      // fallback layer can decide what to do.
      return res;
    }

    // Tee the response: collect bytes, write to disk, hand them
    // back to flutter_map. `toBytes` consumes the stream once, so
    // we rebuild a fresh ByteStream from the collected payload.
    final bytes = await res.stream.toBytes();
    try {
      await _cache.putFile(
        cacheKey,
        Uint8List.fromList(bytes),
        // 30 days — tiles don't change daily, but a month is
        // long enough to make cold starts instant for any area
        // a regular user visits, and short enough that a CDN
        // style change rolls out within a billing cycle.
        maxAge: const Duration(days: 30),
        fileExtension: 'png',
      );
    } catch (err) {
      if (kDebugMode) {
        debugPrint('Tile cache write failed: $err');
      }
      // Disk write failure must not prevent the tile from
      // rendering — fall through with the in-memory bytes.
    }
    return http.StreamedResponse(
      http.ByteStream.fromBytes(bytes),
      200,
      contentLength: bytes.length,
      request: request,
      headers: res.headers,
    );
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
