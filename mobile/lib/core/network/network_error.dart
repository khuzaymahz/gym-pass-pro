import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../l10n/app_localizations.dart';
import '../api/api_exception.dart';

/// Coarse-grained classification of failures coming out of the network
/// layer. Pages should never pattern-match on raw exception strings —
/// they route everything through [classifyNetworkError] and switch on
/// this enum. Without that, every screen ends up with its own copy of
/// the SocketException / "Failed host lookup" / "connectionError"
/// sniffer (we had five and counting before this lived here).
///
/// Cases are listed in resolution order: more specific first.
enum NetworkErrorKind {
  /// No transport: device has no working route to the server. Could be
  /// truly offline, captive portal, DNS failure, TCP RST, or a kernel-
  /// level firewall block. From a UX point of view they're all the
  /// same — show "Check your connection" and offer retry.
  offline,

  /// Transport was up but the request didn't finish in time. Distinct
  /// from [offline] because the next attempt has a reasonable chance
  /// of succeeding on the same network (server was slow, not down).
  timeout,

  /// Request was cancelled (e.g. page unmounted, controller disposed).
  /// Not user-facing — call sites that surface this in UI are usually
  /// racing themselves. Logged but otherwise dropped.
  cancelled,

  /// Server responded 5xx. The request reached the server but
  /// something on the other side failed. Retryable in principle.
  serverError,

  /// Server responded 4xx — auth, validation, business-rule rejection.
  /// Caller should look at the inner [ApiException.code] for a precise
  /// message; this enum is too coarse on its own.
  clientError,

  /// Anything we didn't anticipate. Pages render the generic snackbar
  /// instead of leaking a raw exception string to the user.
  unknown,
}

/// Carrier for the classified failure. Holds the kind plus the
/// underlying [ApiException] when one is present, so call sites that
/// want to special-case a specific business code (e.g.
/// `AUTH_INVALID_CREDENTIALS`) can do so without re-walking the
/// `DioException → response → data → error` tree.
class ClassifiedNetworkError {
  ClassifiedNetworkError({
    required this.kind,
    this.apiException,
    this.statusCode,
  });

  final NetworkErrorKind kind;
  final ApiException? apiException;
  final int? statusCode;

  /// True when the device couldn't reach the server at all (no route,
  /// DNS failure, TCP refused, request timed out). UI uses this to
  /// suppress action-specific messages ("invalid credentials") in
  /// favour of the connectivity message — there's no point telling
  /// the user their password is wrong if we never got far enough to
  /// check.
  bool get isTransport =>
      kind == NetworkErrorKind.offline || kind == NetworkErrorKind.timeout;
}

/// Map a thrown error into a [ClassifiedNetworkError]. Handles:
///   * `DioException` with structured `ApiException` envelope
///   * `DioException` with `SocketException` / `HttpException` /
///     `TimeoutException` underneath (transport-level)
///   * Bare `SocketException`, `TimeoutException`, `HandshakeException`
///     thrown outside of Dio (e.g. by `package:http` clients —
///     resilient_tile_provider, biometric vault).
///
/// Anything else falls through to [NetworkErrorKind.unknown] — better
/// to show a generic snackbar than to mis-classify something rare as
/// "offline" and have the user disable airplane mode for nothing.
ClassifiedNetworkError classifyNetworkError(Object error) {
  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiException) {
      return ClassifiedNetworkError(
        kind: inner.statusCode >= 500
            ? NetworkErrorKind.serverError
            : NetworkErrorKind.clientError,
        apiException: inner,
        statusCode: inner.statusCode,
      );
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ClassifiedNetworkError(kind: NetworkErrorKind.timeout);
      case DioExceptionType.cancel:
        return ClassifiedNetworkError(kind: NetworkErrorKind.cancelled);
      case DioExceptionType.connectionError:
        return ClassifiedNetworkError(kind: NetworkErrorKind.offline);
      case DioExceptionType.badCertificate:
        return ClassifiedNetworkError(kind: NetworkErrorKind.offline);
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        return ClassifiedNetworkError(
          kind: status >= 500
              ? NetworkErrorKind.serverError
              : NetworkErrorKind.clientError,
          statusCode: status,
        );
      case DioExceptionType.unknown:
        // Fall through to the inner-exception sniff below.
        break;
    }
    if (inner is SocketException || inner is HttpException) {
      return ClassifiedNetworkError(kind: NetworkErrorKind.offline);
    }
    if (inner is TimeoutException) {
      return ClassifiedNetworkError(kind: NetworkErrorKind.timeout);
    }
    return ClassifiedNetworkError(kind: NetworkErrorKind.unknown);
  }
  if (error is ApiException) {
    return ClassifiedNetworkError(
      kind: error.statusCode >= 500
          ? NetworkErrorKind.serverError
          : NetworkErrorKind.clientError,
      apiException: error,
      statusCode: error.statusCode,
    );
  }
  if (error is SocketException || error is HttpException) {
    return ClassifiedNetworkError(kind: NetworkErrorKind.offline);
  }
  if (error is TimeoutException) {
    return ClassifiedNetworkError(kind: NetworkErrorKind.timeout);
  }
  return ClassifiedNetworkError(kind: NetworkErrorKind.unknown);
}

/// Localized one-liner for a failure. Use this whenever you'd
/// otherwise pop a snackbar from a catch block — it routes
/// transport-level failures to `errorNetwork` and everything else to
/// `snackErrorGeneric`, so the member sees a consistent message
/// across screens.
///
/// Call sites that need to special-case a business code (wrong
/// password, OTP locked, etc.) should pre-empt this with their own
/// `if (classified.apiException?.code == 'AUTH_INVALID_CREDENTIALS')`
/// check, then fall through here for everything else.
String resolveErrorMessage(Object error, AppLocalizations l) {
  final c = classifyNetworkError(error);
  switch (c.kind) {
    case NetworkErrorKind.offline:
    case NetworkErrorKind.timeout:
      return l.errorNetwork;
    case NetworkErrorKind.cancelled:
    case NetworkErrorKind.clientError:
    case NetworkErrorKind.serverError:
    case NetworkErrorKind.unknown:
      return l.snackErrorGeneric;
  }
}

/// String-form fallback for call sites that only have a stringified
/// error (e.g. AuthState.error stored as `e.toString()` in the auth
/// controller, where the original exception object isn't preserved).
///
/// Matches the same transport patterns the live network stack emits
/// when it can't reach the server — `SocketException`, dart:io
/// "Failed host lookup", Dio's `connectionError` / `connectionTimeout`
/// type tags. Anything else collapses to the generic snack.
///
/// New call sites should prefer [resolveErrorMessage] with the raw
/// `Object` error — the structured form catches more transport types
/// (e.g. `HandshakeException`, `BadCertificate`) and distinguishes
/// offline from server-error. This string form exists only to keep
/// the AuthController stringification path migratable in one line.
String resolveErrorMessageString(String raw, AppLocalizations l) {
  if (_transportPatterns.any(raw.contains)) return l.errorNetwork;
  return l.snackErrorGeneric;
}

const _transportPatterns = <String>[
  'SocketException',
  'HttpException',
  'HandshakeException',
  'TimeoutException',
  'connectionError',
  'connectionTimeout',
  'Connection refused',
  'Failed host lookup',
  'Network is unreachable',
  'No address associated with hostname',
];
