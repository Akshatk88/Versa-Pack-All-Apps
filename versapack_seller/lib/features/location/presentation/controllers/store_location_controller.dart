// import 'dart:async';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:quick_commerce_seller/features/location/data/store_location_repository.dart';
// import 'package:quick_commerce_seller/features/location/domain/store_location_status.dart';
//
// class StoreLocationNotifier extends AsyncNotifier<StoreLocationStatus> {
//   late final StoreLocationRepository _repository;
//
//   @override
//   FutureOr<StoreLocationStatus> build() async {
//     _repository = ref.watch(storeLocationRepositoryProvider);
//     return _repository.getCurrentLocationStatus();
//   }
//
//   Future<void> loadStatus() async {
//     state = const AsyncValue.loading();
//     state = await AsyncValue.guard(() => _repository.getCurrentLocationStatus());
//   }
//
//   Future<bool> updateLocation({
//     required double lat,
//     required double lng,
//     String? shopName,
//     String? address,
//     required Function(String error) onError,
//   }) async {
//     try {
//       final updatedStatus = await _repository.updateStoreLocation(
//         lat: lat,
//         lng: lng,
//         shopName: shopName,
//         address: address,
//       );
//       state = AsyncValue.data(updatedStatus);
//       return true;
//     } on StoreLocationApiException catch (e) {
//       onError(e.message);
//       return false;
//     } catch (e) {
//       onError('Failed to update store location: ${e.toString()}');
//       return false;
//     }
//   }
// }
//
// final storeLocationNotifierProvider =
//     AsyncNotifierProvider<StoreLocationNotifier, StoreLocationStatus>(
//   StoreLocationNotifier.new,
// );

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/features/location/data/store_location_repository.dart';
import 'package:quick_commerce_seller/features/location/domain/store_location_status.dart';

class StoreLocationNotifier extends AsyncNotifier<StoreLocationStatus> {
  late final StoreLocationRepository _repository;

  @override
  FutureOr<StoreLocationStatus> build() async {
    _repository = ref.watch(storeLocationRepositoryProvider);
    return _repository.getCurrentLocationStatus();
  }

  Future<void> loadStatus() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getCurrentLocationStatus());
  }

  Future<bool> updateLocation({
    required double lat,
    required double lng,
    String? shopName,
    String? address,
    required Function(String error) onError,
  }) async {
    debugPrint('[StoreLocation] updateLocation called → lat=$lat, lng=$lng');

    try {
      final updatedStatus = await _repository.updateStoreLocation(
        lat: lat,
        lng: lng,
        shopName: shopName,
        address: address,
      );

      debugPrint(
        '[StoreLocation] updateLocation success → lat=$lat, lng=$lng, '
            'status=$updatedStatus',
      );

      state = AsyncValue.data(updatedStatus);
      return true;
    } on StoreLocationApiException catch (e) {
      debugPrint('[StoreLocation] updateLocation FAILED → lat=$lat, lng=$lng, error=${e.message}');
      onError(e.message);
      return false;
    } catch (e) {
      debugPrint('[StoreLocation] updateLocation FAILED → lat=$lat, lng=$lng, error=$e');
      onError('Failed to update store location: ${e.toString()}');
      return false;
    }
  }
}

final storeLocationNotifierProvider =
AsyncNotifierProvider<StoreLocationNotifier, StoreLocationStatus>(
  StoreLocationNotifier.new,
);
