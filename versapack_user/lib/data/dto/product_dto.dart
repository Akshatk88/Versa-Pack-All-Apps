import '../../core/network/media_url.dart';
import 'json_reader.dart';

/// Mirrors an item from `GET /food/search/products` (the richest catalog
/// surface: it alone returns mrp, stockQty, brand, packSize and the seller).
///
/// It also parses items from `/restaurant/restaurants/:id/menu` and
/// `/restaurant/public/foods`, which are subsets of the same shape.
class ProductDto {
  const ProductDto({
    required this.id,
    required this.name,
    required this.price,
    this.otherPrice,
    this.mrp,
    this.description = '',
    this.image = '',
    this.images = const [],
    this.categoryId = '',
    this.categoryName = '',
    this.brand = '',
    this.packSize = '',
    this.foodType = '',
    this.isAvailable = true,
    this.inStock,
    this.stockQty,
    this.maxQtyPerOrder,
    this.rating = 0,
    this.totalRatings = 0,
    this.variants = const [],
    this.restaurantId = '',
    this.seller,
  });

  final String id;
  final String name;
  final double price;
  final double? otherPrice;
  final double? mrp;
  final String description;
  final String image;
  final List<String> images;
  final String categoryId;
  final String categoryName;
  final String brand;
  final String packSize;
  final String foodType;
  final bool isAvailable;
  final bool? inStock;
  final int? stockQty;
  final int? maxQtyPerOrder;
  final double rating;
  final int totalRatings;
  final List<ProductVariantDto> variants;
  final String restaurantId;
  final SellerDto? seller;

  factory ProductDto.fromJson(Map<String, dynamic> json) {
    final seller = json.mapOrNull('seller');
    return ProductDto(
      id: json.id(),
      name: json.str('name'),
      price: json.dbl('price'),
      otherPrice: json.doubleOrNull('otherPrice'),
      mrp: json.doubleOrNull('mrp'),
      description: json.str('description'),
      image: json.imageUrl('image'),
      images: json.strings('images').map(MediaUrl.resolve).toList(),
      categoryId: json.id(const ['categoryId']),
      categoryName: json.firstStr(['categoryName', 'category']),
      brand: json.str('brand'),
      packSize: json.str('packSize'),
      foodType: json.str('foodType'),
      isAvailable: json.boolean('isAvailable', true),
      inStock: json['inStock'] == null ? null : json.boolean('inStock', true),
      stockQty: json.intOrNull('stockQty'),
      maxQtyPerOrder: json.intOrNull('maxQtyPerOrder'),
      rating: json.dbl('rating'),
      totalRatings: json.integer('totalRatings'),
      variants: json
          .objects('variants')
          .map(ProductVariantDto.fromJson)
          .where((v) => v.name.isNotEmpty && v.price > 0)
          .toList(),
      restaurantId: json.id(const ['restaurantId']),
      seller: seller == null ? null : SellerDto.fromJson(seller),
    );
  }
}

class ProductVariantDto {
  const ProductVariantDto({
    required this.id,
    required this.name,
    required this.price,
    this.otherPrice,
  });

  final String id;
  final String name;
  final double price;
  final double? otherPrice;

  factory ProductVariantDto.fromJson(Map<String, dynamic> json) => ProductVariantDto(
        id: json.id(),
        name: json.str('name'),
        price: json.dbl('price'),
        otherPrice: json.doubleOrNull('otherPrice'),
      );
}

/// The fulfilling store, embedded in `/search/products` responses.
class SellerDto {
  const SellerDto({
    required this.id,
    this.name = '',
    this.image = '',
    this.rating = 0,
    this.isAcceptingOrders = true,
    this.deliveryMinutes,
  });

  final String id;
  final String name;
  final String image;
  final double rating;
  final bool isAcceptingOrders;
  final int? deliveryMinutes;

  factory SellerDto.fromJson(Map<String, dynamic> json) => SellerDto(
        id: json.id(),
        name: json.firstStr(['name', 'restaurantName']),
        image: json.imageUrl('image').isNotEmpty
            ? json.imageUrl('image')
            : json.imageUrl('profileImage'),
        rating: json.dbl('rating'),
        isAcceptingOrders: json.boolean('isAcceptingOrders', true),
        deliveryMinutes: json.intOrNull('estimatedDeliveryTimeMinutes'),
      );
}
