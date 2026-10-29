import 'product_variant.dart';

/// Stock posture of a catalog item. `stockQty == null` means the seller does
/// not track stock for it, which the backend treats as unlimited.
enum StockStatus { inStock, limited, outOfStock }

/// A sellable catalog item.
///
/// Maps onto the backend's food item. The grocery vocabulary in the UI
/// (`unitLabel`, `mrp`, `brand`) all come from real fields on that model.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.sellerId,
    this.comparePrice,
    this.mrp,
    this.description = '',
    this.imageUrl = '',
    this.images = const [],
    this.categoryId = '',
    this.categoryName = '',
    this.brand = '',
    this.packSize = '',
    this.isVeg = true,
    this.isAvailable = true,
    this.stockQty,
    this.maxQtyPerOrder,
    this.rating = 0,
    this.ratingCount = 0,
    this.variants = const [],
    this.sellerName = '',
    this.sellerImageUrl = '',
    this.deliveryMinutes,
    this.sellerAcceptingOrders = true,
  });

  final String id;
  final String name;
  final double price;

  /// Compare-at price from the seller (`otherPrice`).
  final double? comparePrice;

  /// Manufacturer MRP, when the seller has entered one.
  final double? mrp;

  final String description;
  final String imageUrl;
  final List<String> images;
  final String categoryId;
  final String categoryName;
  final String brand;
  final String packSize;
  final bool isVeg;
  final bool isAvailable;
  final int? stockQty;
  final int? maxQtyPerOrder;
  final double rating;
  final int ratingCount;
  final List<ProductVariant> variants;

  /// The dark store / restaurant fulfilling this item. A cart may only contain
  /// items from one seller, which is what makes single-drop delivery possible.
  final String sellerId;
  final String sellerName;
  final String sellerImageUrl;
  final int? deliveryMinutes;
  final bool sellerAcceptingOrders;

  bool get hasVariants => variants.length > 1;

  /// The strike-through price to display, if any.
  double? get strikePrice {
    final candidates = [mrp, comparePrice].whereType<double>().where((p) => p > price);
    return candidates.isEmpty ? null : candidates.reduce((a, b) => a > b ? a : b);
  }

  bool get isDiscounted => strikePrice != null;

  int get discountPercent {
    final strike = strikePrice;
    if (strike == null) return 0;
    return (((strike - price) / strike) * 100).round();
  }

  StockStatus get stockStatus {
    if (!isAvailable) return StockStatus.outOfStock;
    final qty = stockQty;
    if (qty == null) return StockStatus.inStock;
    if (qty <= 0) return StockStatus.outOfStock;
    if (qty <= 5) return StockStatus.limited;
    return StockStatus.inStock;
  }

  bool get isPurchasable => stockStatus != StockStatus.outOfStock;

  /// "500 g" / "1 L" style label; falls back to the brand when unset.
  String get unitLabel => packSize.trim().isNotEmpty ? packSize.trim() : '1 pack';

  List<String> get gallery {
    final all = [
      ...images.where((i) => i.trim().isNotEmpty),
      if (imageUrl.trim().isNotEmpty) imageUrl,
    ];
    final seen = <String>{};
    return all.where(seen.add).toList();
  }

  /// Ceiling for the quantity stepper: seller cap and remaining stock, else 10.
  int get maxOrderableQty {
    final caps = <int>[
      if (maxQtyPerOrder != null && maxQtyPerOrder! > 0) maxQtyPerOrder!,
      if (stockQty != null && stockQty! > 0) stockQty!,
    ];
    if (caps.isEmpty) return 10;
    return caps.reduce((a, b) => a < b ? a : b);
  }

  Product copyWith({double? price, int? stockQty, bool? isAvailable}) => Product(
        id: id,
        name: name,
        price: price ?? this.price,
        sellerId: sellerId,
        comparePrice: comparePrice,
        mrp: mrp,
        description: description,
        imageUrl: imageUrl,
        images: images,
        categoryId: categoryId,
        categoryName: categoryName,
        brand: brand,
        packSize: packSize,
        isVeg: isVeg,
        isAvailable: isAvailable ?? this.isAvailable,
        stockQty: stockQty ?? this.stockQty,
        maxQtyPerOrder: maxQtyPerOrder,
        rating: rating,
        ratingCount: ratingCount,
        variants: variants,
        sellerName: sellerName,
        sellerImageUrl: sellerImageUrl,
        deliveryMinutes: deliveryMinutes,
        sellerAcceptingOrders: sellerAcceptingOrders,
      );

  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
