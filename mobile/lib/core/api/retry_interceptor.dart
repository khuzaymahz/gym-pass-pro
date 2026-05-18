import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../network/network_error.dart';

/// Retries transient network failures on idempotent requests so a
/// single flaky packet doesn't surface as a hard error to the user.
///
/// Why this lives in its own interceptor (not folded into [ApiClient]):
///
///   * Auth-refresh and transient-retry are different concerns. Auth
///     refresh only fires for 401 + `AUTH_TOKEN_EXPIRED` and runs at
///     most once per request. Transient retry fires for 5xx / 408 /
///     429 / network drops and runs up to N times with backoff.
///     Splitting them keeps each readable.
///   * Dio interceptors compose by appending — placing this one
///     **before** the auth interceptor means a 5xx retry doesn't
///     interact with the refresh coalescing. (Order: this →
///     [_buildInterceptor] in api_client.dart.)
///
/// Policy:
///
///   * **Idempotent only.** Default: GET, HEAD, OPTIONS. Anything else
///     (POST/PUT/PATCH/DELETE) is retried **only** when the caller
///     opts in via `Options(extra: {'idempotent': true})`. POST is
///     usually not idempotent (creates a row, charges a card) so we
///     can't blanket-retry it without risking duplicate side effects.
///   * **Transient only.** SocketException / timeout / 408 / 429 / 5xx
///     are retried. 4xx (other than 408/429) is a client error —
///     retrying won't change the answer.
///   * **Capped at 2 retries** (so worst case = 3 total attempts).
///     With ~500 ms → 1500 ms backoff that's a wall-clock ceiling of
///     ~2 s of waiting on top of the original request, comfortably
///     under the 15 s connect timeout.
///   * **Skip refresh + login.** The auth interceptor handles refresh
///     itself; retrying a refresh call would compound failure modes.
///     Login (POST without `idempotent`) is excluded by default.
///   * **Skip when offline.** If the connectivity layer reports
///     `offline`, retrying immediately won't help — we fail fast
///     instead and let the caller surface the offline banner. Callers
///     that read from cache don't get here in the first place.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(milliseconds: 4000),
    Future<bool> Function()? isOnline,
  }) : _isOnline = isOnline ?? (() async => true);

  /// The Dio instance this interceptor is attached to. Retries reuse
  /// it (via `fetch`) so the retried request goes through the entire
  /// interceptor chain — auth headers, structured-error wrapping,
  /// future retry logic — exactly like a fresh request would. Without
  /// this we'd silently skip auth on every retry.
  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  final Future<bool> Function() _isOnline;

  static const _retryCountKey = '_retryCount';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }
    final attempts = (options.extra[_retryCountKey] as int?) ?? 0;
    if (attempts >= maxRetries) {
      return handler.next(err);
    }
    // Don't waste a retry slot when the OS already told us we're
    // offline — surface the failure now so the caller can switch to
    // cache / show the offline banner without sitting through two
    // doomed backoffs.
    if (!await _isOnline()) {
      return handler.next(err);
    }
    final delay = _delayFor(attempts);
    await Future<void>.delayed(delay);
    final retryOptions = options.copyWith(
      extra: {
        ...options.extra,
        _retryCountKey: attempts + 1,
      },
    );
    try {
      final response = await dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (next) {
      // The retried request bubbled back through the interceptor
      // chain — this very interceptor saw it and either retried
      // again or gave up. Either way the chain has done its work,
      // so we just pass the final error onward.
      handler.next(next);
    } catch (other) {
      handler.next(
        DioException(requestOptions: retryOptions, error: other),
      );
    }
  }

  bool _shouldRetry(DioException err) {
    final options = err.requestOptions;
    if (options.extra['skipRetry'] == true) return false;
    if (options.extra['skipRefresh'] == true) return false; // refresh call
    final method = options.method.toUpperCase();
    final idempotent = options.extra['idempotent'] == true ||
        method == 'GET' ||
        method == 'HEAD' ||
        method == 'OPTIONS';
    if (!idempotent) return false;
    final classified = classifyNetworkError(err);
    switch (classified.kind) {
      case NetworkErrorKind.offline:
      case NetworkErrorKind.timeout:
        return true;
      case NetworkErrorKind.serverError:
        return true;
      case NetworkErrorKind.clientError:
        // 408 Request Timeout and 429 Too Many Requests are 4xx but
        // retryable by spec. Everything else (auth, validation, not
        // found) won't change on retry.
        final status = classified.statusCode ?? 0;
        return status == 408 || status == 429;
      case NetworkErrorKind.cancelled:
      case NetworkErrorKind.unknown:
        return false;
    }
  }

  Duration _delayFor(int attempt) {
    // Exponential backoff with jitter: 500ms, 1000ms, 2000ms... capped
    // at maxDelay. Jitter (±20%) prevents thundering-herd when many
    // tiles / many parallel requests all retry at once after a brief
    // network hiccup.
    final base = baseDelay.inMilliseconds * math.pow(2, attempt);
    final capped = math.min(base.toDouble(), maxDelay.inMilliseconds.toDouble());
    final jitter = (capped * 0.2) * (math.Random().nextDouble() * 2 - 1);
    return Duration(milliseconds: (capped + jitter).round());
  }
}

/// Bare-exception variant used outside Dio (e.g. by the resilient tile
/// provider when wrapping a raw http.Client). Kept here so the policy
/// definition stays in one place.
bool isTransientForRetry(Object error) {
  if (error is TimeoutException) return true;
  if (error is SocketException) return true;
  return false;
}
