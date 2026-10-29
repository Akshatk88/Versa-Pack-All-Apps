import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/features/explore/domain/seller_zone_model.dart';

void main() {
  group('SellerZoneModel Unit Tests', () {
    test('fromJson parses standard JSON correctly', () {
      final json = {
        'id': '6741abf2e12a9b0012345678',
        'seller_id': '6741a001e12a9b0087654321',
        'name': 'Zone 1 (Default)',
        'center_lat': 19.0760,
        'center_lng': 72.8777,
        'radius_m': 5000,
        'is_active': true,
        'created_at': '2026-09-23T10:00:00.000Z',
        'updated_at': '2026-09-23T10:00:00.000Z',
      };

      final zone = SellerZoneModel.fromJson(json);

      expect(zone.id, '6741abf2e12a9b0012345678');
      expect(zone.sellerId, '6741a001e12a9b0087654321');
      expect(zone.name, 'Zone 1 (Default)');
      expect(zone.centerLat, 19.0760);
      expect(zone.centerLng, 72.8777);
      expect(zone.radiusM, 5000);
      expect(zone.isActive, true);
      expect(zone.createdAt, '2026-09-23T10:00:00.000Z');
      expect(zone.updatedAt, '2026-09-23T10:00:00.000Z');
    });

    test('toJson produces expected Map', () {
      const zone = SellerZoneModel(
        id: 'zone_123',
        sellerId: 'seller_456',
        name: 'North Zone',
        centerLat: 28.6139,
        centerLng: 77.2090,
        radiusM: 3000,
        isActive: false,
        createdAt: '2026-09-23T12:00:00.000Z',
        updatedAt: '2026-09-23T12:00:00.000Z',
      );

      final json = zone.toJson();

      expect(json['id'], 'zone_123');
      expect(json['seller_id'], 'seller_456');
      expect(json['name'], 'North Zone');
      expect(json['center_lat'], 28.6139);
      expect(json['center_lng'], 77.2090);
      expect(json['radius_m'], 3000);
      expect(json['is_active'], false);
    });

    test('copyWith updates specific properties', () {
      const zone = SellerZoneModel(
        id: '1',
        name: 'Old Name',
        centerLat: 10.0,
        centerLng: 20.0,
        radiusM: 1000,
        isActive: false,
        createdAt: '',
        updatedAt: '',
      );

      final updated = zone.copyWith(name: 'New Name', isActive: true);

      expect(updated.id, '1');
      expect(updated.name, 'New Name');
      expect(updated.isActive, true);
      expect(updated.radiusM, 1000);
    });
  });
}
