import 'dart:async';

import 'package:dio/dio.dart';

import '../config/env.dart';
import 'api_exception.dart';
import 'token_store.dart';

class ApiClient {
  ApiClient({required AppEnv env, required TokenStore tokens})
      : _tokens = tokens,
        dio = Dio(
          BaseOptions(
            baseUrl: env.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'content-type': 'application/json'},
          ),
        ) {
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
        // Token expired / invalid — try to refresh once, then retry
        // the original request with the new access token. Only fires
        // for requests that asked for auth (`requireAuth == true`)
        // and only if we have a refresh token to use. The refresh
        // call itself sets `extra.skipRefresh = true` so a failure
        // there doesn't recurse.
        final isAuthRequest = error.requestOptions.extra['requireAuth'] == true;
        final isRefreshCall =
            error.requestOptions.extra['skipRefresh'] == true;
        final isExpired = resp?.statusCode == 401 &&
            (resp?.data is Map &&
                (resp!.data as Map)['error'] is Map &&
                (((resp.data as Map)['error'] as Map)['code'] ==
                        'AUTH_TOKEN_EXPIRED' ||
                    ((resp.data as Map)['error'] as Map)['code'] ==
                        'AUTH_TOKEN_INVALID'));
        if (isAuthRequest && !isRefreshCall && isExpired) {
          final refreshed = await _refreshOnce();
          if (refreshed) {
            // Retry the original request with the new access token.
            final newToken = await _tokens.readAccess();
            final retryOptions = error.requestOptions
              ..headers['authorization'] = 'Bearer $newToken';
            try {
              final response = await dio.fetch<dynamic>(retryOptions);
              handler.resolve(response);
              return;
            } catch (retryErr) {
              // Fall through to the structured-envelope unwrap below.
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
