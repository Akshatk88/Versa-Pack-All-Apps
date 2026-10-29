class CategoryModel {
  final String id;
  final String name;
  final int itemCount;
  final bool isActive;
  final String? iconName;

  /// Which diets this category covers: 'Veg', 'Non-Veg' or 'Both'.
  ///
  /// Required by the backend on create — it rejects the request outright
  /// without one, which is why category creation used to fail silently.
  final String foodTypeScope;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.itemCount,
    this.isActive = true,
    this.iconName,
    this.foodTypeScope = 'Both',
  });

  CategoryModel copyWith({
    String? name,
    int? itemCount,
    bool? isActive,
    String? iconName,
    String? foodTypeScope,
  }) {
    return CategoryModel(
      id: id,
      name: name ?? this.name,
      itemCount: itemCount ?? this.itemCount,
      isActive: isActive ?? this.isActive,
      iconName: iconName ?? this.iconName,
      foodTypeScope: foodTypeScope ?? this.foodTypeScope,
    );
  }
}

/// One purchasable size of a product ("500 g", "1 kg").
///
/// The backend derives a product's headline price from its variants, and
/// rejects a base-price edit on a product that has any — so these are the
/// prices for such an item, not decoration.
class ProductVariant {
  const ProductVariant({
    required this.name,
    required this.price,
    this.otherPrice,
  });

  final String name;
  final double price;

  /// Compare-at price for this size. Null when none is set.
  final double? otherPrice;

  ProductVariant copyWith({String? name, double? price, double? otherPrice}) =>
      ProductVariant(
        name: name ?? this.name,
        price: price ?? this.price,
        otherPrice: otherPrice ?? this.otherPrice,
      );
}

/// Where a product stands in admin review.
///
/// Editing a name, price, photo, variant or category sends an approved product
/// back to `pending` — the seller keeps seeing it, customers do not, so the
/// state has to be visible in the app.
enum ProductApproval {
  pending,
  approved,
  rejected;

  static ProductApproval parse(String? wire) => switch (wire) {
    'pending' => ProductApproval.pending,
    'rejected' => ProductApproval.rejected,
    _ => ProductApproval.approved,
  };

  String get label => switch (this) {
    ProductApproval.pending => 'Pending approval',
    ProductApproval.rejected => 'Rejected',
    ProductApproval.approved => 'Approved',
  };
}

class ProductModel {
  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final double price;

  /// The printed MRP. Drives the struck-through price and the discount badge;
  /// the backend refuses a `price` above it.
  final double? originalPrice;

  /// Pack size — the backend's `packSize`.
  final String unit;
  final bool isAvailable;
  final int stockQuantity;

  /// Primary photo. Always the first entry of [images] when there is one.
  final String? imageUrl;
  final List<String> images;
  final String description;
  final String brand;

  /// 'Veg' or 'Non-Veg'. The backend validates against exactly these.
  final String foodType;
  final double? gstRate;
  final int? lowStockThreshold;
  final int? maxQtyPerOrder;
  final String preparationTime;
  final bool isRecommended;
  final List<ProductVariant> variants;
  final ProductApproval approval;
  final String rejectionReason;

  /// Customer rating. Read-only — the seller cannot set it.
  final double rating;
  final int totalRatings;

  const ProductModel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.price,
    this.originalPrice,
    required this.unit,
    this.isAvailable = true,
    required this.stockQuantity,
    this.imageUrl,
    this.images = const [],
    this.description = '',
    this.brand = '',
    this.foodType = 'Veg',
    this.gstRate,
    this.lowStockThreshold,
    this.maxQtyPerOrder,
    this.preparationTime = '',
    this.isRecommended = false,
    this.variants = const [],
    this.approval = ProductApproval.approved,
    this.rejectionReason = '',
    this.rating = 0,
    this.totalRatings = 0,
  });

  /// Saving off a product with variants means editing the variants; the
  /// backend throws on a base-price update for one.
  bool get hasVariants => variants.isNotEmpty;

  /// Percentage off the MRP, or null when there is no genuine discount.
  /// "Discount" is not a stored field — it is this relationship.
  int? get discountPercent {
    final mrp = originalPrice;
    if (mrp == null || mrp <= 0 || price >= mrp) return null;
    return (((mrp - price) / mrp) * 100).round();
  }

  bool get isLowStock =>
      stockQuantity > 0 && stockQuantity <= (lowStockThreshold ?? 10);

  ProductModel copyWith({
    String? name,
    String? categoryId,
    String? categoryName,
    double? price,
    double? originalPrice,
    bool clearOriginalPrice = false,
    String? unit,
    bool? isAvailable,
    int? stockQuantity,
    String? imageUrl,
    List<String>? images,
    String? description,
    String? brand,
    String? foodType,
    double? gstRate,
    bool clearGstRate = false,
    int? lowStockThreshold,
    int? maxQtyPerOrder,
    String? preparationTime,
    bool? isRecommended,
    List<ProductVariant>? variants,
    ProductApproval? approval,
    String? rejectionReason,
  }) {
    return ProductModel(
      id: id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      price: price ?? this.price,
      originalPrice: clearOriginalPrice
          ? null
          : (originalPrice ?? this.originalPrice),
      unit: unit ?? this.unit,
      isAvailable: isAvailable ?? this.isAvailable,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      description: description ?? this.description,
      brand: brand ?? this.brand,
      foodType: foodType ?? this.foodType,
      gstRate: clearGstRate ? null : (gstRate ?? this.gstRate),
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      maxQtyPerOrder: maxQtyPerOrder ?? this.maxQtyPerOrder,
      preparationTime: preparationTime ?? this.preparationTime,
      isRecommended: isRecommended ?? this.isRecommended,
      variants: variants ?? this.variants,
      approval: approval ?? this.approval,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rating: rating,
      totalRatings: totalRatings,
    );
  }
}
