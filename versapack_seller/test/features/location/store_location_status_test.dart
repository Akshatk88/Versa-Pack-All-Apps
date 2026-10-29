import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/features/location/domain/store_location_status.dart';

void main() {
  group('StoreLocationStatus Unit Tests', () {
    test('fromRestaurantJson parses live and pending location status correctly', () {
      final json = {
        'restaurantName': 'Fresh Grocery Mart',
        'zoneId': '6741abf2e12a9b0012345678',
        'locationUpdateStatus': 'pending',
        'locationRejectionReason': '',
        'location': {
          'lat': 19.0760,
          'lng': 72.8777,
          'address': 'Shop 10, Main St, Mumbai',
        },
        'pendingLocation': {
          'lat': 19.0820,
          'lng': 72.8800,
          'address': 'Shop 12, New Ave, Mumbai',
        },
      };

      final status = StoreLocationStatus.fromRestaurantJson(json);

      expect(status.name, 'Fresh Grocery Mart');
      expect(status.zoneId, '6741abf2e12a9b0012345678');
      expect(status.isPending, isTrue);
      expect(status.isRejected, isFalse);
      expect(status.location?.latitude, 19.0760);
      expect(status.location?.longitude, 72.8777);
      expect(status.pendingLocation?.latitude, 19.0820);
      expect(status.pendingLocation?.address, 'Shop 12, New Ave, Mumbai');
    });

    test('isRejected getter returns true when locationUpdateStatus is rejected', () {
      final json = {
        'name': 'Corner Store',
        'locationUpdateStatus': 'rejected',
        'locationRejectionReason': 'Pin is outside service area',
      };

      final status = StoreLocationStatus.fromRestaurantJson(json);

      expect(status.isPending, isFalse);
      expect(status.isRejected, isTrue);
      expect(status.locationRejectionReason, 'Pin is outside service area');
    });
  });
}
