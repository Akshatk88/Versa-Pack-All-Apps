import 'package:quick_commerce_seller/features/explore/domain/store_settings_model.dart';

abstract class ExploreRepository {
  Future<StoreProfileModel> getStoreProfile();
  Future<void> updateStoreProfile(StoreProfileModel profile);
  Future<void> setStoreOnlineStatus(bool isOnline, {String reason = ''});
  Future<List<DayTimingModel>> getOutletTimings();
  Future<void> updateOutletTimings(List<DayTimingModel> timings);
  Future<DeliverySettingsModel> getDeliverySettings();
  Future<void> updateDeliverySettings(DeliverySettingsModel settings);
}
