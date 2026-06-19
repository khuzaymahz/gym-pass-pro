import 'dart:async';

import 'package:dio/dio.dart';

import '../config/env.dart';
import 'api_exception.dart';
import 'retry_interceptor.dart';
import 'token_store.dart';

class ApiClient {
  ApiClient({
    required AppEnv env,
    required TokenStore tokens,
    Future<bool> Function()? isOnline,
  })  : _tokens = tokens,
        dio = Dio(
          BaseOptions(
            baseUrl: env.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'content-type': 'application/json'},
          ),
        ) {
    // Order matters. Retry sits **before** auth so a 5xx retry runs
    // its own backoff loop on the original (still-authed) request,
    // and only failures it can't recover from cascade to the auth
    // interceptor — which then handles 401 / refresh / re-issue
    // exactly once.
    dio.interceptors.add(RetryInterceptor(dio: dio, isOnline: isOnline));
    dio.interceptors.add(_buildInterceptor());
  }

  final Dio dio;
  final TokenStore _tokens;

  /// Single in-flight refresh shared across concurrent 401s. Without
  /// this, ten simultaneous expired requests would each try to refresh
  /// the token, racing each other and burning the refresh token (the
  /// backend invalidates the old one on each refresh). Coalescing
  /// onto one future means the first 401 starts a refresh, the rest
  /// wait for it, and everyone retries with the new access token.
  Future<bool>? _refreshInFlight;

  /// Short-lived memo of the most recent refresh result. Closes the
  /// trailing-401 race the prior coalescer left open: a third 401
  /// arriving the millisecond `_refreshInFlight` cleared would start a
  /// SECOND refresh, which the backend invalidates the just-issued
  /// access token against. With this memo, late-arriving 401s see
  /// "we refreshed N ms ago — just re-read the token and retry" for a
  /// short window (10s). Stamped with the new access token's prefix so
  /// we can detect the 401 was caused by an even-newer rotation.
  static const _refreshMemoTtl = Duration(seconds: 10);
  DateTime? _lastRefreshAt;
  String? _lastRefreshAccessPrefix;

  InterceptorsWrapper _buildInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final requireAuth = options.extra['requireAuth'] == true;
        if (requireAuth) {
          final token = await _tokens.readAccess();
          if (token != null) {
            options.headers['authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final resp = error.response;
        final isAuthRequest = error.requestOptions.extra['requireAuth'] == true;
        final isRefreshCall =
            error.requestOptions.extra['skipRefresh'] == true;
        // Treat ANY 401 on an authed request as refresh-eligible. The
        // backend emits a typed `AUTH_TOKEN_EXPIRED` / `AUTH_TOKEN_INVALID`
        // envelope on its 401s, but a 401 from an upstream proxy, a
        // malformed JSON body, or a future error code we don't enumerate
        // here would skip refresh and bounce the member to sign-in for
        // what was actually a recoverable token expiry. Treating bare
        // 401 as refresh-eligible (still gated on `requireAuth` and
        // `!isRefreshCall`) is the conservative shape — worst case is
        // one wasted refresh on a hard 401, vs. a member punished for
        // an expiry the interceptor was built to absorb.
        final isUnauthorised = resp?.statusCode == 401;
        if (isAuthRequest && !isRefreshCall && isUnauthorised) {
          // Check if a recent refresh memo covers us. If the token the
          // failing request carried matches the access token we issued
          // < `_refreshMemoTtl` ago, a second refresh would invalidate
          // the still-good token. Just retry with whatever's in store.
          final sentAuth =
              error.requestOptions.headers['authorization'] as String?;
          final memo = _recentRefreshCovers(sentAuth);
          if (memo) {
            final newToken = await _tokens.readAccess();
            final retryOptions = error.requestOptions
              ..headers['authorization'] = 'Bearer $newToken';
            try {
              final response = await dio.fetch<dynamic>(retryOptions);
              handler.resolve(response);
              return;
            } catch (retryErr) {
              if (retryErr is DioException) {
                _emitStructured(retryErr, handler);
                return;
              }
              rethrow;
            }
          }
          final refreshed = await _refreshOnce();
          if (refreshed) {
            final newToken = await _tokens.readAccess();
            final retryOptions = error.requestOptions
              ..headers['authorization'] = 'Bearer $newToken';
            try {
              final response = await dio.fetch<dynamic>(retryOptions);
              handler.resolve(response);
              return;
            } catch (retryErr) {
              if (retryErr is DioException) {
                _emitStructured(retryErr, handler);
                return;
              }
              rethrow;
            }
          }
        }
        _emitStructured(error, handler);
      },
    );
  }

  /// Does a recently-completed refresh cover this 401? Returns true
  /// when the failed request's Authorization header carried a token
  /// older than the one we just stored, and the memo is still warm.
  /// Lets trailing-window 401s skip the redundant refresh.
  bool _recentRefreshCovers(String? failedAuthHeader) {
    final at = _lastRefreshAt;
    final prefix = _lastRefreshAccessPrefix;
    if (at == null || prefix == null) return false;
    if (DateTime.now().difference(at) > _refreshMemoTtl) return false;
    if (failedAuthHeader == null) return true;
    // If the failing request was already carrying the new access
    // token's prefix, the 401 was for a different reason — don't
    // suppress refresh.
    final sentPrefix = _prefixOf(failedAuthHeader);
    return sentPrefix != prefix;
  }

  static String? _prefixOf(String authHeader) {
    if (!authHeader.toLowerCase().startsWith('bearer ')) return null;
    final token = authHeader.substring(7);
    return token.length >= 16 ? token.substring(0, 16) : token;
  }

  /// Wrap server `{"error": {"code": ..., "message": ...}}` payloads
  /// in an [ApiException] so call sites get a typed code instead of
  /// a raw `DioException [bad_response]` string.
  void _emitStructured(DioException error, ErrorInterceptorHandler handler) {
    final resp = error.response;
    if (resp != null) {
      final data = resp.data;
      if (data is Map && data['error'] is Map) {
        final e = data['error'] as Map;
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            response: resp,
            error: ApiException(
              code: (e['code'] ?? 'UNKNOWN').toString(),
              message: (e['message'] ?? resp.statusMessage ?? 'Error').toString(),
              statusCode: resp.statusCode ?? 0,
              details: (e['details'] as Map?)?.cast<String, dynamic>(),
            ),
          ),
        );
        return;
      }
    }
    handler.next(error);
  }

  /// Trade the saved refresh token for a fresh access+refresh pair.
  /// Returns true on success. Coalesces concurrent calls onto a
  /// single in-flight future. On failure clears tokens (forces a
  /// fresh login) and returns false.
  Future<bool> _refreshOnce() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final future = _doRefresh();
    _refreshInFlight = future;
    future.whenComplete(() => _refreshInFlight = null);
    return future;
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await _tokens.readRefresh();
    if (refreshToken == null) return false;
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'skipRefresh': true}),
      );
      final data = response.data;
      if (data == null) return false;
      final access = data['accessToken'] as String?;
      final refresh = data['refreshToken'] as String?;
      if (access == null || refresh == null) return false;
      final persistent = await _tokens.isPersistent();
      await _tokens.save(
        access: access,
        refresh: refresh,
        persistent: persistent,
      );
      _lastRefreshAt = DateTime.now();
      _lastRefreshAccessPrefix =
          access.length >= 16 ? access.substring(0, 16) : access;
      return true;
    } catch (_) {
      // Refresh failed — token revoked, expired refresh, network
      // hiccup. Wipe the tokens so the next app launch / route
      // guard kicks the member back to sign-in instead of looping
      // on 401s.
      await _tokens.clear();
      return false;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool authed = false,
  }) {
    return dio.get<T>(
      path,
      queryParameters: query,
      options: Options(extra: {'requireAuth': authed}),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? body,
    bool authed = false,
  }) {
    return dio.post<T>(
      path,
      data: body,
      options: Options(extra: {'requireAuth': authed}),
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? body,
    bool authed = false,
  }) {
    return dio.patch<T>(
      path,
      data: body,
      options: Options(extra: {'requireAuth': authed}),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? body,
    bool authed = false,
  }) {
    return dio.delete<T>(
      path,
      data: body,
      options: Options(extra: {'requireAuth': authed}),
    );
  }
}
