import 'cart_item.dart';
import 'coupon.dart';
import 'product.dart';

/// The server-computed bill. Every number here comes from
/// `POST /orders/calculate` — the client never derives or adjusts them.
class CartPricing {
  const CartPricing({
    this.subtotal = 0,
    this.tax = 0,
    this.packagingFee = 0,
    this.deliveryFee = 0,
    this.deliveryFeeGst = 0,
    this.platformFee = 0,
    this.quickDeliveryFee = 0,
    this.discount = 0,
    this.total = 0,
    this.currency = 'INR',
    this.couponCode,
    this.deliveryMode = 'basic',
    this.distanceKm,
    this.deliveryPromiseMinutes,
    this.deliveryFeeMessage = '',
  });

  final double subtotal;
  final double tax;
  final double packagingFee;
  final double deliveryFee;
  final double deliveryFeeGst;
  final double platformFee;
  final double quickDeliveryFee;
  final double discount;
  final double total;
  final String currency;
  final String? couponCode;
  final String deliveryMode;
  final double? distanceKm;
  final int? deliveryPromiseMinutes;
  final String deliveryFeeMessage;

  bool get isFreeDelivery => deliveryFee <= 0;
  bool get hasDiscount => discount > 0;

  static const empty = CartPricing();
}

/// A price that moved between the cart and the pricing call — surfaced to the
/// user before they pay rather than silently changing the total.
class PriceChange {
  const PriceChange({
    required this.itemId,
    required this.name,
    required this.previousPrice,
    required this.price,
  });

  final String itemId;
  final String name;
  final double previousPrice;
  final double price;

  bool get increased => price > previousPrice;
}

/// The cart. Single-seller by design: quick commerce ships one drop per order,
/// and the backend's order model carries exactly one `restaurantId`.
class Cart {
  const Cart({
    this.items = const [],
    this.sellerId = '',
    this.sellerName = '',
    this.appliedCoupon,
    this.pricing = CartPricing.empty,
    this.priceChanges = const [],
    this.deliveryMode = 'basic',
  });

  final List<CartItem> items;
  final String sellerId;
  final String sellerName;
  final Coupon? appliedCoupon;
  final CartPricing pricing;
  final List<PriceChange> priceChanges;
  final String deliveryMode;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  int get lineCount => items.length;

  /// Local sum used only for optimistic UI before the server prices the cart.
  double get provisionalSubtotal =>
      items.fold(0, (sum, i) => sum + i.lineTotal);

  /// Effective total payable: server-calculated total if > 0, otherwise provisional subtotal.
  double get effectiveTotal => pricing.total > 0 ? pricing.total : provisionalSubtotal;

  double get provisionalStrikeTotal =>
      items.fold(0, (sum, i) => sum + i.lineStrikeTotal);

  double get provisionalSavings {
    final saved = provisionalStrikeTotal - provisionalSubtotal;
    return saved > 0 ? saved : 0;
  }

  /// Total savings the customer sees: item-level plus any coupon discount.
  double get totalSavings => provisionalSavings + pricing.discount;

  int quantityOf(String productId) => items
      .where((i) => i.product.id == productId)
      .fold(0, (sum, i) => sum + i.quantity);

  CartItem? lineById(String lineId) {
    for (final item in items) {
      if (item.lineId == lineId) return item;
    }
    return null;
  }

  /// True when [product] comes from a different seller than the current cart.
  bool conflictsWith(Product product) =>
      isNotEmpty && sellerId.isNotEmpty && sellerId != product.sellerId;

  static const empty = Cart();

  Cart copyWith({
    List<CartItem>? items,
    String? sellerId,
    String? sellerName,
    Coupon? appliedCoupon,
    bool clearCoupon = false,
    CartPricing? pricing,
    List<PriceChange>? priceChanges,
    String? deliveryMode,
  }) =>
      Cart(
        items: items ?? this.items,
        sellerId: sellerId ?? this.sellerId,
        sellerName: sellerName ?? this.sellerName,
        appliedCoupon: clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
        pricing: pricing ?? this.pricing,
        priceChanges: priceChanges ?? this.priceChanges,
        deliveryMode: deliveryMode ?? this.deliveryMode,
      );
}
