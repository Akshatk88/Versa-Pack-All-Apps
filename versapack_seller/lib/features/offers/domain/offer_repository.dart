import 'package:quick_commerce_seller/features/offers/domain/offer_model.dart';

abstract class OfferRepository {
  Future<List<CouponModel>> getCoupons();
  Future<void> toggleCouponActive(String couponId, bool isActive);
  Future<void> createCoupon(CouponModel coupon);
  Future<void> deleteCoupon(String couponId);
}
