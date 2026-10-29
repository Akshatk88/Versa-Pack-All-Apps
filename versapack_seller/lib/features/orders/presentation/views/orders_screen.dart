import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:quick_commerce_seller/core/widgets/app_drawer.dart';
import 'package:quick_commerce_seller/features/orders/domain/order_model.dart';
import 'package:quick_commerce_seller/features/orders/presentation/controllers/orders_controller.dart';
import 'package:quick_commerce_seller/features/notifications/presentation/controllers/notifications_controller.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  int _selectedFilterIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  /// Labels only. The counts beside them are derived from the orders on screen,
  /// because a pill that says 6 while the list shows none is worse than no
  /// number at all.
  static const List<String> _filterLabels = [
    'All Orders',
    'New',
    'Accepted',
    'Preparing',
    'Ready',
  ];

  List<Map<String, dynamic>> _filtersFor(List<OrderModel> orders) {
    int count(OrderStatus s) => orders.where((o) => o.status == s).length;
    final byLabel = <String, int>{
      'All Orders': orders.length,
      'New': count(OrderStatus.newOrder),
      'Accepted': count(OrderStatus.preparing),
      'Preparing': count(OrderStatus.preparing),
      'Ready': count(OrderStatus.ready),
    };
    return _filterLabels
        .map((l) => {'label': l, 'count': '${byLabel[l] ?? 0}'})
        .toList();
  }

  List<OrderModel> _applyFilterAndSearch(List<OrderModel> orders) {
    Iterable<OrderModel> filtered = orders;

    switch (_selectedFilterIndex) {
      case 1: // New
        filtered = filtered.where((o) => o.status == OrderStatus.newOrder);
        break;
      case 2: // Accepted
      case 3: // Preparing
        filtered = filtered.where((o) => o.status == OrderStatus.preparing);
        break;
      case 4: // Ready
        filtered = filtered.where((o) => o.status == OrderStatus.ready);
        break;
      case 0: // All Orders
      default:
        break;
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((o) {
        final matchesId = o.id.toLowerCase().contains(query) ||
            o.orderNumber.toLowerCase().contains(query);
        final matchesName = o.customer.name.toLowerCase().contains(query);
        final matchesPhone = o.customer.phone.toLowerCase().contains(query);
        final matchesItem =
            o.items.any((item) => item.name.toLowerCase().contains(query));
        return matchesId || matchesName || matchesPhone || matchesItem;
      });
    }

    return filtered.toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openStatusFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                for (var i = 0; i < _filterLabels.length; i++)
                  ListTile(
                    leading: Icon(
                      _selectedFilterIndex == i
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: _selectedFilterIndex == i
                          ? const Color(0xFFD97706)
                          : context.textSecondary,
                    ),
                    title: Text(
                      _filterLabels[i],
                      style: TextStyle(
                        fontWeight: _selectedFilterIndex == i
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: context.textPrimary,
                      ),
                    ),
                    onTap: () {
                      setState(() => _selectedFilterIndex = i);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(
              Icons.menu_rounded,
              color: context.textPrimary,
              size: 26,
            ),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Column(
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Inter',
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(
                    text: 'Versa',
                    style: TextStyle(color: context.textPrimary),
                  ),
                  TextSpan(
                    text: 'pack',
                    style: TextStyle(color: Color(0xFF0F9D58)),
                  ),
                ],
              ),
            ),
            Text(
              'Quick Seller',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: context.textPrimary,
                  size: 26,
                ),
                onPressed: () => context.push('/notifications'),
              ),
              // Hidden at zero: a badge reading "0" is worse than no badge.
              if (ref.watch(unreadNotificationsCountProvider) > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${ref.watch(unreadNotificationsCountProvider)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header Title
              Text(
                'Orders',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Manage and track all incoming orders',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
              const SizedBox(height: 16),

              // Filter Pills Horizontal ListView
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: (() {
                    final orders =
                        ref.watch(ordersControllerProvider).value ?? const [];
                    final filters = _filtersFor(orders);
                    return List.generate(filters.length, (index) {
                      final isSelected = _selectedFilterIndex == index;
                      final f = filters[index];

                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedFilterIndex = index),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFEF3C7)
                                : context.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFD9027)
                                  : context.borderColor,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                f['label'].toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                f['count'].toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? const Color(0xFFD97706)
                                      : context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    });
                  })(),
                ),
              ),
              const SizedBox(height: 14),

              // Search & Filter Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search order ID, customer, phone...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: context.textSecondary,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _openStatusFilterSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _selectedFilterIndex != 0
                            ? const Color(0xFFFEF3C7)
                            : context.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedFilterIndex != 0
                              ? const Color(0xFFFD9027)
                              : context.borderColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            size: 16,
                            color: _selectedFilterIndex != 0
                                ? const Color(0xFFD97706)
                                : context.textPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Filter',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _selectedFilterIndex != 0
                                  ? const Color(0xFFD97706)
                                  : context.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: _selectedFilterIndex != 0
                                ? const Color(0xFFD97706)
                                : context.textPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              ...(() {
                final allRaw =
                    ref.watch(ordersControllerProvider).value ?? const [];
                final all = _applyFilterAndSearch(allRaw);

                if (all.isEmpty) {
                  final isFiltered = _selectedFilterIndex != 0 ||
                      _searchController.text.trim().isNotEmpty;
                  return [
                    _buildEmptySection(isFiltered),
                  ];
                }

                final now = DateTime.now();
                final today = all.where(
                  (o) =>
                      o.createdAt.year == now.year &&
                      o.createdAt.month == now.month &&
                      o.createdAt.day == now.day,
                ).toList();

                final earlier = all.where(
                  (o) =>
                      !(o.createdAt.year == now.year &&
                          o.createdAt.month == now.month &&
                          o.createdAt.day == now.day),
                ).toList();

                return <Widget>[
                  if (today.isNotEmpty) ...[
                    Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...today.map((o) => _buildOrderCard(_cardFor(o))),
                  ],
                  if (earlier.isNotEmpty) ...[
                    if (today.isNotEmpty) const SizedBox(height: 16),
                    Text(
                      'Yesterday',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...earlier.map((o) => _buildOrderCard(_cardFor(o))),
                  ],
                ];
              })(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Shown where cards would be when there is genuinely nothing to show.
  Widget _buildEmptySection(bool isFiltered) {
    if (isFiltered) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: context.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'No orders found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search or filter',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedFilterIndex = 0;
                });
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 30,
            color: context.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            'No orders yet',
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Shapes a real order into the map `_buildOrderCard` already renders, so the
  /// card keeps its exact layout and only its contents become true.
  Map<String, dynamic> _cardFor(OrderModel o) {
    final (label, bg, fg, action) = switch (o.status) {
      OrderStatus.newOrder => (
        'New',
        const Color(0xFFFEF3C7),
        const Color(0xFFD97706),
        'Accept Order',
      ),
      OrderStatus.preparing => (
        'Preparing',
        const Color(0xFFECFDF5),
        const Color(0xFF059669),
        'Mark Ready',
      ),
      OrderStatus.ready => (
        'Ready',
        const Color(0xFFEFF6FF),
        const Color(0xFF2563EB),
        'Handed Over',
      ),
      OrderStatus.delivered => (
        'Completed',
        const Color(0xFFF3F4F6),
        const Color(0xFF6B7280),
        '',
      ),
      OrderStatus.cancelled => (
        'Cancelled',
        const Color(0xFFFEE2E2),
        const Color(0xFFDC2626),
        '',
      ),
    };

    final count = o.items.fold<int>(0, (n, i) => n + i.quantity);

    return {
      'id': o.orderNumber.isEmpty ? o.id : o.orderNumber,
      'orderId': o.id,
      'status': label,
      'statusColor': bg,
      'textColor': fg,
      'customer': o.customer.name,
      'phone': o.customer.phone,
      'amount': '₹${o.totalAmount.toStringAsFixed(2)}',
      'items': '$count item${count == 1 ? '' : 's'}',
      'distance': o.customer.address,
      'time': _formatWhen(o.createdAt),
      'action': action,
      'expiry': '',
    };
  }

  static String _formatWhen(DateTime at) {
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    final period = at.hour < 12 ? 'AM' : 'PM';
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return '${sameDay ? 'Today' : '${at.day}/${at.month}'}, $h:$m $period';
  }

  Widget _buildOrderCard(Map<String, dynamic> o) {
    final bool isOutlined = o['isOutlined'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wrap: long status labels ("Out for Delivery") must fall
                    // to a second line rather than overflow the card.
                    Wrap(
                      spacing: 2,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Order ID ',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: o['statusColor'] as Color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            o['status'].toString(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: o['textColor'] as Color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      o['id'].toString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 13,
                          color: context.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            o['customer'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 13,
                          color: context.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            o['phone'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      o['amount'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      o['items'].toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Button
                    if (isOutlined)
                      OutlinedButton(
                        onPressed: () => context.push('/order-details/${o['orderId']}'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          o['action'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: () => context.push('/order-details/${o['orderId']}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFD9027),
                          foregroundColor: const Color(0xFF181C2E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          o['action'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      ),

                    if (o['expiry'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        o['expiry'].toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: context.borderColor),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.two_wheeler_rounded,
                size: 14,
                color: Color(0xFF10B981),
              ),
              const SizedBox(width: 4),
              const Text(
                'Delivery',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
              Expanded(
                child: Text(
                  '  •  ${o['distance']}  •  ${o['time']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
