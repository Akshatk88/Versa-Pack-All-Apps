import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/providers/repository_providers.dart';
import 'package:quick_commerce_seller/features/offers/domain/offer_model.dart';
import 'package:quick_commerce_seller/features/offers/domain/offer_repository.dart';

final offersControllerProvider =
    AsyncNotifierProvider<OffersController, List<CouponModel>>(
      OffersController.new,
    );

class OffersController extends AsyncNotifier<List<CouponModel>> {
  late final OfferRepository _repository;

  @override
  Future<List<CouponModel>> build() async {
    _repository = ref.watch(offerRepositoryProvider);
    return _repository.getCoupons();
  }

  Future<void> toggleActive(String couponId, bool isActive) async {
    final currentList = state.value ?? [];
    state = AsyncValue.data(
      currentList
          .map((c) => c.id == couponId ? c.copyWith(isActive: isActive) : c)
          .toList(),
    );
    await _repository.toggleCouponActive(couponId, isActive);
  }

  Future<void> createCoupon(CouponModel coupon) async {
    await _repository.createCoupon(coupon);
    state = await AsyncValue.guard(() => _repository.getCoupons());
  }

  Future<void> deleteCoupon(String couponId) async {
    await _repository.deleteCoupon(couponId);
    state = await AsyncValue.guard(() => _repository.getCoupons());
  }
}
