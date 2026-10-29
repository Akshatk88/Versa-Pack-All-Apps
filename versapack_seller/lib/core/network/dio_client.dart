import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/config/constants/app_constants.dart';
import 'package:quick_commerce_seller/core/network/api_exception.dart';
import 'package:quick_commerce_seller/core/providers/core_providers.dart';
import 'package:quick_commerce_seller/core/storage/token_storage.dart';

/// Broadcasts a forced logout to anything that cares.
///
/// A `ChangeNotifier` in an otherwise Riverpod-only app is a deliberate,
/// documented exception: the auth controller and the router refresh listener
/// both need to react to the same event, and Riverpod 3 has no
/// `ChangeNotifierProvider` to route it through.
class AuthSessionNotifier extends ChangeNotifier {
  bool _isExpired = false;

  /// True once the backend has invalidated this session and the client cannot
  /// recover it by refreshing.
  bool get isExpired => _isExpired;

  /// Reason to show the seller — for a device eviction the backend's wording is
  /// far more useful than "session expired".
  String? get reason => _reason;
  String? _reason;

  void notifySessionExpired({String? reason}) {
    _isExpired = true;
    _reason = reason;
    notifyListeners();
  }

  /// Called after a successful login so a later eviction fires cleanly.
  void reset() {
    _isExpired = false;
    _reason = null;
  }
}

final authSessionProvider = Provider<AuthSessionNotifier>((ref) {
  final notifier = AuthSessionNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// The single HTTP entry point. Never construct a `Dio` in a feature, and never
/// add an interceptor from one.
final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final session = ref.watch(authSessionProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );

  // Interceptor-free client for the refresh call itself. Using `dio` here would
  // recurse: a 401 from the refresh endpoint would trigger another refresh.
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
    ),
  );

  final refresher = _TokenRefresher(
    refreshDio: refreshDio,
    tokenStorage: tokenStorage,
    session: session,
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        debugPrint('--------------------------------------------------');
        debugPrint('>>> [HTTP REQUEST] ${options.method} ${options.uri}');
        debugPrint('>>> [ACCESS TOKEN]: $token');
        debugPrint('>>> [AUTHORIZATION HEADER]: ${options.headers['Authorization']}');
        debugPrint('--------------------------------------------------');
        handler.next(options);
      },

      onResponse: (response, handler) {
        final body = response.data;

        // The backend wraps every route the app calls in
        // `{ success, message, data }`. A few (health, the socket process, some
        // FCM debug routes) do not — leave those untouched rather than
        // pretending they are malformed.
        if (body is! Map || !body.containsKey('success')) {
          return handler.next(response);
        }

        if (body['success'] == true) {
          // `data` is legitimately absent on some 200s (e.g. a bare
          // acknowledgement), so an empty map is the honest substitute.
          response.data = body['data'] ?? const <String, dynamic>{};
          return handler.next(response);
        }

        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: ApiException(
              message: _messageFrom(body) ?? 'Something went wrong.',
              statusCode: response.statusCode,
              data: body['data'],
            ),
          ),
        );
      },

      onError: (error, handler) async {
        final options = error.requestOptions;
        final status = error.response?.statusCode;

        if (status == 401 && !_isAuthEndpoint(options.path)) {
          final message = _messageFrom(error.response?.data);

          // The backend increments `tokenVersion` on every login and rejects
          // stale tokens with this message. The refresh token minted before
          // that login is stale too, so refreshing can never succeed —
          // attempting it would loop until the retry guard trips.
          if (_isDeviceEviction(message)) {
            await tokenStorage.clear();
            session.notifySessionExpired(reason: message);
            return handler.reject(
              _asApiException(
                error,
                message ?? 'You have been signed out.',
                isSessionEvicted: true,
              ),
            );
          }

          // Guard against a replayed request 401-ing again and recursing.
          if (options.extra[_retriedFlag] != true) {
            final newToken = await refresher.refresh();
            if (newToken != null) {
              options.extra[_retriedFlag] = true;
              options.headers['Authorization'] = 'Bearer $newToken';
              try {
                final replayed = await dio.fetch<dynamic>(options);
                return handler.resolve(replayed);
              } on DioException catch (e) {
                return handler.reject(e);
              }
            }
          }

          return handler.reject(
            _asApiException(
              error,
              message ?? 'Your session has expired. Please sign in again.',
              isSessionEvicted: true,
            ),
          );
        }

        handler.reject(_asApiException(error, _friendlyMessage(error)));
      },
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        // Bodies can carry tokens and OTPs; the line is only ever useful for
        // seeing which call fired.
        request: false,
        requestBody: false,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
        logPrint: (line) => debugPrint('$line'),
      ),
    );
  }

  ref.onDispose(() {
    dio.close();
    refreshDio.close();
  });

  return dio;
});

