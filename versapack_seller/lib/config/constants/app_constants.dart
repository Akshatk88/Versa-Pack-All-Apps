/// Environment-level configuration.
///
/// Values are supplied at build time so a release build never carries a
/// developer's machine address:
///
///   flutter run --dart-define=BASE_URL=https://api.example.com/api \
///               --dart-define=SOCKET_URL=https://api.example.com
///
/// The defaults point at the deployed backend, so a plain `flutter run` works
/// on a physical device without any extra flags. Point them at a local server
/// only when you have one running and the device shares its network — the
/// Android emulator reaches the host as `10.0.2.2`, never `localhost`.
class AppConstants {
  const AppConstants._();

  /// Backend origin **including the `/api/v1` prefix**, matching
  /// `FLUTTER_API_SPEC.md` ("Base URL: {HOST}/api/v1"). Repository paths are
  /// therefore written without the version, e.g. `/food/restaurant/current`.
  /// Keep the version here and nowhere else — splitting it across the base and
  /// the call sites is how paths end up with a doubled or missing segment.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // BASE_URL is retained as a compatibility alias for existing CI/release
    // commands. New builds should use API_BASE_URL for all three apps.
    defaultValue: String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'https://versapack.in/api/v1',
    ),
  );

  /// Socket.IO origin. Deployed behind the same host as the API; a local setup
  /// may run it as a separate process on 5001 (`SOCKET_PORT`), which is why it
  /// is configured independently of [baseUrl].
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://versapack.in',
  );

  static bool get hasValidApiBaseUrl =>
      Uri.tryParse(baseUrl)?.path.replaceAll(RegExp(r'/+$'), '') == '/api/v1';

  /// Google Maps key for the Dart side (Maps SDK, Places, Geocoding).
  ///
  /// **This is the single source of truth for the Dart layer only.** The native
  /// Maps SDKs read their key before any Dart code runs, so Android and iOS
  /// each need their own copy — they cannot import this constant. Those live in:
  ///
  ///   * `android/gradle.properties` → `MAPS_API_KEY`, injected into
  ///     `AndroidManifest.xml` as the `MAPS_API_KEY` manifest placeholder.
  ///   * `ios/Runner/Info.plist` → `GoogleMapsApiKey`.
  ///
  /// Change the key in all three, or override every one at build time:
  ///
  ///   flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=... \
  ///     -Pmaps-api-key=...
  ///
  /// A Maps key shipped in an app binary is always extractable — that is
  /// expected and is not what protects it. Restrict it in the Google Cloud
  /// console by Android package name + SHA-1, iOS bundle id, and the specific
  /// APIs it may call. An unrestricted key is billable by anyone who finds it.
  static const String googleMapsApiKey = String.fromEnvironment(
    'AIzaSyArBbII2fgAuVaycfkEAm1GcuyvKPTSWyc',
    defaultValue: 'AIzaSyArBbII2fgAuVaycfkEAm1GcuyvKPTSWyc',
  );

  /// Whether a Maps key is configured at all. Screens that would otherwise
  /// render a blank grey tile can check this and show an explanation instead.
  static bool get hasGoogleMapsKey => googleMapsApiKey.isNotEmpty;

  /// Origin used to resolve relative media paths.
  ///
  /// The backend's upload service deliberately refuses to persist absolute
  /// localhost URLs, so `url` in an upload response is usually a relative
  /// `/uploads/...` path. [resolveMediaUrl] turns it back into something the
  /// image loader can fetch.
  static String get mediaOrigin {
    final uri = Uri.parse(baseUrl);
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.port).toString();
  }

  /// Absolute URL for a possibly-relative media path returned by the backend.
  /// Returns an empty string for empty input so callers can branch on `isEmpty`
  /// rather than juggling nulls.
  static String resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$mediaOrigin${url.startsWith('/') ? '' : '/'}$url';
  }
}
