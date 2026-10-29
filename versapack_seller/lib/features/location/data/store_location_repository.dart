import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/network/dio_client.dart';
import 'package:quick_commerce_seller/features/location/domain/store_location_status.dart';

class StoreLocationApiException implements Exception {
  final String message;
  const StoreLocationApiException(this.message);

  @override
  String toString() => message;
}

abstract class StoreLocationRepository {
  Future<StoreLocationStatus> getCurrentLocationStatus();

  Future<StoreLocationStatus> updateStoreLocation({
    required double lat,
    required double lng,
    String? shopName,
    String? address,
  });
}

class ApiStoreLocationRepository implements StoreLocationRepository {
  final Dio _dio;

  ApiStoreLocationRepository(this._dio);

  static const StoreLocationStatus _fallbackStatus = StoreLocationStatus(
    name: 'My Store',
    locationUpdateStatus: 'none',
    locationRejectionReason: '',
    location: StoreLocationInfo(
      latitude: 19.0760,
      longitude: 72.8777,
      address: 'Shop 12, Main Market, Mumbai',
    ),
  );

  @override
  Future<StoreLocationStatus> getCurrentLocationStatus() async {
    try {
      final response = await _dio.get('/food/restaurant/current');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final restaurant = data['restaurant'] ?? data['data']?['restaurant'] ?? data['data'];
        if (restaurant is Map) {
          return StoreLocationStatus.fromRestaurantJson(Map<String, dynamic>.from(restaurant));
        }
      }
      return _fallbackStatus;
    } catch (_) {
      return _fallbackStatus;
    }
  }

  @override
  Future<StoreLocationStatus> updateStoreLocation({
    required double lat,
    required double lng,
    String? shopName,
    String? address,
  }) async {
    final body = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      if (shopName != null && shopName.isNotEmpty) 'shop_name': shopName,
      if (address != null && address.isNotEmpty) 'address': address,
    };

    try {
      late Response response;
      try {
        response = await _dio.patch('/food/restaurant/location', data: body);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          response = await _dio.patch('/food/restaurant/profile', data: {
            'pendingLocation': {
              'latitude': lat,
              'longitude': lng,
              'address': address ?? '',
            },
            'locationUpdateStatus': 'pending',
          });
        } else {
          final serverMsg = e.response?.data?['message']?.toString();
          if (serverMsg != null && serverMsg.isNotEmpty) {
            throw StoreLocationApiException(serverMsg);
          }
          rethrow;
        }
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final restaurant = data['restaurant'] ?? data['data']?['restaurant'] ?? data['data'];
        if (restaurant is Map) {
          return StoreLocationStatus.fromRestaurantJson(Map<String, dynamic>.from(restaurant));
        }
      }

      return StoreLocationStatus(
        name: shopName ?? 'My Store',
        locationUpdateStatus: 'pending',
        locationRejectionReason: '',
        location: StoreLocationInfo(latitude: lat, longitude: lng, address: address ?? ''),
        pendingLocation: StoreLocationInfo(latitude: lat, longitude: lng, address: address ?? ''),
      );
    } on StoreLocationApiException {
      rethrow;
    } catch (e) {
      throw StoreLocationApiException(e.toString());
    }
  }
}

final storeLocationRepositoryProvider = Provider<StoreLocationRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiStoreLocationRepository(dio);
});
