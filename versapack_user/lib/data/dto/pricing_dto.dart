import 'json_reader.dart';

/// The `pricing` object returned by `POST /food/orders/calculate` and
/// persisted on every order. Field names mirror the backend exactly.
class PricingDto {
  const PricingDto({
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

  factory PricingDto.fromJson(Map<String, dynamic> json) => PricingDto(
        subtotal: json.dbl('subtotal'),
        tax: json.dbl('tax'),
        packagingFee: json.dbl('packagingFee'),
        deliveryFee: json.dbl('deliveryFee'),
        deliveryFeeGst: json.dbl('deliveryFeeGst'),
        platformFee: json.dbl('platformFee'),
        quickDeliveryFee: json.dbl('quickDeliveryFee'),
        discount: json.dbl('discount'),
        total: json.dbl('total'),
        currency: json.str('currency', 'INR'),
        couponCode: json.str('couponCode').isEmpty ? null : json.str('couponCode'),
        deliveryMode: json.str('deliveryMode', 'basic'),
        distanceKm: json.doubleOrNull('distanceKm'),
        deliveryPromiseMinutes: json.intOrNull('deliveryPromiseMinutes'),
        deliveryFeeMessage: json.mapAt('deliveryFeeBreakdown').str('message'),
      );

  /// Echoed back on `POST /orders`. The server recomputes everything and only
  /// reads `couponCode`, but we send the full object as the contract expects.
  Map<String, dynamic> toJson() => {
        'subtotal': subtotal,
        'tax': tax,
        'packagingFee': packagingFee,
        'deliveryFee': deliveryFee,
        'platformFee': platformFee,
        'discount': discount,
        'total': total,
        'currency': currency,
        'couponCode': couponCode,
      };
}

class PriceChangeDto {
  const PriceChangeDto({
    required this.itemId,
    required this.name,
    required this.previousPrice,
    required this.price,
  });

  final String itemId;
  final String name;
  final double previousPrice;
  final double price;

  factory PriceChangeDto.fromJson(Map<String, dynamic> json) => PriceChangeDto(
        itemId: json.str('itemId'),
        name: json.str('name'),
        previousPrice: json.dbl('previousPrice'),
        price: json.dbl('price'),
      );
}
