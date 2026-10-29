import '../../domain/model/cart.dart';
import '../dto/pricing_dto.dart';

abstract final class PricingMapper {
  static CartPricing toDomain(PricingDto dto) => CartPricing(
        subtotal: dto.subtotal,
        tax: dto.tax,
        packagingFee: dto.packagingFee,
        deliveryFee: dto.deliveryFee,
        deliveryFeeGst: dto.deliveryFeeGst,
        platformFee: dto.platformFee,
        quickDeliveryFee: dto.quickDeliveryFee,
        discount: dto.discount,
        total: dto.total,
        currency: dto.currency,
        couponCode: dto.couponCode,
        deliveryMode: dto.deliveryMode,
        distanceKm: dto.distanceKm,
        deliveryPromiseMinutes: dto.deliveryPromiseMinutes,
        deliveryFeeMessage: dto.deliveryFeeMessage,
      );

  static PricingDto toDto(CartPricing pricing) => PricingDto(
        subtotal: pricing.subtotal,
        tax: pricing.tax,
        packagingFee: pricing.packagingFee,
        deliveryFee: pricing.deliveryFee,
        deliveryFeeGst: pricing.deliveryFeeGst,
        platformFee: pricing.platformFee,
        quickDeliveryFee: pricing.quickDeliveryFee,
        discount: pricing.discount,
        total: pricing.total,
        currency: pricing.currency,
        couponCode: pricing.couponCode,
        deliveryMode: pricing.deliveryMode,
      );

  static PriceChange changeToDomain(PriceChangeDto dto) => PriceChange(
        itemId: dto.itemId,
        name: dto.name,
        previousPrice: dto.previousPrice,
        price: dto.price,
      );
}
