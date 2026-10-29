import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/widgets/feedback/app_dialog.dart';

import '../../core/constants/app_durations.dart';
import '../../core/utils/app_haptics.dart';
import '../../core/utils/logger.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../di/app_providers.dart';
import '../common/widgets/misc/fly_to_cart.dart';

/// Bottom navigation for the five top-level destinations, with the delivery
/// promise raised into a centre badge that doubles as the cart entry point.
///
/// The badge carries [cartAnchorKey] so the fly-to-cart animation knows where
/// to land from anywhere in the app.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// The visual order differs from the router's branch order, so each item
  /// names its branch explicitly rather than relying on position.
  /// Router branches: 0 home · 1 categories · 2 cart · 3 orders · 4 profile.
  static const _cartBranchIndex = 2;
  static const _homeBranchIndex = 0;

  static const _left = [
    (0, Icons.home_outlined, Icons.home_rounded, 'Home'),
    (3, Icons.replay_outlined, Icons.replay_rounded, 'Order Again'),
  ];

  static const _right = [
    (1, Icons.grid_view_outlined, Icons.grid_view_rounded, 'Categories'),
    (4, Icons.person_outline_rounded, Icons.person_rounded, 'Account'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartItemCountProvider);
    final current = navigationShell.currentIndex;

    // Back on a tab root used to fall straight through to the OS and close the
    // app — there is nothing above the shell to pop, and switching tabs with
    // `go` leaves no history entry behind. Only Home is allowed to exit, and
    // only after asking.
    //
    // Screens pushed on top of the shell (product, order details, checkout …)
    // are separate routes on the root navigator, so their back press is handled
    // by the Navigator and never reaches this callback. Deep links are
    // unaffected for the same reason.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (current != _homeBranchIndex) {
          // Any other tab returns to Home first, the way a back press is
          // expected to behave on Android.
          _go(_homeBranchIndex);
          return;
        }
        await _confirmExit(context);
      },
      child: _scaffold(context, cartCount, current),
    );
  }

  /// Home is the only place the app may be closed from, and never silently.
  Future<void> _confirmExit(BuildContext context) async {
    AppLogger.action('back', details: 'confirm_exit');
    final shouldExit = await AppDialog.confirm(
      context,
      icon: Icons.exit_to_app_rounded,
      title: 'Do you want to exit the app?',
      message: 'Your cart is saved and will be waiting when you come back.',
      confirmLabel: 'Exit',
      cancelLabel: 'Cancel',
    );
    if (!shouldExit) return;
    AppLogger.action('exit_app', details: 'confirmed');

    // `SystemNavigator.pop` backs out of the app the way the OS expects,
    // leaving it resumable from Recents. `exit(0)` would kill the process and
    // is what Android's own guidance warns against.
    await SystemNavigator.pop();
  }

  Widget _scaffold(BuildContext context, int cartCount, int current) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.semantic.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72, // 68 -> 72, matches the taller centre badge below
            child: Row(
              children: [
                for (final item in _left)
                  Expanded(
                    child: _NavItem(
                      spec: item,
                      selected: current == item.$1,
                      onTap: () => _go(item.$1),
                    ),
                  ),
                Expanded(
                  child: _CentreBadge(
                    count: cartCount,
                    onTap: () => _go(_cartBranchIndex),
                  ),
                ),
                for (final item in _right)
                  Expanded(
                    child: _NavItem(
                      spec: item,
                      selected: current == item.$1,
                      onTap: () => _go(item.$1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _go(int index) {
    AppLogger.action('navigation_tab', details: 'branch=$index');
    // Only cue an actual tab change — re-tapping the current tab (which just
    // pops to its root) should not buzz.
    if (index != navigationShell.currentIndex) AppHaptics.selection();
    navigationShell.goBranch(
      index,
      // Tapping the active tab pops it back to its root.
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  /// (branch index, unselected icon, selected icon, label)
  final (int, IconData, IconData, String) spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? context.colors.primary
        : context.semantic.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: spec.$4,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? spec.$3 : spec.$2, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              spec.$4,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall!.copyWith(
                color: selected
                    ? context.colors.primary
                    : context.semantic.textSecondary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CentreBadge extends StatelessWidget {
  const _CentreBadge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? 'Cart, $count items' : 'Quick Delivery',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 68,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 8,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      key: cartAnchorKey,
                      height: 72,
                      width: 76,
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: context.colors.surface,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.14),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delivery_dining_outlined,
                            color: context.colors.onPrimary,
                            size: 24, // 26 -> 24
                          ),
                          const SizedBox(height: 1), // 2 -> 1
                          Text(
                            'Delivery in',
                            style: context.text.labelSmall!.copyWith(
                              color: context.colors.onPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 9,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '10 mins',
                            style: context.text.labelSmall!.copyWith(
                              color: context.colors.onPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(count),
                          tween: Tween(begin: 0.6, end: 1),
                          duration: AppDurations.medium,
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 1,
                            ),
                            constraints: const BoxConstraints(minWidth: 18),
                            decoration: BoxDecoration(
                              color: context.semantic.danger,
                              borderRadius: AppRadii.rPill,
                              border: Border.all(
                                color: context.colors.surface,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: context.text.labelSmall!.copyWith(
                                color: context.colors.surface,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}