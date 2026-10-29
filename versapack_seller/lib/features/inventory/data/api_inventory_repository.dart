import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:quick_commerce_seller/features/inventory/domain/inventory_repository.dart';
import 'package:quick_commerce_seller/features/inventory/domain/product_model.dart';

/// The seller's catalogue and stock.
///
/// Products come back from `/food/restaurant/menu` grouped into sections, which
/// is the shape the customer app renders. A seller manages a flat list, so the
/// sections are flattened here rather than in a controller — the grouping is a
/// presentation detail of a different app.
class ApiInventoryRepository implements InventoryRepository {
  const ApiInventoryRepository(this._dio);

  final Dio _dio;

  @override
  /// Uploads one product image and returns the stored URL.
  ///
  /// `/uploads/image` takes multipart under the field `file` and re-encodes to
  /// WebP server-side. The URL it returns is usually relative, and is stored
  /// as-is — `AppConstants.resolveMediaUrl` makes it absolute for display.
  Future<String> uploadImage(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'folder': 'products',
    });
    developer.log('POST /uploads/image file=$filePath', name: 'products');

    final response = await _dio.post<dynamic>(
      '/uploads/image',
      data: form,
      // Without this the multipart boundary never reaches the server and the
      // file arrives empty.
      options: Options(contentType: 'multipart/form-data'),
    );
    final url = (_asMap(response.data)['url'] ?? '').toString();
    developer.log('upload OK -> $url', name: 'products');
    return url;
  }

  @override
  Future<List<ProductModel>> getProducts() async {
    final response = await _dio.get<dynamic>('/food/restaurant/menu');
    final menu = _asMap(_asMap(response.data)['menu']);

    final products = <ProductModel>[];
    for (final section in _asList(menu['sections'])) {
      // Subsections exist once a category has children; their items would be
      // missed entirely by reading `items` alone.
      for (final item in _asList(section['items'])) {
        products.add(_toProduct(item));
      }
      for (final sub in _asList(section['subsections'])) {
        for (final item in _asList(sub['items'])) {
          products.add(_toProduct(item));
        }
      }
    }

    // The same product cannot appear twice, but a product filed under a
    // category *and* its parent would. Keyed by id so it is listed once.
    final byId = {for (final p in products) p.id: p};
    return byId.values.toList();
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final response = await _dio.get<dynamic>('/food/restaurant/categories');
    final data = response.data;
    final list = data is List ? data : _asList(_asMap(data)['categories']);

    return list
        .map(
          (c) => CategoryModel(
            id: (c['_id'] ?? c['id'] ?? '').toString(),
            name: (c['name'] ?? '').toString(),
            itemCount: _asNum(c['itemCount'])?.toInt() ?? 0,
            isActive: c['isActive'] != false,
            iconName: _nullIfEmpty(c['image']),
            foodTypeScope: (c['foodTypeScope'] ?? 'Both').toString(),
          ),
        )
        .toList();
  }

  @override
  Future<void> toggleProductAvailability(String productId, bool isAvailable) =>
      _dio.patch<dynamic>(
        '/food/restaurant/foods/$productId',
        data: {'isAvailable': isAvailable},
      );

  @override
  Future<void> updateProduct(ProductModel product, {ProductModel? original}) {
    final body = _toWire(product);
    if (original != null) {
      final before = _toWire(original);
      body.removeWhere(
        (key, value) => _sameWireValue(before[key], value),
      );
      if (body.isEmpty) return Future.value();
    }
    return _dio.patch<dynamic>(
      '/food/restaurant/foods/${product.id}',
      data: body,
    );
  }

  /// Wire values are scalars or lists of scalars/maps, so a structural compare
  /// is enough — and `==` alone would treat two equal lists as different.
  static bool _sameWireValue(Object? a, Object? b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_sameWireValue(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_sameWireValue(a[key], b[key])) return false;
      }
      return true;
    }
    return a == b;
  }

  @override
  Future<void> addProduct(ProductModel product) =>
      _dio.post<dynamic>('/food/restaurant/foods', data: _toWire(product));

  @override
  Future<void> addCategory(CategoryModel category) => _dio.post<dynamic>(
    '/food/restaurant/categories',
    // `foodTypeScope` is mandatory server-side. Omitting it returned
    // "Category diet type is required" and no category was ever created.
    data: {
      'name': category.name,
      'isActive': category.isActive,
      'foodTypeScope': category.foodTypeScope,
    },
  );

  @override
  Future<void> toggleCategoryActive(String categoryId, bool isActive) =>
      _dio.patch<dynamic>(
        '/food/restaurant/categories/$categoryId',
        data: {'isActive': isActive},
      );

  @override
  Future<void> renameCategory(String categoryId, String name) =>
      _dio.patch<dynamic>(
        '/food/restaurant/categories/$categoryId',
        data: {'name': name},
      );

  @override
  Future<void> deleteCategory(String categoryId) =>
      _dio.delete<dynamic>('/food/restaurant/categories/$categoryId');

  @override
  Future<void> deleteProduct(String productId) =>
      _dio.delete<dynamic>('/food/restaurant/foods/$productId');

  ProductModel _toProduct(Map<String, dynamic> json) {
    final variants = _asList(json['variants'] ?? json['variations'])
        .map(
          (v) => ProductVariant(
            name: (v['name'] ?? '').toString(),
            price: _asNum(v['price'])?.toDouble() ?? 0,
            otherPrice: _positiveOrNull(_asNum(v['otherPrice'])?.toDouble()),
          ),
        )
        .where((v) => v.name.isNotEmpty)
        .toList();

    final images = [
      for (final url in (json['images'] is List ? json['images'] as List : []))
        if (url.toString().trim().isNotEmpty) url.toString().trim(),
    ];
    final primary = _nullIfEmpty(json['image']);
    // The primary photo is not always echoed inside `images`; leading with it
    // keeps the detail screen's first slide and the list thumbnail identical.
    if (primary != null && !images.contains(primary)) images.insert(0, primary);

    return ProductModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      categoryId: (json['categoryId'] ?? '').toString(),
      categoryName: (json['categoryName'] ?? json['category'] ?? '').toString(),
      price: _asNum(json['price'])?.toDouble() ?? 0,
      // The struck-through price is the printed MRP. `otherPrice` is a
      // compare-against-other-platforms figure and is not what a shopper is
      // shown, so it is only a fallback for products predating MRP.
      originalPrice:
          _asNum(json['mrp'])?.toDouble() ??
          _positiveOrNull(_asNum(json['otherPrice'])?.toDouble()),
      // A grocery line's "unit" is its pack size.
      unit: (json['packSize'] ?? '').toString(),
      isAvailable: json['isAvailable'] != false,
      // null means the product is not stock-tracked at all, which is different
      // from none in stock. The screen has no way to draw that distinction, so
      // untracked reads as 0 and the seller sets a real count to begin tracking.
      stockQuantity: _asNum(json['stockQty'])?.toInt() ?? 0,
      imageUrl: primary ?? (images.isEmpty ? null : images.first),
      images: images,
      description: (json['description'] ?? '').toString(),
      brand: (json['brand'] ?? '').toString(),
      foodType: (json['foodType'] ?? 'Veg').toString(),
      gstRate: _asNum(json['gstRate'])?.toDouble(),
      lowStockThreshold: _asNum(json['lowStockThreshold'])?.toInt(),
      maxQtyPerOrder: _asNum(json['maxQtyPerOrder'])?.toInt(),
      preparationTime: (json['preparationTime'] ?? '').toString(),
      isRecommended: json['isRecommended'] == true,
      variants: variants,
      approval: ProductApproval.parse(json['approvalStatus']?.toString()),
      rejectionReason: (json['rejectionReason'] ?? '').toString(),
      rating: _asNum(json['rating'])?.toDouble() ?? 0,
      totalRatings: _asNum(json['totalRatings'])?.toInt() ?? 0,
    );
  }

  /// The create/update body.
  ///
  /// Only keys the backend's `updateRestaurantFood` actually reads are sent —
  /// anything else is silently dropped there, which is how `brand` used to be
  /// collected by the form and never saved.
  Map<String, dynamic> _toWire(ProductModel p) => {
    'name': p.name,
    if (p.categoryId.isNotEmpty) 'categoryId': p.categoryId,
    if (p.categoryName.isNotEmpty) 'categoryName': p.categoryName,
    // A product with variants derives its price from them, and the backend
    // rejects a base-price edit on one.
    if (p.hasVariants)
      'variants': [
        for (final v in p.variants)
          {
            'name': v.name,
            'price': v.price,
            if (v.otherPrice != null) 'otherPrice': v.otherPrice,
          },
      ]
    else
      'price': p.price,
    'mrp': p.originalPrice,
    'packSize': p.unit,
    'brand': p.brand,
    'foodType': p.foodType,
    'gstRate': p.gstRate,
    'isAvailable': p.isAvailable,
    // 0 is a real count (out of stock); the backend treats null as untracked,
    // so only send a number the seller actually entered.
    'stockQty': p.stockQuantity,
    'lowStockThreshold': p.lowStockThreshold,
    'maxQtyPerOrder': p.maxQtyPerOrder,
    'preparationTime': p.preparationTime,
    'isRecommended': p.isRecommended,
    'description': p.description,
    if (p.images.isNotEmpty) 'images': p.images,
    if (p.imageUrl != null && p.imageUrl!.isNotEmpty) 'image': p.imageUrl,
  };

  static double? _positiveOrNull(double? v) => (v == null || v <= 0) ? null : v;

  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<Map<String, dynamic>> _asList(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  static num? _asNum(dynamic v) =>
      v is num ? v : num.tryParse((v ?? '').toString());

  static String? _nullIfEmpty(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}
