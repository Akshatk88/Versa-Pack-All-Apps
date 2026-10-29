import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/config/constants/app_constants.dart';

void main() {
  group('AppConstants.resolveMediaUrl', () {
    test('leaves an absolute URL alone', () {
      expect(
        AppConstants.resolveMediaUrl('https://cdn.example.com/a.webp'),
        'https://cdn.example.com/a.webp',
      );
      expect(
        AppConstants.resolveMediaUrl('http://cdn.example.com/a.webp'),
        'http://cdn.example.com/a.webp',
      );
    });

    test('prefixes the origin onto a relative path', () {
      // The backend deliberately stores relative upload paths, so this is the
      // common case rather than the edge case.
      expect(
        AppConstants.resolveMediaUrl('/uploads/stores/logo.webp'),
        '${AppConstants.mediaOrigin}/uploads/stores/logo.webp',
      );
    });

    test('inserts the missing separator on a path without a leading slash', () {
      expect(
        AppConstants.resolveMediaUrl('uploads/logo.webp'),
        '${AppConstants.mediaOrigin}/uploads/logo.webp',
      );
    });

    test('empty and null collapse to an empty string', () {
      expect(AppConstants.resolveMediaUrl(null), '');
      expect(AppConstants.resolveMediaUrl(''), '');
    });

    test('the media origin carries no path segment', () {
      expect(Uri.parse(AppConstants.mediaOrigin).path, isEmpty);
    });
  });
}
