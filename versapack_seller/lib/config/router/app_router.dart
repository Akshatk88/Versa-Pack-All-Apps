import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/core/logging/startup_log.dart';
import 'package:quick_commerce_seller/core/providers/onboarding_provider.dart';
import 'package:quick_commerce_seller/core/providers/splash_provider.dart';
import 'package:quick_commerce_seller/features/analytics/presentation/views/analytics_screen.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_controller.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_state.dart';
import 'package:quick_commerce_seller/features/auth/presentation/views/account_status_screen.dart';
import 'package:quick_commerce_seller/features/auth/presentation/views/login_screen.dart';
import 'package:quick_commerce_seller/features/auth/presentation/views/registration_screen.dart';
import 'package:quick_commerce_seller/features/auth/presentation/views/registration_documents_screen.dart';
import 'package:quick_commerce_seller/features/auth/presentation/views/registration_success_screen.dart';
import 'package:quick_commerce_seller/features/complaints/presentation/views/complaints_screen.dart';
import 'package:quick_commerce_seller/features/explore/presentation/views/delivery_settings_screen.dart';
import 'package:quick_commerce_seller/features/explore/presentation/views/outlet_info_screen.dart';
import 'package:quick_commerce_seller/features/explore/presentation/views/outlet_timings_screen.dart';
import 'package:quick_commerce_seller/features/explore/presentation/views/restaurant_status_screen.dart';
import 'package:quick_commerce_seller/features/explore/presentation/views/zone_setup_screen.dart';
import 'package:quick_commerce_seller/features/feedback/presentation/views/feedback_screen.dart';
import 'package:quick_commerce_seller/features/home/presentation/views/home_screen.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/views/add_product_screen.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/views/categories_screen.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/views/product_details_screen.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/views/products_screen.dart';
import 'package:quick_commerce_seller/features/explore/presentation/views/explore_screen.dart';
import 'package:quick_commerce_seller/features/main_layout/presentation/views/main_shell.dart';
import 'package:quick_commerce_seller/features/notifications/presentation/views/notifications_screen.dart';
import 'package:quick_commerce_seller/features/offers/presentation/views/create_coupon_screen.dart';
import 'package:quick_commerce_seller/features/offers/presentation/views/offers_screen.dart';
import 'package:quick_commerce_seller/features/orders/presentation/views/order_details_screen.dart';
import 'package:quick_commerce_seller/features/orders/presentation/views/order_history_screen.dart';
import 'package:quick_commerce_seller/features/orders/presentation/views/orders_screen.dart';
import 'package:quick_commerce_seller/features/payouts/presentation/views/bank_details_screen.dart';
import 'package:quick_commerce_seller/features/payouts/presentation/views/payouts_screen.dart';
import 'package:quick_commerce_seller/features/settings/presentation/views/settings_screen.dart';
import 'package:quick_commerce_seller/features/splash/presentation/views/splash_screen.dart';
import 'package:quick_commerce_seller/features/support/presentation/views/help_center_screen.dart';
import 'package:quick_commerce_seller/features/support/presentation/views/privacy_policy_screen.dart';
import 'package:quick_commerce_seller/features/support/presentation/views/support_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'home',
);
final GlobalKey<NavigatorState> _ordersNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'orders',
);
final GlobalKey<NavigatorState> _productsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'products');
final GlobalKey<NavigatorState> _exploreNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'explore');

/// The splash route. Transient by definition: it exists only while the session
/// is being resolved, and is never a legal place to come to rest.
const String splashRoute = '/';

/// Routes reachable while logged out.
const Set<String> _publicRoutes = {
  '/login',
  '/registration',
  '/registration-success',
};
const Set<String> _blockedRoutes = {'/account-status'};

