import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/providers/repository_providers.dart';
import 'package:quick_commerce_seller/features/explore/domain/explore_repository.dart';
import 'package:quick_commerce_seller/features/explore/domain/store_settings_model.dart';

final storeProfileProvider =
    AsyncNotifierProvider<StoreProfileController, StoreProfileModel>(
      StoreProfileController.new,
    );

class StoreProfileController extends AsyncNotifier<StoreProfileModel> {
  late final ExploreRepository _repository;

  @override
  Future<StoreProfileModel> build() async {
    _repository = ref.watch(exploreRepositoryProvider);
    return _repository.getStoreProfile();
  }

  Future<void> setOnlineStatus(bool isOnline, {String reason = ''}) async {
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(isOnline: isOnline, offlineReason: reason),
      );
    }
    await _repository.setStoreOnlineStatus(isOnline, reason: reason);
  }

  Future<void> updateProfile(StoreProfileModel profile) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateStoreProfile(profile);
      return profile;
    });
  }
}

final outletTimingsProvider =
    AsyncNotifierProvider<OutletTimingsController, List<DayTimingModel>>(
      OutletTimingsController.new,
    );

class OutletTimingsController extends AsyncNotifier<List<DayTimingModel>> {
  late final ExploreRepository _repository;

  @override
  Future<List<DayTimingModel>> build() async {
    _repository = ref.watch(exploreRepositoryProvider);
    return _repository.getOutletTimings();
  }

  /// Returns whether the server accepted the schedule.
  ///
  /// Deliberately does not push a loading or error state. The screen this
  /// serves is a form built from [state]; flipping it to a spinner and then to
  /// an error page would throw away the seller's unsaved edits at the exact
  /// moment they need to correct them.
  Future<bool> updateTimings(List<DayTimingModel> timings) async {
    try {
      await _repository.updateOutletTimings(timings);
      state = AsyncValue.data(timings);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final deliverySettingsProvider =
    AsyncNotifierProvider<DeliverySettingsController, DeliverySettingsModel>(
      DeliverySettingsController.new,
    );

class DeliverySettingsController extends AsyncNotifier<DeliverySettingsModel> {
  late final ExploreRepository _repository;

  @override
  Future<DeliverySettingsModel> build() async {
    _repository = ref.watch(exploreRepositoryProvider);
    return _repository.getDeliverySettings();
  }

  Future<void> updateSettings(DeliverySettingsModel settings) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateDeliverySettings(settings);
      return settings;
    });
  }
}