const String _retriedFlag = 'qc_retried_after_refresh';

/// De-duplicates concurrent refreshes. Without this, five parallel screen loads
/// hitting an expired token fire five refreshes, and the backend's token
/// rotation means four of them lose.
class _TokenRefresher {
  _TokenRefresher({
    required this.refreshDio,
    required this.tokenStorage,
    required this.session,
  });

  final Dio refreshDio;
  final TokenStorage tokenStorage;
  final AuthSessionNotifier session;

  Completer<String?>? _inFlight;

  Future<String?> refresh() {
    final existing = _inFlight;
    if (existing != null) return existing.future;

    final completer = Completer<String?>();
    _inFlight = completer;

    unawaited(
      _performRefresh()
          .then((token) {
            _inFlight = null;
            completer.complete(token);
          })
          .catchError((Object _) {
            _inFlight = null;
            completer.complete(null);
          }),
    );

    return completer.future;
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await tokenStorage.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _failSession(null);
      return null;
    }

    try {
      final response = await refreshDio.post<dynamic>(
        '/food/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      // refreshDio has no interceptors, so the envelope is still wrapped here.
      final body = response.data;
      final payload = body is Map ? body['data'] : null;
      final accessToken = payload is Map ? payload['accessToken'] : null;

      if (accessToken is! String || accessToken.isEmpty) {
        await _failSession(null);
        return null;
      }

      await tokenStorage.saveAccessToken(accessToken);
      final newRefresh = payload is Map ? payload['refreshToken'] : null;
      if (newRefresh is String && newRefresh.isNotEmpty) {
        await tokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: newRefresh,
        );
      }
      return accessToken;
    } on DioException catch (e) {
      await _failSession(_messageFrom(e.response?.data));
      return null;
    }
  }

  Future<void> _failSession(String? reason) async {
    await tokenStorage.clear();
    session.notifySessionExpired(reason: reason);
  }
}

bool _isAuthEndpoint(String path) =>
    path.contains('/auth/') || path.contains('/restaurant/register');

bool _isDeviceEviction(String? message) =>
    message != null && message.toLowerCase().contains('another device');

String? _messageFrom(Object? body) {
  if (body is! Map) return null;

  final message = body['message'];
  if (message is String && message.isNotEmpty) return message;

  // Validation failures come back as `{ success: false, error: 'Required' }`
  // with no `message` at all — reading only `message` would replace the
  // server's reason with a generic fallback.
  final error = body['error'];
  if (error is String && error.isNotEmpty) return error;

  return null;
}

DioException _asApiException(
  DioException error,
  String message, {
  bool isSessionEvicted = false,
}) {
  // A rejection produced by the response interceptor already carries one.
  if (error.error is ApiException) return error;

  final body = error.response?.data;
  return DioException(
    requestOptions: error.requestOptions,
    response: error.response,
    type: error.type,
    error: ApiException(
      message: message,
      statusCode: error.response?.statusCode,
      data: body is Map ? body['data'] : body,
      isSessionEvicted: isSessionEvicted,
    ),
  );
}

String _friendlyMessage(DioException error) {
  final serverMessage = _messageFrom(error.response?.data);
  if (serverMessage != null) return serverMessage;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'The server took too long to respond. Please try again.';
    case DioExceptionType.connectionError:
      return 'No internet connection. Please try again.';
    case DioExceptionType.cancel:
      return 'Request cancelled.';
    case DioExceptionType.badCertificate:
      return 'Could not establish a secure connection.';
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
    // Newer Dio versions add cases here; a generic message is the right
    // fallback for any transport failure we have no specific copy for.
    default:
      return 'Something went wrong. Please try again.';
  }
}
