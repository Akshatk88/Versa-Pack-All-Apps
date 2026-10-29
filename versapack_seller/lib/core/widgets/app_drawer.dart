import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:quick_commerce_seller/features/explore/presentation/controllers/explore_controller.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeProfileAsync = ref.watch(storeProfileProvider);
    final storeProfile = storeProfileAsync.value;
    final isStoreOnline = storeProfile?.isOnline ?? false;
    final storeName = storeProfile?.name ?? 'Your store';

    return Drawer(
      backgroundColor: context.surface,
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
                  storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF181C2E),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isStoreOnline
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB91C1C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isStoreOnline ? 'Online • Accepting Orders' : 'Offline',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF181C2E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home_outlined, color: context.textPrimary),
            title: Text('Dashboard', style: TextStyle(color: context.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              context.go('/home');
            },
          ),
          ListTile(
            leading: Icon(Icons.shopping_bag_outlined, color: context.textPrimary),
            title: Text('Orders', style: TextStyle(color: context.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              context.go('/orders');
            },
          ),
          ListTile(
            leading: Icon(Icons.inventory_2_outlined, color: context.textPrimary),
            title: Text('Products & Inventory', style: TextStyle(color: context.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              context.go('/products');
            },
          ),
          ListTile(
            leading: Icon(Icons.bar_chart_rounded, color: context.textPrimary),
            title: Text('Analytics', style: TextStyle(color: context.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              context.push('/analytics');
            },
          ),
          ListTile(
            leading: Icon(Icons.local_offer_outlined, color: context.textPrimary),
            title: Text('Offers & Coupons', style: TextStyle(color: context.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              context.push('/offers');
            },
          ),
          ListTile(
            leading: Icon(Icons.account_balance_wallet_outlined, color: context.textPrimary),
            title: Text('Payouts', style: TextStyle(color: context.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              context.push('/payouts');
            },
          ),
          ListTile(
            leading: Icon(Icons.headset_mic_outlined, color: context.textPrimary),
            title: Text('Support', style: TextStyle(color: context.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              context.push('/support');
            },
          ),
          ListTile(
            leading: Icon(Icons.settings_outlined, color: context.textPrimary),
            title: Text('Settings', style: TextStyle(color: context.textPrimary)),
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
