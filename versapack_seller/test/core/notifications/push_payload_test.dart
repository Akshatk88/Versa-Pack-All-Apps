import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/core/notifications/push_service.dart';

/// The payload contract with the backend's `notifyRestaurantNewOrder`.
///
/// Everything else in the push flow needs a device to exercise; this part is
/// pure and is where a wrong key silently sends the seller nowhere.
void main() {
  test('reads the order id the backend actually sends', () {
    final message = RemoteMessage(
      data: {
        'type': 'new_order',
        'orderId': '68d1f0a2c4b1e90012ab34cd',
        'orderDisplayId': 'QC-1042',
      },
    );

    expect(PushService.orderIdOf(message), '68d1f0a2c4b1e90012ab34cd');
  });

  test('falls back to orderMongoId', () {
    final message = RemoteMessage(
      data: {'type': 'new_order', 'orderMongoId': '68d1f0a2c4b1e90012ab34cd'},
    );

    expect(PushService.orderIdOf(message), '68d1f0a2c4b1e90012ab34cd');
  });

  test('never routes on the human-facing reference', () {
    // orderDisplayId is `order_id`, which the orders API would 404 on. Routing
    // by it would open "Order not found" on a perfectly valid order.
    final message = RemoteMessage(
      data: {'type': 'new_order', 'orderDisplayId': 'QC-1042'},
    );

    expect(PushService.orderIdOf(message), isNull);
  });

  test('ignores blank ids rather than routing to an empty path', () {
    final message = RemoteMessage(
      data: {'type': 'new_order', 'orderId': '  ', 'orderMongoId': ''},
    );

    expect(PushService.orderIdOf(message), isNull);
  });
}
