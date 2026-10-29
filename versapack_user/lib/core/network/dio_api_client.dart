import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../errors/app_exception.dart';
import '../errors/error_mapper.dart';
import '../local_storage/local_storage.dart';
import '../utils/logger.dart';
import 'api_client.dart';

/// Supplies and refreshes the tokens the interceptors need. Implemented by the
/// auth repository so this client stays free of feature knowledge.
abstract interface class AuthTokenStore {
  String? get accessToken;
  String? get refreshToken;
  Future<bool> refreshSession();
  Future<void> clearSession();
}

/// Reads/writes tokens straight from [LocalStorage]. The refresh call is
/// installed later by the auth repository via [onRefresh] to avoid a cycle.
class LocalAuthTokenStore implements AuthTokenStore {
  LocalAuthTokenStore(this._storage);

  final LocalStorage _storage;
  Future<bool> Function()? onRefresh;

  @override
  String? get accessToken => _storage.getString(StorageKeys.accessToken);

  @override
  String? get refreshToken => _storage.getString(StorageKeys.refreshToken);

  @override
  Future<bool> refreshSession() async => await onRefresh?.call() ?? false;

  @override
  Future<void> clearSession() async {
    await _storage.remove(StorageKeys.accessToken);
    await _storage.remove(StorageKeys.refreshToken);
    await _storage.remove(StorageKeys.userJson);
  }
}

/// The single transport used by every repository.
///
/// The backend always answers `{success, message, data}`; this client unwraps
/// `data` and converts anything else into a typed [AppException].
class DioApiClient implements ApiClient {
  DioApiClient({required AppConfig config, required AuthTokenStore tokenStore})
      : _tokenStore = tokenStore,
        _dio = Dio(
          BaseOptions(
            baseUrl: config.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 25),
            sendTimeout: const Duration(seconds: 25),
            headers: const {'Accept': 'application/json'},
            // We inspect the envelope ourselves, so let every status through.
            validateStatus: (_) => true,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.extra['requiresAuth'] == true) {
            final token = _tokenStore.accessToken;
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          if (config.enableNetworkLogs) {
            AppLogger.debug('→ ${options.method} ${options.uri}', scope: 'net');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (config.enableNetworkLogs) {
            AppLogger.debug(
              '← ${response.statusCode} ${response.requestOptions.uri}',
              scope: 'net',
            );
          }
          handler.next(response);
        },
      ),
    );
  }

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requiresAuth = false,
  }) =>
      _send(path, 'GET', query: query, headers: headers, requiresAuth: requiresAuth);

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requiresAuth = false,
  }) =>
      _send(path, 'POST', body: body, query: query, headers: headers, requiresAuth: requiresAuth);

  @override
  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
    bool requiresAuth = false,
  }) =>
      _send(path, 'PATCH', body: body, headers: headers, requiresAuth: requiresAuth);

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
    bool requiresAuth = false,
  }) =>
      _send(path, 'PUT', body: body, headers: headers, requiresAuth: requiresAuth);

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
    bool requiresAuth = false,
  }) =>
      _send(path, 'DELETE', body: body, headers: headers, requiresAuth: requiresAuth);

  Future<dynamic> _send(
    String path,
    String method, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requiresAuth = false,
    bool allowRetry = true,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: _pruned(query),
        options: Options(
          method: method,
          headers: headers,
          extra: {'requiresAuth': requiresAuth},
        ),
      );

      final status = response.statusCode ?? 0;

      // One transparent refresh-and-retry on an expired access token.
      // One transparent refresh-and-retry on an expired access token.
      if (status == 401 && requiresAuth && allowRetry) {
        print('🔴 401 body: ${response.data}');
        print('🔴 401 request headers: ${response.requestOptions.headers}');
        final refreshed = await _tokenStore.refreshSession();
        if (refreshed) {
          return _send(
            path,
            method,
            body: body,
            query: query,
            requiresAuth: requiresAuth,
            allowRetry: false,
          );
        }
        await _tokenStore.clearSession();
      }

      if (status < 200 || status >= 300) throw ErrorMapper.fromResponse(response);

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['success'] == false) throw ErrorMapper.fromResponse(response);
        // Some endpoints legitimately answer with `data: null`.
        return data.containsKey('data') ? data['data'] : data;
      }
      return data;
    } on DioException catch (e, stackTrace) {
      AppLogger.error(
        'API request failed: $method $path',
        error: e,
        stackTrace: stackTrace,
      );
      throw ErrorMapper.fromDio(e);
    } catch (e, stackTrace) {
      AppLogger.error(
        'API request failed: $method $path',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Dio serialises nulls as empty params; the backend's zod validators reject
  /// those, so strip them here rather than at every call site.
  Map<String, dynamic>? _pruned(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      cleaned[key] = value;
    });
    return cleaned.isEmpty ? null : cleaned;
  }
}
