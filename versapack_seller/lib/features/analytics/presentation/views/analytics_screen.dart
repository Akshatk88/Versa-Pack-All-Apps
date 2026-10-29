import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:quick_commerce_seller/features/analytics/data/api_analytics_repository.dart';
import 'package:quick_commerce_seller/features/analytics/domain/analytics_model.dart';
import 'package:intl/intl.dart';
import 'package:quick_commerce_seller/features/explore/presentation/controllers/explore_controller.dart';
import 'package:quick_commerce_seller/features/orders/domain/order_model.dart';
import 'package:quick_commerce_seller/features/orders/presentation/controllers/orders_controller.dart';
import 'package:quick_commerce_seller/features/notifications/presentation/controllers/notifications_controller.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  /// Today's real date. It used to read "Today, 4 May" on every device on
  /// every day of the year.
  String get _selectedDate =>
      'Today, ${DateFormat('d MMM').format(DateTime.now())}';

  /// Compact money for a chart axis: ₹0, ₹450, ₹5.2K, ₹1.4L.
  static String _axisLabel(double value) {
    if (value <= 0) return '₹0';
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.round()}';
  }

  /// Weekday names for the seven days the chart covers: a rolling window
  /// ending today, matching `weeklySalesProvider`, oldest first.
  static List<String> _chartDayLabels() {
    final today = DateTime.now();
    return [
      for (var i = 6; i >= 0; i--)
        DateFormat('EEE').format(today.subtract(Duration(days: i))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
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
      drawer: _buildDrawer(context, ref),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header Title & Date Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analytics',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Track your store performance',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Flexible now that the date is real: "Today, 4 May" and
                  // "Today, 15 Aug" are different widths, and the fixed chip
                  // overflowed on the longer ones at large text scales.
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFD9027),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: context.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _selectedDate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: context.textPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 6 Performance Metric Cards (2 Grid columns)
              _buildMetricsGrid(
                ref
                    .watch(analyticsSummaryProvider)
                    .maybeWhen(
                      data: (s) => s,
                      orElse: () => const AnalyticsSummary.empty(),
                    ),
                isLoading: ref.watch(analyticsSummaryProvider).isLoading,
              ),
              const SizedBox(height: 16),

              // Sales Overview Chart Card
              _buildSalesOverviewCard(),
              const SizedBox(height: 16),

              // Top Selling Categories & Orders Overview Breakdown Cards
              _buildBreakdownCardsRow(),
              const SizedBox(height: 16),

              // Recent Orders List Card
              _buildRecentOrdersCard(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders an em dash while the figures are still loading, so the tiles never
  /// show a number that was not measured.
  String _money(double v, {required bool isLoading}) =>
      isLoading ? '—' : '₹${v.toStringAsFixed(2)}';

  String _count(int v, {required bool isLoading}) => isLoading ? '—' : '$v';

  /// Null means there was no previous period to compare with, which is not the
  /// same as no change.
  String _trend(double? percent, {required bool isLoading}) {
    if (isLoading) return ' ';
    if (percent == null) return 'No earlier period';
    final up = percent >= 0;
    return '${up ? '↑' : '↓'} ${percent.abs().toStringAsFixed(1)}% vs previous';
  }

  Widget _buildMetricsGrid(AnalyticsSummary s, {required bool isLoading}) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                icon: Icons.shopping_bag_outlined,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                title: 'Total Sales',
                value: _money(s.totalSales, isLoading: isLoading),
                trend: _trend(s.salesTrendPercent, isLoading: isLoading),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.shopping_basket_outlined,
                iconBg: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF059669),
                title: 'Total Orders',
                value: _count(s.totalOrders, isLoading: isLoading),
                trend: _trend(s.ordersTrendPercent, isLoading: isLoading),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.trending_up_rounded,
                iconBg: const Color(0xFFF5F3FF),
                iconColor: const Color(0xFF7C3AED),
                title: 'Average Order Value',
                value: _money(s.averageOrderValue, isLoading: isLoading),
                trend: _trend(null, isLoading: isLoading),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                icon: Icons.shopping_cart_outlined,
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
                title: 'Items Sold',
                value: _count(s.itemsSold, isLoading: isLoading),
                trend: _trend(null, isLoading: isLoading),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.person_add_alt_1_outlined,
                iconBg: const Color(0xFFFFF7ED),
                iconColor: const Color(0xFFEA580C),
                title: 'New Customers',
                value: _count(s.newCustomers, isLoading: isLoading),
                trend: _trend(null, isLoading: isLoading),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.people_outline_rounded,
                iconBg: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
                title: 'Returning Customers',
                value: _count(s.returningCustomers, isLoading: isLoading),
                trend: _trend(null, isLoading: isLoading),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
    required String trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF181C2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trend,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesOverviewCard() {
    final summary = ref.watch(analyticsSummaryProvider).value;
    final dailySales = ref.watch(weeklySalesProvider);
    // The plot area reserves 10% headroom (see _SalesLineChartPainter), so the
    // value at the very top of the grid is peak/0.9. Labelling with the raw
    // peak would put every gridline slightly off the line it describes.
    final peak = dailySales.isEmpty
        ? 0.0
        : dailySales.reduce((a, b) => a > b ? a : b);
    final axisMax = peak <= 0 ? 0.0 : peak / 0.9;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Sales Overview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  children: [
                    Text(
                      'This Week',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: context.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Total Sales',
            style: TextStyle(fontSize: 10, color: context.textSecondary),
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                summary == null
                    ? '—'
                    : '₹${summary.totalSales.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: context.textPrimary,
                ),
              ),
              // Only drawn when the backend actually resolved a prior period to
              // compare against. A trend is a claim about the past; inventing
              // one is worse than leaving the row short.
              if (summary?.salesTrendPercent != null) ...[
                Icon(
                  summary!.salesTrendPercent! < 0
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 14,
                  color: summary.salesTrendPercent! < 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF10B981),
                ),
                Text(
                  '${summary.salesTrendPercent!.abs().toStringAsFixed(1)}% vs Last Week',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: summary.salesTrendPercent! < 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF10B981),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Custom Painted Line Chart Area with Y-Axis and Grid
          SizedBox(
            height: 160,
            width: double.infinity,
            child: Row(
              children: [
                // Y-Axis Labels
                // Scaled to the week actually being drawn. The old fixed
                // ₹0–20K ladder described no real quantity and did not match
                // the line beside it, which the painter scales to the peak.
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var tick = 4; tick >= 0; tick--)
                      Text(
                        _axisLabel(axisMax * tick / 4),
                        style: TextStyle(
                          fontSize: 9,
                          color: context.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _SalesLineChartPainter(
                            ref.watch(weeklySalesProvider),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Generated from the same seven days the chart
                          // plots — a rolling window ending today, not a fixed
                          // Mon–Sun week. The static labels mislabelled every
                          // point on any day that was not Sunday.
                          for (final day in _chartDayLabels())
                            Expanded(
                              child: Text(
                                day,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Live status split for the donut. Empty buckets are dropped so the legend
  /// does not list five zeroes for a store with no orders.
  Map<_OrderBucket, int> get _statusCounts {
    final active = ref.watch(ordersControllerProvider).value ?? const [];
    final past = ref.watch(orderHistoryProvider).value ?? const [];

    final counts = <_OrderBucket, int>{};
    for (final o in [...active, ...past]) {
      final bucket = switch (o.status) {
        OrderStatus.delivered => _OrderBucket.completed,
        OrderStatus.preparing => _OrderBucket.preparing,
        OrderStatus.ready => _OrderBucket.ready,
        OrderStatus.cancelled => _OrderBucket.cancelled,
        OrderStatus.newOrder => _OrderBucket.pending,
      };
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    return counts;
  }

  Widget _buildBreakdownCardsRow() {
    final statusCounts = _statusCounts;
    final totalOrders = statusCounts.values.fold<int>(0, (a, b) => a + b);
    final categories = [
      for (final c in ref.watch(categorySalesProvider))
        {
          'name': c.name,
          'amount': NumberFormat.currency(
            locale: 'en_IN',
            symbol: '₹',
            decimalDigits: 0,
          ).format(c.revenue),
          'pct': '${(c.share * 100).toStringAsFixed(1)}%',
          'val': c.share,
          'icon': Icons.category_rounded,
        },
    ];

    return Column(
      children: [
        // Top Selling Categories Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Top Selling Categories',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'This Week',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.textPrimary,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 12,
                          color: context.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: categories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              cat['icon'] as IconData,
                              size: 16,
                              color: const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                cat['name'].toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              cat['amount'].toString(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat['pct'].toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: cat['val'] as double,
                            backgroundColor: const Color(0xFFF3F4F6),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFD9027),
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Orders Overview Card with Donut Chart
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Orders Overview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Donut Chart Area
              Center(
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(140, 140),
                        painter: _OrdersDonutChartPainter(statusCounts),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$totalOrders',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            'Total Orders',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Breakdown Legends List
              for (final entry in statusCounts.entries) ...[
                _buildDonutLegend(
                  entry.key.color,
                  entry.key.label,
                  totalOrders == 0
                      ? '0'
                      : '${entry.value} '
                            '(${(entry.value / totalOrders * 100).toStringAsFixed(1)}%)',
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDonutLegend(Color color, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Expanded, so the inner Row has a bounded width for its Flexible
        // label. Without it the label sits under unbounded constraints and
        // flex is illegal.
        Expanded(
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
      ],
    );
  }

  /// One order in the shape the row below was written against.
  Map<String, dynamic> _recentRowFor(OrderModel o) {
    final (label, bg, fg) = switch (o.status) {
      OrderStatus.newOrder => (
        'New',
        const Color(0xFFFEF3C7),
        const Color(0xFFD97706),
      ),
      OrderStatus.preparing => (
        'Preparing',
        const Color(0xFFFEF3C7),
        const Color(0xFFD97706),
      ),
      OrderStatus.ready => (
        'Ready',
        const Color(0xFFEFF6FF),
        const Color(0xFF2563EB),
      ),
      OrderStatus.delivered => (
        'Completed',
        const Color(0xFFECFDF5),
        const Color(0xFF059669),
      ),
      OrderStatus.cancelled => (
        'Cancelled',
        const Color(0xFFFEE2E2),
        const Color(0xFFDC2626),
      ),
    };

    final count = o.items.fold<int>(0, (n, i) => n + i.quantity);

    return {
      'id': o.orderNumber.isEmpty ? o.id : o.orderNumber,
      'customer': o.customer.name,
      'status': label,
      'statusBg': bg,
      'statusColor': fg,
      'amount': '₹${o.totalAmount.toStringAsFixed(2)}',
      'items': '$count item${count == 1 ? '' : 's'}',
      'stateText': label,
      'stateColor': fg,
      'time': DateFormat('h:mm a').format(o.createdAt.toLocal()),
      'iconBg': bg,
      'iconColor': fg,
    };
  }

  Widget _buildRecentOrdersCard(BuildContext context) {
    // The five most recent orders across both lists, newest first.
    final active = ref.watch(ordersControllerProvider).value ?? const [];
    final past = ref.watch(orderHistoryProvider).value ?? const [];
    final all = [...active, ...past]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recent = all.take(5).map(_recentRowFor).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Recent Orders',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/orders'),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: recent.map((o) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.pageBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: o['iconBg'] as Color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.widgets_outlined,
                        color: o['iconColor'] as Color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                o['id'].toString(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: o['statusBg'] as Color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  o['status'].toString(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: o['statusColor'] as Color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            o['customer'].toString(),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            o['amount'].toString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            '${o['items']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textSecondary,
                            ),
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
                            o['stateText'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: o['stateColor'] as Color,
                            ),
                          ),
                          Text(
                            o['time'].toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.textSecondary,
                      size: 18,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProfileProvider).value;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFFD9027)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  store?.name ?? 'Your store',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF181C2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (store?.isOnline ?? false) ? 'Online' : 'Offline',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF181C2E),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined, color: Color(0xFF181C2E)),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
              context.go('/home');
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.shopping_bag_outlined,
              color: Color(0xFF181C2E),
            ),
            title: const Text('Orders'),
            onTap: () {
              Navigator.pop(context);
              context.go('/orders');
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.bar_chart_rounded,
              color: Color(0xFFF59E0B),
            ),
            title: const Text(
              'Analytics',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFF59E0B),
              ),
            ),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF181C2E),
            ),
            title: const Text('Products'),
            onTap: () {
              Navigator.pop(context);
              context.go('/products');
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.settings_outlined,
              color: Color(0xFF181C2E),
            ),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),
        ],
      ),
    );
  }
}

class _SalesLineChartPainter extends CustomPainter {
  const _SalesLineChartPainter(this.values);

  /// Delivered revenue per day, oldest first.
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) return;

    // Scaled against the best day. A week with no sales has no line to draw —
    // a flat one at any height would state something that did not happen.
    final peak = values.reduce((a, b) => a > b ? a : b);
    if (peak <= 0) return;

    final step = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(step * i, size.height * (1 - (values[i] / peak)) * 0.9),
    ];

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFD9027).withValues(alpha: 0.35),
          const Color(0xFFFD9027).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFFFD9027)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = const Color(0xFFFD9027);
    final innerDotPaint = Paint()..color = Colors.white;

    for (final pt in points) {
      canvas.drawCircle(pt, 4.5, dotPaint);
      canvas.drawCircle(pt, 2, innerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SalesLineChartPainter oldDelegate) =>
      oldDelegate.values != values;
}

/// The five slices the orders donut can show, with the colour each is drawn in.
enum _OrderBucket {
  completed('Completed', Color(0xFF10B981)),
  preparing('Preparing', Color(0xFFFD9027)),
  ready('Ready', Color(0xFF2563EB)),
  pending('Pending', Color(0xFF8B5CF6)),
  cancelled('Cancelled', Color(0xFF9CA3AF));

  const _OrderBucket(this.label, this.color);

  final String label;
  final Color color;
}

class _OrdersDonutChartPainter extends CustomPainter {
  const _OrdersDonutChartPainter(this.counts);

  final Map<_OrderBucket, int> counts;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;

    double startAngle = -math.pi / 2;

    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;

    final slices = [
      for (final entry in counts.entries)
        {
          'sweep': 2 * math.pi * (entry.value / total),
          'color': entry.key.color,
        },
    ];

    for (final slice in slices) {
      paint.color = slice['color'] as Color;
      final sweepAngle = slice['sweep'] as double;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle - 0.04,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _OrdersDonutChartPainter oldDelegate) =>
      oldDelegate.counts != counts;
}
