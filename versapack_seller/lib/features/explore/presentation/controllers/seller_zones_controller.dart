import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/features/explore/data/seller_zone_repository.dart';
import 'package:quick_commerce_seller/features/explore/domain/seller_zone_model.dart';

class SellerZonesNotifier extends AsyncNotifier<List<SellerZoneModel>> {
  late final SellerZoneRepository _repository;

  @override
  FutureOr<List<SellerZoneModel>> build() async {
    _repository = ref.watch(sellerZoneRepositoryProvider);
    return _repository.getSellerZones();
  }

  Future<void> loadZones() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getSellerZones());
  }

  Future<bool> addZone({
    required String name,
    required double centerLat,
    required double centerLng,
    required int radiusM,
  }) async {
    try {
      final newZone = await _repository.createZone(
        name: name,
        centerLat: centerLat,
        centerLng: centerLng,
        radiusM: radiusM,
      );

      final current = state.value ?? [];
      bool autoActivate = current.isEmpty || newZone.isActive;

      final updatedList = current.map((z) {
        if (autoActivate) {
          return z.copyWith(isActive: false);
        }
        return z;
      }).toList();

      updatedList.add(newZone.copyWith(isActive: autoActivate ? true : newZone.isActive));
      state = AsyncValue.data(updatedList);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> editZone({
    required String zoneId,
    required String name,
    required double centerLat,
    required double centerLng,
    required int radiusM,
  }) async {
    try {
      final updated = await _repository.updateZone(
        zoneId: zoneId,
        name: name,
        centerLat: centerLat,
        centerLng: centerLng,
        radiusM: radiusM,
      );

      final current = state.value ?? [];
      state = AsyncValue.data(
        current.map((z) => z.id == zoneId ? updated.copyWith(isActive: z.isActive) : z).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> activateZone(String zoneId) async {
    try {
      await _repository.activateZone(zoneId);
      final current = state.value ?? [];
      state = AsyncValue.data(
        current.map((z) => z.copyWith(isActive: z.id == zoneId)).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteZone(String zoneId) async {
    try {
      await _repository.deleteZone(zoneId);
      final current = state.value ?? [];
      final remaining = current.where((z) => z.id != zoneId).toList();

      if (remaining.isNotEmpty && !remaining.any((z) => z.isActive)) {
        remaining[remaining.length - 1] = remaining.last.copyWith(isActive: true);
      }

      state = AsyncValue.data(remaining);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final sellerZonesNotifierProvider =
    AsyncNotifierProvider<SellerZonesNotifier, List<SellerZoneModel>>(
  SellerZonesNotifier.new,
);
