import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:quick_commerce_seller/core/widgets/async_state_view.dart';
import 'package:quick_commerce_seller/features/orders/domain/order_model.dart';
import 'package:quick_commerce_seller/features/orders/presentation/controllers/orders_controller.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.textPrimary,
            size: 18,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Order History',
          style: AppTextStyles.h3.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search & Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search orders',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: context.textSecondary,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondaryLight,
                      ),
                      fillColor: const Color(0xFFF9FAFB),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.pageBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: context.textPrimary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF181C2E),
              unselectedLabelColor: AppColors.textSecondaryLight,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: AppTextStyles.bodyMedium,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryList(context, filter: 'All'),
                _buildHistoryList(context, filter: 'Completed'),
                _buildHistoryList(context, filter: 'Cancelled'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, {required String filter}) {
    final history = ref.watch(orderHistoryProvider);

    return AsyncStateView<List<OrderModel>>(
      value: history,
      onRetry: () => ref.invalidate(orderHistoryProvider),
      isEmpty: (orders) => _filter(orders, filter).isEmpty,
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: _query.isNotEmpty
          ? 'No matching orders'
          : 'No past orders yet',
      emptyMessage: _query.isNotEmpty
          ? 'Nothing matches "$_query".'
          : 'Completed and cancelled orders will appear here.',
      builder: (orders) {
        final filtered = _filter(orders, filter);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final order = filtered[index];
            final isCompleted = order.status == OrderStatus.delivered;
            final label = isCompleted ? 'Completed' : 'Cancelled';

            return GestureDetector(
              onTap: () => context.push('/order-details/${order.id}'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNumber.isEmpty
                                ? order.id
                                : order.orderNumber,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: const Color(0xFF181C2E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat(
                              'd MMM, h:mm a',
                            ).format(order.createdAt.toLocal()),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${order.totalAmount.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: const Color(0xFF181C2E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? AppColors.successBg
                                : AppColors.errorBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            label,
                            style: AppTextStyles.caption.copyWith(
                              color: isCompleted
                                  ? AppColors.successText
                                  : AppColors.errorText,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Tab filter plus the search box. Both narrow the same list, so they are
  /// applied in one place rather than at each call site.
  List<OrderModel> _filter(List<OrderModel> orders, String filter) {
    final query = _query.trim().toLowerCase();

    return orders.where((o) {
      final matchesTab = switch (filter) {
        'Completed' => o.status == OrderStatus.delivered,
        'Cancelled' => o.status == OrderStatus.cancelled,
        _ => true,
      };
      if (!matchesTab) return false;
      if (query.isEmpty) return true;

      return o.orderNumber.toLowerCase().contains(query) ||
          o.id.toLowerCase().contains(query) ||
          o.customer.name.toLowerCase().contains(query);
    }).toList();
  }
}
