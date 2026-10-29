import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:quick_commerce_seller/features/orders/presentation/controllers/orders_controller.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingOrders = ref.watch(newOrdersCountProvider);
    final onDashboard = navigationShell.currentIndex == 0;

    return PopScope(
      // Never automatic. On a tab other than Dashboard the shell is the last
      // route, so letting the pop through closed the app from what the seller
      // reads as an inner screen.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (onDashboard) {
          _confirmExit(context);
        } else {
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: context.surface,
            border: Border(top: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
          ),
          child: BottomNavigationBar(
            currentIndex: navigationShell.currentIndex,
            onTap: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            backgroundColor: context.surface,
            selectedItemColor: const Color(0xFFFD9027),
            unselectedItemColor: const Color(0xFF9CA3AF),
            selectedFontSize: 11,
            unselectedFontSize: 11,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined, size: 24),
                activeIcon: Icon(Icons.home_rounded, size: 24),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 24),
                    // Only the orders still awaiting an answer, and only when
                    // there are any — a permanent "8" is not a notification.
                    if (pendingOrders > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFD9027),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$pendingOrders',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                activeIcon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_bag_rounded, size: 24),
                    // Only the orders still awaiting an answer, and only when
                    // there are any — a permanent "8" is not a notification.
                    if (pendingOrders > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFD9027),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$pendingOrders',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Orders',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined, size: 24),
                activeIcon: Icon(Icons.inventory_2_rounded, size: 24),
                label: 'Products',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_outlined, size: 24),
                activeIcon: Icon(Icons.grid_view_rounded, size: 24),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The one place the app closes from. Deliberately a dialog rather than a
  /// press-back-twice toast: a seller mid-shift losing the app to a stray back
  /// press costs them an order.
  void _confirmExit(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Do you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Closes the app the way the OS expects, leaving it in recents.
              SystemNavigator.pop();
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
