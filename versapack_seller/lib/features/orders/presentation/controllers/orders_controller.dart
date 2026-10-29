import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/providers/repository_providers.dart';
import 'package:quick_commerce_seller/features/orders/domain/order_model.dart';
import 'package:quick_commerce_seller/features/orders/domain/order_repository.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/controllers/inventory_controller.dart';

final ordersControllerProvider =
    AsyncNotifierProvider<OrdersController, List<OrderModel>>(
      OrdersController.new,
    );

class OrdersController extends AsyncNotifier<List<OrderModel>> {
  late final OrderRepository _repository;

  @override
  Future<List<OrderModel>> build() async {
    _repository = ref.watch(orderRepositoryProvider);
    return _repository.getOrders();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getOrders());
  }

  Future<void> updateStatus(String orderId, OrderStatus status) async {
    final previousState = state;
    state = await AsyncValue.guard(() async {
      await _repository.updateOrderStatus(orderId, status);
      return _repository.getOrders();
    });
    if (state.hasError) {
      state = previousState;
    }
  }
}

/// Completed and cancelled orders — the ones the seller can no longer act on.
/// Separate from [ordersControllerProvider] because the two hit the same route
/// with opposite status filters and a screen only ever wants one of them.
final orderHistoryProvider = FutureProvider<List<OrderModel>>(
  (ref) => ref.watch(orderRepositoryProvider).getOrderHistory(),
);

/// A single order, for the details screen. Keyed by id so navigating between
/// two orders does not serve the first one's payload to the second.
final orderByIdProvider = FutureProvider.family<OrderModel?, String>(
  (ref, orderId) => ref.watch(orderRepositoryProvider).getOrderById(orderId),
);

final newOrdersCountProvider = Provider<int>((ref) {
  final orders = ref.watch(ordersControllerProvider).value ?? [];
  return orders.where((o) => o.status == OrderStatus.newOrder).length;
});

final preparingOrdersCountProvider = Provider<int>((ref) {
  final orders = ref.watch(ordersControllerProvider).value ?? [];
  return orders.where((o) => o.status == OrderStatus.preparing).length;
});

final readyOrdersCountProvider = Provider<int>((ref) {
  final orders = ref.watch(ordersControllerProvider).value ?? [];
  return orders.where((o) => o.status == OrderStatus.ready).length;
});

/// Finished orders come from the history route, not the active one, so these
/// two read a different provider than the counts above.
final completedOrdersCountProvider = Provider<int>((ref) {
  final orders = ref.watch(orderHistoryProvider).value ?? [];
  return orders.where((o) => o.status == OrderStatus.delivered).length;
});

final cancelledOrdersCountProvider = Provider<int>((ref) {
  final orders = ref.watch(orderHistoryProvider).value ?? [];
  return orders.where((o) => o.status == OrderStatus.cancelled).length;
});

/// Delivered revenue for each of the last seven days, oldest first, so index 6
/// is today. Zero-filled: a day with no orders is a real zero, not a gap.
final weeklySalesProvider = Provider<List<double>>((ref) {
  final orders = ref.watch(orderHistoryProvider).value ?? [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final totals = List<double>.filled(7, 0);

  for (final order in orders) {
    if (order.status != OrderStatus.delivered) continue;

    final at = order.createdAt.toLocal();
    final day = DateTime(at.year, at.month, at.day);
    final index = 6 - today.difference(day).inDays;
    if (index >= 0 && index < 7) totals[index] += order.totalAmount;
  }

  return totals;
});

/// Revenue per category, highest first.
///
/// Order lines carry a product name but no category, so this joins them to the
/// seller's own catalogue by name. Anything that does not match is skipped
/// rather than bucketed into a made-up "Other" — see the hand-back note asking
/// for `categoryName` on the order item payload.
final categorySalesProvider =
    Provider<List<({String name, double revenue, double share})>>((ref) {
      final orders = ref.watch(orderHistoryProvider).value ?? [];
      final catalogue = ref.watch(inventoryControllerProvider).value ?? [];

      final categoryOf = {
        for (final p in catalogue)
          if (p.name.isNotEmpty && p.categoryName.isNotEmpty)
            p.name.toLowerCase(): p.categoryName,
      };

      final revenue = <String, double>{};
      for (final order in orders) {
        if (order.status != OrderStatus.delivered) continue;
        for (final item in order.items) {
          final category = categoryOf[item.name.toLowerCase()];
          if (category == null) continue;
          revenue[category] = (revenue[category] ?? 0) + item.totalPrice;
        }
      }

      final total = revenue.values.fold<double>(0, (a, b) => a + b);
      if (total <= 0) return const [];

      final ranked = revenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return [
        for (final e in ranked.take(5))
          (name: e.key, revenue: e.value, share: e.value / total),
      ];
    });

/// Products ranked by units sold across completed orders.
///
/// Derived on the client because the backend exposes no best-sellers route —
/// see the note in `AnalyticsSummary`. Ranking only delivered orders keeps a
/// cancelled basket from promoting an item nobody actually received.
final topSellingItemsProvider = Provider<List<({String name, int units})>>((
  ref,
) {
  final orders = ref.watch(orderHistoryProvider).value ?? [];

  final units = <String, int>{};
  for (final order in orders) {
    if (order.status != OrderStatus.delivered) continue;
    for (final item in order.items) {
      if (item.name.isEmpty) continue;
      units[item.name] = (units[item.name] ?? 0) + item.quantity;
    }
  }

  final ranked = units.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return [
    for (final e in ranked.take(4)) (name: e.key, units: e.value),
  ];
});
