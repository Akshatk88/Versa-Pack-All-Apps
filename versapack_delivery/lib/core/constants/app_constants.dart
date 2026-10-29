
class AppConstants {
  AppConstants._();

  static const String title = 'Versapack Delivery';

  /// Consumer-facing brand, used in share text, the referral ticket and the
  /// Razorpay checkout sheet. Change it here, not at the call sites.
  static const String brandName = 'Versapack Delivery';

  /// Second line of the stacked wordmark on the referral ticket.
  static const String brandSuffix = 'Delivery';
  static const String appFontFamily = 'Latin';

  /// Backend origin.
  ///
  /// Overridable at build time so a staging build never needs a code edit:
  ///   flutter build apk --dart-define=API_HOST=https://api.example.com
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  static const String _apiHostOverride = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://versapack.in',
  );

  /// Backend origin. API_BASE_URL is the common cross-app override; API_HOST
  /// remains supported for existing delivery builds.
  static String get apiHost {
    final raw = _apiBaseUrlOverride.trim();
    if (raw.isNotEmpty) {
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.hasAuthority) {
        return Uri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.hasPort ? uri.port : null,
        ).toString().replaceFirst(RegExp(r'/$'), '');
      }
    }
    return _apiHostOverride.replaceFirst(RegExp(r'/+$'), '');
  }

  static String get baseUrl {
    final raw = _apiBaseUrlOverride.trim();
    if (raw.isNotEmpty) return raw.replaceFirst(RegExp(r'/+$'), '');
    return '$apiHost/api/v1';
  }

  static bool get hasValidApiBaseUrl =>
      Uri.tryParse(baseUrl)?.path.replaceAll(RegExp(r'/+$'), '') == '/api/v1';

  /// Turns a backend-relative upload path (`/uploads/...`) into a full URL,
  /// leaving absolute and data URLs untouched.
  static String resolveMediaUrl(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return '';
    if (v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('data:')) {
      return v;
    }
    final path = v.startsWith('/') ? v : '/$v';
    return '$apiHost$path';
  }

  /// Google Maps key used for the Static Maps preview. The SDK map itself
  /// reads its key from the native manifests, not from here.
  static const String mapKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyArBbII2fgAuVaycfkEAm1GcuyvKPTSWyc',
  );

  static const String packageName = 'com.quickcommerce.delivery';
}
