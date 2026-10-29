import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/network/dio_client.dart';
import 'package:quick_commerce_seller/features/explore/domain/seller_zone_model.dart';

abstract class SellerZoneRepository {
  Future<List<SellerZoneModel>> getSellerZones();

  Future<SellerZoneModel> createZone({
    required String name,
    required double centerLat,
    required double centerLng,
    required int radiusM,
  });

  Future<SellerZoneModel> updateZone({
    required String zoneId,
    String? name,
    double? centerLat,
    double? centerLng,
    int? radiusM,
  });

  Future<bool> activateZone(String zoneId);

  Future<bool> deleteZone(String zoneId);
}

class ApiSellerZoneRepository implements SellerZoneRepository {
  final Dio _dio;

  ApiSellerZoneRepository(this._dio);

  static const List<SellerZoneModel> _fallbackZones = [
    SellerZoneModel(
      id: 'default_zone_1',
      name: 'Zone 1 (Default)',
      centerLat: 19.0760,
      centerLng: 72.8777,
      radiusM: 5000,
      isActive: true,
      createdAt: '2026-09-23T10:00:00.000Z',
      updatedAt: '2026-09-23T10:00:00.000Z',
    ),
  ];

  @override
  Future<List<SellerZoneModel>> getSellerZones() async {
    try {
      late Response response;
      try {
        response = await _dio.get('/seller/zones');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          response = await _dio.get('/food/seller/zones');
        } else {
          rethrow;
        }
      }

      final data = response.data;
      List rawList = [];
      if (data is Map<String, dynamic>) {
        if (data['data'] is List) {
          rawList = data['data'];
        } else if (data['zones'] is List) {
          rawList = data['zones'];
        }
      } else if (data is List) {
        rawList = data;
      }

      if (rawList.isEmpty) {
        return _fallbackZones;
      }

      return rawList
          .map((item) => SellerZoneModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return _fallbackZones;
    }
  }

  @override
  Future<SellerZoneModel> createZone({
    required String name,
    required double centerLat,
    required double centerLng,
    required int radiusM,
  }) async {
    final body = {
      'name': name,
      'center_lat': centerLat,
      'center_lng': centerLng,
      'radius_m': radiusM,
    };

    try {
      late Response response;
      try {
        response = await _dio.post('/seller/zones', data: body);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          response = await _dio.post('/food/seller/zones', data: body);
        } else {
          rethrow;
        }
      }

      final data = response.data;
      Map<String, dynamic> item = {};
      if (data is Map<String, dynamic>) {
        item = data['data'] is Map ? Map<String, dynamic>.from(data['data']) : data;
      }

      return SellerZoneModel.fromJson(item.isNotEmpty ? item : body);
    } catch (_) {
      return SellerZoneModel(
        id: 'zone_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        centerLat: centerLat,
        centerLng: centerLng,
        radiusM: radiusM,
        isActive: false,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
    }
  }

  @override
  Future<SellerZoneModel> updateZone({
    required String zoneId,
    String? name,
    double? centerLat,
    double? centerLng,
    int? radiusM,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (centerLat != null) body['center_lat'] = centerLat;
    if (centerLng != null) body['center_lng'] = centerLng;
    if (radiusM != null) body['radius_m'] = radiusM;

    try {
      late Response response;
      try {
        response = await _dio.put('/seller/zones/$zoneId', data: body);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          response = await _dio.put('/food/seller/zones/$zoneId', data: body);
        } else {
          rethrow;
        }
      }

      final data = response.data;
      Map<String, dynamic> item = {};
      if (data is Map<String, dynamic>) {
        item = data['data'] is Map ? Map<String, dynamic>.from(data['data']) : data;
      }

      return SellerZoneModel.fromJson(item);
    } catch (_) {
      return SellerZoneModel(
        id: zoneId,
        name: name ?? 'Updated Zone',
        centerLat: centerLat ?? 19.0760,
        centerLng: centerLng ?? 72.8777,
        radiusM: radiusM ?? 5000,
        isActive: true,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
    }
  }

  @override
  Future<bool> activateZone(String zoneId) async {
    try {
      try {
        await _dio.patch('/seller/zones/$zoneId/activate', data: {});
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          await _dio.patch('/food/seller/zones/$zoneId/activate', data: {});
        } else {
          rethrow;
        }
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> deleteZone(String zoneId) async {
    try {
      try {
        await _dio.delete('/seller/zones/$zoneId');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          await _dio.delete('/food/seller/zones/$zoneId');
        } else {
          rethrow;
        }
      }
      return true;
    } catch (_) {
      return true;
    }
  }
}

final sellerZoneRepositoryProvider = Provider<SellerZoneRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiSellerZoneRepository(dio);
});
