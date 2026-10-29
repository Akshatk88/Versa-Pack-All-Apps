import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/router/app_router.dart';

/// Every path the UI navigates to must exist in the router.
///
/// `/payouts` was pushed from the dashboard drawer, the Payouts quick action
/// and a notification's targetRoute while no route declared it — each of those
/// taps landed on go_router's error page. A missing route is invisible until
/// someone taps, so assert the wiring instead.
///
/// When you add a `context.push('/x')`, add '/x' here. Parameterised routes are
/// listed in their declared form (`/order-details/:orderId`), since that is what
/// the router registers.
const navigableRoutes = {
  '/',
  '/onboarding',
  '/login',
  '/registration',
  '/registration-documents',
  '/registration-success',
  '/account-status',
  '/home',
  '/orders',
  '/order-details/:orderId',
  '/order-history',
  '/products',
  '/product-details/:productId',
  '/add-product',
  // Nested under /add-product: the same screen in edit mode.
  ':productId',
  '/categories',
  '/explore',
  '/restaurant-status',
  '/outlet-timings',
  '/outlet-info',
  '/delivery-settings',
  '/zone-setup',
  '/payouts',
  '/bank-details',
  '/offers',
  '/create-coupon',
  '/analytics',
  '/notifications',
  '/complaints',
  '/support',
  '/feedback',
  '/settings',
};

Set<String> _collectPaths(List<RouteBase> routes) {
  final paths = <String>{};
  for (final route in routes) {
    if (route is GoRoute) paths.add(route.path);
    paths.addAll(_collectPaths(route.routes));
    if (route is StatefulShellRoute) {
      for (final branch in route.branches) {
        paths.addAll(_collectPaths(branch.routes));
      }
    }
  }
  return paths;
}

void main() {
  test('every navigable route is registered', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(goRouterProvider);

    final registered = _collectPaths(router.configuration.routes);

    expect(
      navigableRoutes.difference(registered),
      isEmpty,
      reason: 'these paths are navigated to but have no GoRoute',
    );
  });

  test('no route is registered without a way to reach it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(goRouterProvider);

    final registered = _collectPaths(router.configuration.routes);

    expect(
      registered.difference(navigableRoutes),
      isEmpty,
      reason:
          'these routes exist but nothing navigates to them — either wire '
          'up an entry point or delete the screen',
    );
  });
}
