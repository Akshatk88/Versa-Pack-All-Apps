import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/features/auth/domain/seller_model.dart';

void main() {
  group('SellerModel.fromJson', () {
    test('parses a full backend payload', () {
      final seller = SellerModel.fromJson({
        '_id': '65f1c2a4e9b1d2003a7c1234',
        'name': 'Ravi Kumar',
        'restaurantName': 'Ravi Fresh Mart',
        'phone': '9876543210',
        'email': 'ravi@example.com',
        'status': 'approved',
        'profileImage': '/uploads/stores/logo.webp',
        'isAcceptingOrders': true,
        'rating': 4.6,
        'totalRatings': 128,
      });

      expect(seller.id, '65f1c2a4e9b1d2003a7c1234');
      expect(seller.storeName, 'Ravi Fresh Mart');
      expect(seller.isApproved, isTrue);
      expect(seller.isAcceptingOrders, isTrue);
      expect(seller.rating, 4.6);
      expect(seller.totalRatings, 128);
    });

    test('an empty payload yields defaults instead of throwing', () {
      final seller = SellerModel.fromJson(const {});

      expect(seller.id, '');
      expect(seller.status, '');
      expect(seller.rating, 0);
      expect(seller.totalRatings, 0);
      // Absent means open — approved sellers default to trading.
      expect(seller.isAcceptingOrders, isTrue);
      expect(seller.isApproved, isFalse);
      expect(seller.displayName, 'My store');
    });

    test('accepts numbers delivered as strings', () {
      final seller = SellerModel.fromJson({
        'rating': '4.25',
        'totalRatings': '17',
      });

      expect(seller.rating, 4.25);
      expect(seller.totalRatings, 17);
    });

    test('a malformed number falls back rather than throwing', () {
      final seller = SellerModel.fromJson({'rating': 'not-a-number'});

      expect(seller.rating, 0);
    });

    test('prefers id over _id, and falls back to name for the store', () {
      final seller = SellerModel.fromJson({
        'id': 'abc',
        '_id': 'should-not-win',
        'name': 'Corner Store',
      });

      expect(seller.id, 'abc');
      expect(seller.storeName, 'Corner Store');
    });

    test('status flags are mutually exclusive', () {
      expect(SellerModel.fromJson({'status': 'pending'}).isPending, isTrue);
      expect(SellerModel.fromJson({'status': 'rejected'}).isRejected, isTrue);
      expect(SellerModel.fromJson({'status': 'rejected'}).isApproved, isFalse);
    });
  });
}
