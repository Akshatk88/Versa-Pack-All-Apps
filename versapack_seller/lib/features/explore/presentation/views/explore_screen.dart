import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/features/explore/presentation/controllers/explore_controller.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeProfileAsync = ref.watch(storeProfileProvider);
    // Nullable on purpose: an unknown availability must not read as "Online".
    final isOnline = storeProfileAsync.value?.isOnline;

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        title: Text(
          'Store Management Hub',
          style: AppTextStyles.h3.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildExploreTile(
            context,
            icon: Icons.storefront_rounded,
            title: 'Outlet Status',
            subtitle: switch (isOnline) {
              null => 'Checking availability…',
              true => 'Online (Accepting Orders)',
              false => 'Offline (Paused)',
            },
            route: '/restaurant-status',
            isStatus: true,
            statusColor: switch (isOnline) {
              null => AppColors.textSecondaryLight,
              true => const Color(0xFF22C55E),
              false => const Color(0xFFEF4444),
            },
          ),
          const SizedBox(height: 10),
          _buildExploreTile(
            context,
            icon: Icons.access_time_rounded,
            title: 'Outlet Timings',
            subtitle: 'Manage 7-day operating hours',
            route: '/outlet-timings',
          ),
          const SizedBox(height: 10),
          _buildExploreTile(
            context,
            icon: Icons.info_outline_rounded,
            title: 'Outlet Information',
            subtitle: 'Store profile, address & banner photo',
            route: '/outlet-info',
          ),
          // const SizedBox(height: 10),
          // _buildExploreTile(
          //   context,
          //   icon: Icons.local_shipping_outlined,
          //   title: 'Delivery Settings',
          //   subtitle: 'Delivery radius, fees & packaging',
          //   route: '/delivery-settings',
          // ),
          const SizedBox(height: 10),
          _buildExploreTile(
            context,
            icon: Icons.map_outlined,
            title: 'Zone Setup',
            subtitle: 'Manage serviceable delivery zones',
            route: '/zone-setup',
          ),
          const SizedBox(height: 10),
          _buildExploreTile(
            context,
            icon: Icons.category_outlined,
            title: 'Product Categories',
            subtitle: 'Organise catalogue & visibility',
            route: '/categories',
          ),
          const SizedBox(height: 10),
          _buildExploreTile(
            context,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Payouts & Settlements',
            subtitle: 'Balance, withdrawals & bank account',
            route: '/payouts',
          ),
          const SizedBox(height: 10),
          _buildExploreTile(
            context,
            icon: Icons.receipt_long_outlined,
            title: 'Order History',
            subtitle: 'Past & completed orders',
            route: '/order-history',
          ),
          const SizedBox(height: 10),
          _buildExploreTile(
            context,
            icon: Icons.local_offer_outlined,
            title: 'Offers & Coupons',
            subtitle: 'Create promo codes & customer discounts',
            route: '/offers',
          ),
          const SizedBox(height: 10),
          _buildExploreTile(
            context,
            icon: Icons.help_outline_rounded,
            title: 'Support & FAQs',
            subtitle: 'Contact support & live assistance',
            route: '/support',
          ),
          const SizedBox(height: 10),
          _buildExploreTile(
            context,
            icon: Icons.star_outline_rounded,
            title: 'Feedback & Reviews',
            subtitle: 'Customer ratings & reply to reviews',
            route: '/feedback',
          ),
          const SizedBox(height: 10),
          _buildExploreTile(
            context,
            icon: Icons.report_problem_outlined,
            title: 'Customer Complaints',
            subtitle: 'View and resolve order disputes',
            route: '/complaints',
          ),
          const SizedBox(height: 10),
          _buildExploreTile(
            context,
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Alerts, sound & system updates',
            route: '/notifications',
          ),
          const SizedBox(height: 10),
          _buildExploreTile(
            context,
            icon: Icons.settings_outlined,
            title: 'App Settings',
            subtitle: 'Theme mode, account & preferences',
            route: '/settings',
          ),
        ],
      ),
    );
  }

  Widget _buildExploreTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    bool isStatus = false,
    Color? statusColor,
  }) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF181C2E), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: const Color(0xFF181C2E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: isStatus
                          ? (statusColor ?? AppColors.successText)
                          : AppColors.textSecondaryLight,
                      fontWeight: isStatus
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
    );
  }
}
