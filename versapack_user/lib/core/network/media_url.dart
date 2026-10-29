/// Resolves the media paths the backend stores.
///
/// Uploads are persisted as root-relative paths (`/uploads/food/...`) because
/// the web frontend resolves them against its own origin through nginx. A
/// mobile client has no origin of its own, so `Image.network('/uploads/...')`
/// fails outright. Every image field routes through here to be made absolute
/// against the API host.
abstract final class MediaUrl {
  static String _origin = '';

  /// Called once at startup with `AppConfig.apiBaseUrl` (…/api/v1); the origin
  /// is everything before the path.
  static void configure(String apiBaseUrl) {
    final uri = Uri.tryParse(apiBaseUrl);
    _origin = uri == null || !uri.hasAuthority
        ? ''
        : Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null)
            .toString();
  }

  static String resolve(String url) {
    var value = url.trim().replaceAll('\\', '/');
    if (value.isEmpty) return '';
    // A few old/seeded records contain malformed protocol separators.
    value = value.replaceFirst(RegExp(r'^(https?):/(?!/)'), r'$1://');
    if (value.startsWith('//')) value = 'https:$value';

    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasAuthority) {
      // localhost in an API response refers to the server, not the Android
      // device. Rewrite it to the configured backend origin, matching the web
      // client's media resolver. Otherwise ImageDecoder receives an error page
      // (or no response) instead of image bytes.
      final host = parsed.host.toLowerCase();
      if (_origin.isNotEmpty &&
          (host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0')) {
        final origin = Uri.parse(_origin);
        return parsed
            .replace(
              scheme: origin.scheme,
              host: origin.host,
              port: origin.hasPort ? origin.port : null,
            )
            .toString();
      }
      return value;
    }

    if (_origin.isEmpty) return value;
    return value.startsWith('/') ? '$_origin$value' : '$_origin/$value';
  }

  /// Whether [url] is safe to hand to a network image provider.
  static bool isHttpUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
