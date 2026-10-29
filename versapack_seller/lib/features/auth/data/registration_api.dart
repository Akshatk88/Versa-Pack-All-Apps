import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/network/dio_client.dart';

/// The documents a store must attach to register.
///
/// The names are the backend's multipart field names, not labels. A file sent
/// under the wrong key is accepted by multer and then silently ignored, so
/// these are worth keeping in one place rather than typed at each call site.
enum StoreDocument {
  pan('panImage', 'PAN Card'),
  gst('gstImage', 'GSTIN Certificate'),
  fssai('fssaiImage', 'FSSAI Licence'),
  storePhoto('profileImage', 'Store Photo'),
  cover('coverImage', 'Cover Photo');

  const StoreDocument(this.field, this.label);

  /// The multipart field the backend reads this document from.
  final String field;
  final String label;
}

/// Seller registration and its document uploads.
///
/// Both endpoints are public: registration happens before an account exists, so
/// there is no token to send.
class RegistrationApi {
  const RegistrationApi(this._dio);

  final Dio _dio;

  /// Uploads one file and returns the URL the backend stored it at.
  ///
  /// Used by the documents step so each attachment is confirmed as it is
  /// picked, rather than discovering at submit time that one of four files was
  /// rejected and having to ask for all of them again.
  Future<String> uploadAttachment({
    required String filePath,
    String folder = 'restaurants',
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'folder': folder,
    });

    final response = await _dio.post<dynamic>(
      '/food/restaurant/upload-attachment',
      data: form,
      // The client sets a JSON content type by default. Left to infer, the
      // multipart boundary never reaches the server and the file arrives empty.
      options: Options(contentType: 'multipart/form-data'),
    );

    final data = response.data;
    final url = data is Map ? (data['url'] ?? data['secure_url'] ?? '') : '';
    return url.toString();
  }

  /// The platform's category list.
  ///
  /// Public and cached server-side for 10 minutes, which matters because the
  /// seller has no token during onboarding — every authenticated category route
  /// is closed to them at this point.
  ///
  /// Returns names only: the registration payload sends `cuisines` as a
  /// comma-separated string, not ids.
  static const List<String> _defaultCategories = [
    'Grocery & Supermarket',
    'Fruits & Vegetables',
    'Bakery & Confectionery',
    'Dairy & Eggs',
    'Personal Care & Cosmetics',
    'Household & Cleaning Essentials',
    'Snacks & Beverages',
    'Meat, Fish & Seafood',
    'Electronics & Gadgets',
    'General Retail & Convenience',
  ];

  Future<List<String>> publicCategories() async {
    try {
      final response = await _dio.get<dynamic>(
        '/food/restaurant/categories/public',
        queryParameters: const {'limit': 100},
      );

      final data = response.data;
      final raw = data is Map ? (data['categories'] ?? data['data']) : null;
      if (raw is! List) return _defaultCategories;

      final names = <String>[];
      final seen = <String>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final name = (item['name'] ?? '').toString().trim();
        if (name.isNotEmpty && seen.add(name.toLowerCase())) names.add(name);
      }
      return names.isNotEmpty ? names : _defaultCategories;
    } catch (_) {
      return _defaultCategories;
    }
  }

  /// Submits the application.
  ///
  /// [documents] maps each document to a local file path. They are sent in the
  /// same multipart request as the text fields, which is what the backend's
  /// register route expects -- it reads the files off named fields rather than
  /// taking URLs uploaded earlier.
  Future<Map<String, dynamic>> register({
    required Map<String, dynamic> fields,
    Map<StoreDocument, String> documents = const {},
    List<String> galleryImagePaths = const [],
  }) async {
    final form = FormData();

    fields.forEach((key, value) {
      if (value == null) return;
      form.fields.add(MapEntry(key, value.toString()));
    });

    for (final entry in documents.entries) {
      if (entry.value.isEmpty) continue;
      form.files.add(
        MapEntry(entry.key.field, await MultipartFile.fromFile(entry.value)),
      );
    }

    for (final path in galleryImagePaths) {
      if (path.isEmpty) continue;
      form.files.add(
        MapEntry('galleryImages', await MultipartFile.fromFile(path)),
      );
    }

    final response = await _dio.post<dynamic>(
      '/food/restaurant/register',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );

    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }
}

final registrationApiProvider = Provider<RegistrationApi>(
  (ref) => RegistrationApi(ref.watch(dioProvider)),
);

/// Categories offered during onboarding, from the backend.
///
/// A failure here must not block registration — `cuisines` is optional in the
/// register schema — so the screen falls back to letting the seller continue
/// without a category rather than trapping them behind a dead list.
final registrationCategoriesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(registrationApiProvider).publicCategories(),
);
