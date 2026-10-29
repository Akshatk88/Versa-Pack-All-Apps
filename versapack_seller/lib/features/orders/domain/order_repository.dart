import 'package:quick_commerce_seller/features/orders/domain/order_model.dart';

abstract class OrderRepository {
  Future<List<OrderModel>> getOrders();
  Future<OrderModel?> getOrderById(String orderId);
  Future<void> updateOrderStatus(String orderId, OrderStatus status);
  Future<List<OrderModel>> getOrderHistory();
}
