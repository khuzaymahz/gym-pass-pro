import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

/// Network-tile provider that recovers from transient tile-fetch
/// failures without re-introducing the ANR risk of flutter_map's
/// default retry policy.
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
/// This provider tightens both knobs:
///
///   * **`retries: 2`** — every tile gets up to three total attempts
///     (one initial + two retries). One retry recovers from a
///     transient 429 / packet loss (the "white square" hole in an
///     otherwise rendered map); the second covers a flaky CDN edge
///     that occasionally serves a 5xx then 200. The default
///     exponential delay (500ms → 1500ms) keeps the worst-case
///     wall-clock per tile to ~10 s — well under the platform ANR
///     threshold of 5 s of *main-thread* blocking, since these
///     fetches run off-thread.
///   * **Per-request timeout (default 4 s)** — wraps the underlying
///     `http.Client.send` so a stuck connection doesn't hold a
///     socket open until dart:io's idle timeout fires. Without this
///     a single hung tile would dominate the retry budget.
///   * **`silenceExceptions: true`** — failed tiles render as a
///     transparent stub instead of dumping a stack trace per tile
///     into the log. The map's existing `_tilesCeilingTimer` still
///     dismisses the warm-up overlay after 8 s when no tile ever
///     paints, so the member sees the (mostly) blank map and
///     understands they are offline rather than sitting on a
///     spinner forever.
///
/// Originally shipped with `retries: 0` to escape the ANR; that
/// turned out to be too pessimistic — a single transient failure
/// permanently held a "white hole" in the middle of an otherwise
/// rendered map until the user panned. Two retries is the right
/// middle ground.
class ResilientTileProvider extends NetworkTileProvider {
  ResilientTileProvider({
    super.headers,
    Duration timeout = const Duration(seconds: 4),
  }) : super(
          httpClient: RetryClient(
            _TimeoutClient(http.Client(), timeout),
            retries: 2,
            // Retry only on transient errors / network exceptions —
            // never on a 404 (the tile genuinely doesn't exist; CARTO
            // returns 404 for tiles past the zoom range) or 4xx in
            // general (client error, retrying won't help).
            when: (response) =>
                response.statusCode == 408 ||
                response.statusCode == 429 ||
                response.statusCode >= 500,
            whenError: (_, __) => true,
          ),
          silenceExceptions: true,
        );
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
