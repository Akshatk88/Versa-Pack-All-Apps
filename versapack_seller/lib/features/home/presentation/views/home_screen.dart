import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:quick_commerce_seller/core/widgets/app_drawer.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/explore/domain/store_settings_model.dart';
import 'package:quick_commerce_seller/features/explore/presentation/controllers/explore_controller.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:quick_commerce_seller/features/analytics/data/api_analytics_repository.dart';
import 'package:quick_commerce_seller/features/analytics/domain/analytics_model.dart';
import 'package:quick_commerce_seller/features/orders/presentation/controllers/orders_controller.dart';
import 'package:quick_commerce_seller/features/notifications/presentation/controllers/notifications_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeProfileAsync = ref.watch(storeProfileProvider);
    final storeProfile = storeProfileAsync.value;
    // The dashboard deliberately keeps rendering while the profile loads —
    // replacing every card with a spinner for one banner would be worse. But
    // the name is never invented (it used to fall back to a fictional store)
    // and the availability toggle stays disabled until the real state is known,
    // so the seller can't act on a guess.
    final isStoreOnline = storeProfile?.isOnline ?? false;
    final storeName = storeProfile?.name ?? 'Your store';

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
      drawer: const AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Golden Welcome Banner Card
              _buildWelcomeBannerCard(
                context,
                ref,
                storeName,
                isStoreOnline,
                isKnown: storeProfile != null,
              ),
              const SizedBox(height: 20),

              // Today's Overview Section
              _buildTodaysOverviewHeader(context),
              const SizedBox(height: 12),
              _buildMetricsRow(ref),
              const SizedBox(height: 20),

              // Order Summary Card
              _buildOrderSummaryCard(context, ref),
              const SizedBox(height: 20),

              // Sales Analytics & Top Selling Items Section
              _buildSalesAnalyticsCard(context, ref),
              const SizedBox(height: 16),
              _buildTopSellingItemsCard(context, ref),
              const SizedBox(height: 20),

              // Promotional Banner Card
              _buildPromoBannerCard(context),
              const SizedBox(height: 20),

              // Quick Actions
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActionsRow(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBannerCard(
    BuildContext context,
    WidgetRef ref,
    String storeName,
    bool isOnline, {
    required bool isKnown,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFD9027),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFD9027).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF181C2E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF181C2E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Opens the full availability screen (scheduled pauses, reasons).
              InkWell(
                onTap: () => context.push('/restaurant-status'),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 32,
                        color: Color(0xFF181C2E),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 28,
                      height: 28,
                      // On the golden banner, so not a themed surface.
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF181C2E),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildStoreStatusToggle(context, ref, isOnline, isKnown: isKnown),
          const SizedBox(height: 8),
          _buildTodayHours(context, ref),
        ],
      ),
    );
  }

  /// Today's opening hours, under the availability switch.
  ///
  /// Separate from the Online/Offline toggle on purpose: that switch is a
  /// manual override for right now, while this is the schedule. Showing both
  /// is what lets a seller tell "I paused the shop" apart from "we are outside
  /// today's hours". Tapping opens the editor, so the schedule is always one
  /// tap from the screen the seller starts on.
  Widget _buildTodayHours(BuildContext context, WidgetRef ref) {
    final timings = ref.watch(outletTimingsProvider).value;
    // Never guesses. Until the real schedule arrives the row says so, rather
    // than showing default 09:00–22:00 hours the seller never set.
    final todayName = DateFormat('EEEE').format(DateTime.now());
    final forToday =
        timings?.where((t) => t.dayName == todayName) ??
        const <DayTimingModel>[];
    final DayTimingModel? today = forToday.isEmpty ? null : forToday.first;

    final String label;
    if (timings == null) {
      label = 'Loading hours…';
    } else if (today == null) {
      label = 'Hours not set';
    } else if (!today.isOpen) {
      label = 'Closed today';
    } else {
      label = '${_hhmmToDisplay(context, today.openTime)} – '
          '${_hhmmToDisplay(context, today.closeTime)}';
    }

    return InkWell(
      onTap: () => context.push('/outlet-timings'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 16,
              color: Color(0xFF181C2E),
            ),
            const SizedBox(width: 8),
            // Flexible, not fixed: at 320dp with 1.5x text this label and the
            // hours together overflowed the row by 55px. The label truncates
            // first — the icon already says what the row is about, and the
            // hours themselves are the part worth reading.
            const Flexible(
              child: Text(
                "Today's hours",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181C2E),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3F4451),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF3F4451),
            ),
          ],
        ),
      ),
    );
  }

  /// Weekday names for the seven days the sales chart covers: a rolling window
  /// ending today, matching `weeklySalesProvider`, oldest first.
  static List<String> _chartDayLabels() {
    final today = DateTime.now();
    return [
      for (var i = 6; i >= 0; i--)
        DateFormat('EEE').format(today.subtract(Duration(days: i))),
    ];
  }

  /// "22:00" → "10:00 PM", following the device's clock setting.
  static String _hhmmToDisplay(BuildContext context, String value) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (m == null) return value;
    final hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    if (hour > 23 || minute > 59) return value;
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  /// Shop Open/Closed switch. Writes through the same provider as the
  /// availability screen, so both stay in sync.
  Widget _buildStoreStatusToggle(
    BuildContext context,
    WidgetRef ref,
    bool isOnline, {
    required bool isKnown,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0xFF15803D)
                  : const Color(0xFFB91C1C),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !isKnown
                      ? 'Checking status…'
                      : (isOnline ? 'Shop Open' : 'Shop Closed'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF181C2E),
                  ),
                ),
                Text(
                  !isKnown
                      ? 'Loading your store'
                      : (isOnline
                            ? 'Accepting new orders'
                            : 'Not accepting orders'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF3F4451),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOnline,
            activeTrackColor: const Color(0xFF22C55E),
            activeThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFEF4444),
            inactiveThumbColor: Colors.white,
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            onChanged: !isKnown
                ? null
                : (value) {
                    ref
                        .read(storeProfileProvider.notifier)
                        .setOnlineStatus(
                          value,
                          reason: value ? '' : 'Manual Pause',
                        );
                    AppToast.show(
                      context,
                      value
                          ? 'Shop is now Open — accepting orders'
                          : 'Shop is now Closed — orders paused',
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysOverviewHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            "Today's Overview",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  DateFormat('d MMM yyyy, EEEE').format(DateTime.now()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: context.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Rupees, grouped the Indian way (₹1,08,645 rather than ₹108,645) and
  /// without paise — every figure on this screen is a headline, not a receipt.
  static String _money(double amount) =>
      NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      ).format(amount);

  Widget _buildMetricsRow(WidgetRef ref) {
    final summary =
        ref.watch(analyticsSummaryProvider).value ??
        const AnalyticsSummary.empty();
    final isLoading = ref.watch(analyticsSummaryProvider).isLoading;

    // A null trend means there is no previous day to compare against. Showing
    // "0%" there would read as "flat", which is a different claim.
    String? trend(double? percent) =>
        percent == null ? null : '${percent.abs().toStringAsFixed(0)}%';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildMetricTile(
            bgColor: const Color(0xFFFFFBEB),
            iconBgColor: const Color(0xFFFDE68A),
            icon: Icons.shopping_bag_outlined,
            iconColor: const Color(0xFFD97706),
            label: 'Total Orders',
            value: isLoading ? '—' : '${summary.totalOrders}',
            percentage: trend(summary.ordersTrendPercent),
            isDown: (summary.ordersTrendPercent ?? 0) < 0,
          ),
          const SizedBox(width: 12),
          _buildMetricTile(
            bgColor: const Color(0xFFECFDF5),
            iconBgColor: const Color(0xFFA7F3D0),
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFF059669),
            label: 'Total Earnings',
            value: isLoading ? '—' : _money(summary.totalSales),
            percentage: trend(summary.salesTrendPercent),
            isDown: (summary.salesTrendPercent ?? 0) < 0,
          ),
          const SizedBox(width: 12),
          _buildMetricTile(
            bgColor: const Color(0xFFF5F3FF),
            iconBgColor: const Color(0xFFDDD6FE),
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFF7C3AED),
            label: 'Avg. Order Value',
            value: isLoading ? '—' : _money(summary.averageOrderValue),
            percentage: null,
          ),
          const SizedBox(width: 12),
          _buildMetricTile(
            bgColor: const Color(0xFFEFF6FF),
            iconBgColor: const Color(0xFFBFDBFE),
            icon: Icons.people_outline_rounded,
            iconColor: const Color(0xFF2563EB),
            label: 'New Customers',
            value: isLoading ? '—' : '${summary.newCustomers}',
            percentage: null,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required Color bgColor,
    required Color iconBgColor,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String? percentage,
    bool isDown = false,
  }) {
    return Container(
      width: 135,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF181C2E),
            ),
          ),
          const SizedBox(height: 6),
          // No comparison exists for a store's first day, so the row is left
          // blank rather than claiming a flat 0%.
          if (percentage != null)
            Row(
              children: [
                Icon(
                  isDown
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 11,
                  color: isDown
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF10B981),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    '$percentage vs yesterday',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDown
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
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
                  'Order Summary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: GestureDetector(
                  onTap: () => context.push('/order-history'),
                  child: const Text(
                    'View all orders',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildOrderStatusPill(
                  context,
                  icon: Icons.assignment_outlined,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFEF3C7),
                  count: '${ref.watch(newOrdersCountProvider)}',
                  label: 'New Orders',
                  isActive: true,
                ),
                const SizedBox(width: 10),
                _buildOrderStatusPill(
                  context,
                  icon: Icons.access_time_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFFFBEB),
                  count: '${ref.watch(preparingOrdersCountProvider)}',
                  label: 'Preparing',
                  isActive: false,
                ),
                const SizedBox(width: 10),
                _buildOrderStatusPill(
                  context,
                  icon: Icons.local_shipping_outlined,
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFEFF6FF),
                  count: '${ref.watch(readyOrdersCountProvider)}',
                  label: 'Ready',
                  isActive: false,
                ),
                const SizedBox(width: 10),
                _buildOrderStatusPill(
                  context,
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF059669),
                  iconBg: const Color(0xFFECFDF5),
                  count: '${ref.watch(completedOrdersCountProvider)}',
                  label: 'Completed',
                  isActive: false,
                ),
                const SizedBox(width: 10),
                _buildOrderStatusPill(
                  context,
                  icon: Icons.cancel_outlined,
                  iconColor: const Color(0xFFDC2626),
                  iconBg: const Color(0xFFFEF2F2),
                  count: '${ref.watch(cancelledOrdersCountProvider)}',
                  label: 'Cancelled',
                  isActive: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusPill(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String count,
    required String label,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: isActive
            ? const Border(
                bottom: BorderSide(color: Color(0xFFFD9027), width: 2.5),
              )
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: iconColor),
              ),
              const SizedBox(width: 4),
              Text(
                count,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? context.textPrimary : context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesAnalyticsCard(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(analyticsSummaryForProvider(7));
    final week = weekly.value ?? const AnalyticsSummary.empty();
    final dailySales = ref.watch(weeklySalesProvider);

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
                  'Sales Analytics',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'This Week',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textSecondary,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: context.textSecondary,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                weekly.isLoading ? '—' : _money(week.totalSales),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              if (week.salesTrendPercent != null) ...[
                Icon(
                  week.salesTrendPercent! < 0
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 13,
                  color: week.salesTrendPercent! < 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF10B981),
                ),
                Text(
                  '${week.salesTrendPercent!.abs().toStringAsFixed(0)}% vs last week',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: week.salesTrendPercent! < 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF10B981),
                  ),
                ),
              ],
            ],
          ),
          Text(
            'Total Sales',
            style: TextStyle(fontSize: 10, color: context.textSecondary),
          ),
          const SizedBox(height: 14),

          // Custom Painted Chart Area
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(painter: _SalesChartPainter(dailySales)),
          ),
          const SizedBox(height: 6),

          // Days Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Generated from the seven days the chart actually plots — a
              // rolling window ending today. Fixed Mon–Sun labels put today's
              // figure under "Sun" on every day except Sunday.
              for (final day in _chartDayLabels())
                Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: context.textSecondary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingItemsCard(BuildContext context, WidgetRef ref) {
    final topItems = ref.watch(topSellingItemsProvider);

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
                  'Top Selling Items',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/order-history'),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (topItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_basket_outlined,
                    size: 18,
                    color: context.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'No items sold today',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: topItems
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xFFD97706),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.units} sold',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPromoBannerCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEF08A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFD9027),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Color(0xFF181C2E),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Create offers & grow!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF181C2E),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Attract more customers with offers.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Color(0xFF4B5563)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: ElevatedButton(
              onPressed: () => context.push('/offers'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFD9027),
                foregroundColor: const Color(0xFF181C2E),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Create Offer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    final actions = [
      {
        'label': 'Add Menu\nItem',
        'icon': Icons.add_rounded,
        'color': const Color(0xFF10B981),
        'bg': const Color(0xFFECFDF5),
        'route': '/add-product',
      },
      {
        'label': 'Manage\nOffers',
        'icon': Icons.local_offer_outlined,
        'color': const Color(0xFFEF4444),
        'bg': const Color(0xFFFEF2F2),
        'route': '/offers',
      },
      {
        'label': 'Payouts',
        'icon': Icons.account_balance_wallet_outlined,
        'color': const Color(0xFF2563EB),
        'bg': const Color(0xFFEFF6FF),
        'route': '/payouts',
      },
      {
        'label': 'Outlet\nSettings',
        'icon': Icons.settings_outlined,
        'color': const Color(0xFF8B5CF6),
        'bg': const Color(0xFFF5F3FF),
        'route': '/settings',
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions
            .map(
              (a) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => context.push(a['route'].toString()),
                  child: Container(
                    width: 72,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: a['bg'] as Color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            a['icon'] as IconData,
                            color: a['color'] as Color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          a['label'].toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  const _SalesChartPainter(this.values);

  /// One revenue figure per day, oldest first.
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    // Scale against the best day so the line uses the full height. A week with
    // no sales has no shape to draw, and a flat line at the top would imply
    // the opposite of what happened.
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
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = const Color(0xFFFD9027);
    final innerDotPaint = Paint()..color = Colors.white;

    for (final pt in points) {
      canvas.drawCircle(pt, 4, dotPaint);
      canvas.drawCircle(pt, 1.8, innerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) =>
      oldDelegate.values != values;
}
