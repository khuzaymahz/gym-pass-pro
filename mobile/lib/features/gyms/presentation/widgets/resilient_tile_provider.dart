import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

/// Network-tile provider that fails fast and silently when the
/// basemap CDN is unreachable.
///
/// flutter_map's default `NetworkTileProvider` wraps a `RetryClient`
/// that retries each failed request three times with exponential
/// backoff, and uses dart:io's `HttpClient` which has no per-request
/// connection timeout. On a network where CARTO is blocked /
/// unreachable, this means every visible tile (~100 in a typical
/// viewport) holds open a socket for ~30 s before failing, three
/// times — overwhelming the connection pool, blocking the image
/// pipeline, and triggering an ANR ("GymPass isn't responding") with
/// no useful map ever painted.
///
/// This provider keeps the same interface but tightens both knobs:
///
///   * `retries: 0` — every tile fetch attempts the network once. If
///     the CDN is reachable, the tile loads on the first try. If
///     it's not, the request fails immediately and the layer renders
///     blank rather than thrashing.
///   * Per-request timeout (default 4 s) — wraps the underlying
///     `http.Client.send` so a stuck connection doesn't hold a
///     socket open until dart:io's idle timeout fires.
///   * `silenceExceptions: true` — failed tiles render as a
///     transparent stub instead of dumping a stack trace per tile
///     into the log. The map's existing `_tilesCeilingTimer` still
///     dismisses the warm-up overlay after 8 s when no tile ever
///     paints, so the member sees the blank map and understands they
///     are offline rather than sitting on a spinner forever.
///
/// The trade-off vs the default: a single transient packet loss can
/// leave a tile blank instead of being retried. In practice the user
/// either pans (re-requesting the tile) or the map is just temporarily
/// patchy — both far less painful than an ANR.
class ResilientTileProvider extends NetworkTileProvider {
  ResilientTileProvider({
    super.headers,
    Duration timeout = const Duration(seconds: 4),
  }) : super(
          httpClient: RetryClient(
            _TimeoutClient(http.Client(), timeout),
            retries: 0,
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
