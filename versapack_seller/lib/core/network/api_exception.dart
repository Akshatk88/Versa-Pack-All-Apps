/// A backend or transport failure, reduced to something a screen can render.
///
/// Every error leaving `dioProvider`'s interceptors is a `DioException` whose
/// `.error` is one of these, so UI code only ever has to handle this type plus
/// a generic fallback.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
    this.isSessionEvicted = false,
  });

  /// Human-readable copy. Prefer the server's `message` — it is written for the
  /// seller and is more specific than anything the client can invent.
  final String message;
  final int? statusCode;

  /// The raw payload, kept so a caller can pull out field-level validation
  /// details without a second parse.
  final Object? data;

  /// True when the backend evicted this session because the account signed in
  /// on another device. Distinct from an ordinary 401 because the refresh token
  /// is invalid too — retrying can never succeed.
  final bool isSessionEvicted;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