/// Pure redirect policy, extracted so it can be tested without a widget tree.
///
/// Returns the location to move to, or `null` to stay put. The splash screen
/// remains active until [splashCompleted] is true AND [auth] is resolved.
String? resolveRedirect({
  required AuthState auth,
  required String location,
  required bool hasSeenOnboarding,
  required bool splashCompleted,
}) {
  final isSplash = location == splashRoute;

  // Enforce splash screen visibility until splash process finishes (initialization + minimum display delay).
  if (isSplash && !splashCompleted) return null;

  // Still resolving the stored session. The splash is the only legal place.
  if (auth is AuthInitial) return isSplash ? null : splashRoute;

  if (auth is AuthPendingApproval || auth is AuthRejected) {
    return _blockedRoutes.contains(location) ? null : '/account-status';
  }

  if (auth is AuthAuthenticated) {
    if (isSplash ||
        _publicRoutes.contains(location) ||
        _blockedRoutes.contains(location)) {
      return '/home';
    }
    return null;
  }

  // The phone verified but no store is attached to it.
  if (auth is AuthNeedsRegistration) {
    const allowed = {'/registration', '/registration-success'};
    return allowed.contains(location) ? null : '/registration';
  }

  // Logged out or mid-OTP.
  if (isSplash) return '/login';
  if (_publicRoutes.contains(location)) return null;
  return '/login';
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _GoRouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/registration',
        builder: (_, _) => const RegistrationScreen(),
      ),
      GoRoute(
        path: '/registration-documents',
        builder: (_, _) => const RegistrationDocumentsScreen(),
      ),
      GoRoute(
        path: '/registration-success',
        builder: (_, _) => const RegistrationSuccessScreen(),
      ),
      GoRoute(
        path: '/account-status',
        builder: (_, _) => const AccountStatusScreen(),
      ),

      // Global Sub-routes
      GoRoute(path: '/analytics', builder: (_, _) => const AnalyticsScreen()),
      GoRoute(
        path: '/product-details/:productId',
        builder: (_, state) =>
            ProductDetailsScreen(productId: state.pathParameters['productId']!),
      ),
      GoRoute(
        path: '/add-product',
        builder: (_, _) => const AddProductScreen(),
        routes: [
          GoRoute(
            path: ':productId',
            builder: (_, state) =>
                AddProductScreen(productId: state.pathParameters['productId']),
          ),
        ],
      ),
      GoRoute(
        path: '/order-details/:orderId',
        builder: (_, state) =>
            OrderDetailsScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: '/order-history',
        builder: (_, _) => const OrderHistoryScreen(),
      ),
      GoRoute(path: '/categories', builder: (_, _) => const CategoriesScreen()),
      GoRoute(path: '/payouts', builder: (_, _) => const PayoutsScreen()),
      GoRoute(
        path: '/bank-details',
        builder: (_, _) => const BankDetailsScreen(),
      ),
      GoRoute(
        path: '/restaurant-status',
        builder: (_, _) => const RestaurantStatusScreen(),
      ),
      GoRoute(
        path: '/outlet-timings',
        builder: (_, _) => const OutletTimingsScreen(),
      ),
      GoRoute(
        path: '/outlet-info',
        builder: (_, _) => const OutletInfoScreen(),
      ),
      GoRoute(
        path: '/delivery-settings',
        builder: (_, _) => const DeliverySettingsScreen(),
      ),
      GoRoute(path: '/zone-setup', builder: (_, _) => const ZoneSetupScreen()),
      GoRoute(path: '/offers', builder: (_, _) => const OffersScreen()),
      GoRoute(
        path: '/create-coupon',
        builder: (_, _) => const CreateCouponScreen(),
      ),
      GoRoute(path: '/complaints', builder: (_, _) => const ComplaintsScreen()),
      GoRoute(path: '/support', builder: (_, _) => const SupportScreen()),
      GoRoute(
        path: '/privacy-policy',
        builder: (_, _) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/help-center',
        builder: (_, _) => const HelpCenterScreen(),
      ),
      GoRoute(path: '/feedback', builder: (_, _) => const FeedbackScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),

      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _ordersNavigatorKey,
            routes: [
              GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _productsNavigatorKey,
            routes: [
              GoRoute(
                path: '/products',
                builder: (_, _) => const ProductsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _exploreNavigatorKey,
            routes: [
              GoRoute(
                path: '/explore',
                builder: (_, _) => const ExploreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final splashCompleted = ref.read(splashCompletedProvider);
      final location = state.matchedLocation;
      final destination = resolveRedirect(
        auth: auth,
        location: location,
        hasSeenOnboarding: ref.read(hasSeenOnboardingProvider),
        splashCompleted: splashCompleted,
      );
      startupLog(
        'router.redirect',
        '${auth.runtimeType} at $location (splashCompleted=$splashCompleted) -> ${destination ?? "(stay)"}',
      );
      return destination;
    },
  );
});

class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    _authSubscription = ref.listen<AuthState>(
      authControllerProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
    _splashSubscription = ref.listen<bool>(
      splashCompletedProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }

  late final ProviderSubscription<AuthState> _authSubscription;
  late final ProviderSubscription<bool> _splashSubscription;

  @override
  void dispose() {
    _authSubscription.close();
    _splashSubscription.close();
    super.dispose();
  }
}
