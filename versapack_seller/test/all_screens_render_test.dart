import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/config/theme/app_theme.dart';
import 'package:quick_commerce_seller/features/analytics/presentation/views/analytics_screen.dart';
import 'package:quick_commerce_seller/features/auth/presentation/views/account_status_screen.dart';
import 'package:quick_commerce_seller/features/auth/presentation/views/login_screen.dart';
import 'package:quick_commerce_seller/features/auth/presentation/views/registration_screen.dart';
import 'package:quick_commerce_seller/features/auth/presentation/views/registration_success_screen.dart';
import 'package:quick_commerce_seller/features/complaints/presentation/views/complaints_screen.dart';
import 'package:quick_commerce_seller/features/explore/presentation/views/delivery_settings_screen.dart';
import 'package:quick_commerce_seller/features/explore/presentation/views/explore_screen.dart';
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
import 'package:quick_commerce_seller/features/notifications/presentation/views/notifications_screen.dart';
import 'package:quick_commerce_seller/features/offers/presentation/views/create_coupon_screen.dart';
import 'package:quick_commerce_seller/features/offers/presentation/views/offers_screen.dart';
import 'package:quick_commerce_seller/features/orders/presentation/views/order_details_screen.dart';
import 'package:quick_commerce_seller/features/orders/presentation/views/order_history_screen.dart';
import 'package:quick_commerce_seller/features/orders/presentation/views/orders_screen.dart';
import 'package:quick_commerce_seller/features/payouts/presentation/views/bank_details_screen.dart';
import 'package:quick_commerce_seller/features/payouts/presentation/views/payouts_screen.dart';
import 'package:quick_commerce_seller/features/settings/presentation/views/settings_screen.dart';
import 'package:quick_commerce_seller/features/support/presentation/views/help_center_screen.dart';
import 'package:quick_commerce_seller/features/support/presentation/views/privacy_policy_screen.dart';
import 'package:quick_commerce_seller/features/support/presentation/views/support_screen.dart';

/// Every screen, rendered under the real [AppTheme] at a small and a large
/// viewport. Catches the two failure modes a per-screen test tends to miss:
/// layout asserts that only fire under the app's own theme, and overflow on
/// narrow devices. A screen added without a line here is a screen nobody
/// smoke-tests, so keep this list exhaustive.
const Map<String, Widget> screens = {
  'HomeScreen': HomeScreen(),
  'OrdersScreen': OrdersScreen(),
  'OrderDetailsScreen': OrderDetailsScreen(orderId: 'smoke-test-order'),
  'OrderHistoryScreen': OrderHistoryScreen(),
  'ProductsScreen': ProductsScreen(),
  'ProductDetailsScreen': ProductDetailsScreen(productId: 'smoke-test-product'),
  'CategoriesScreen': CategoriesScreen(),
  'AddProductScreen': AddProductScreen(),
  'ExploreScreen': ExploreScreen(),
  'RestaurantStatusScreen': RestaurantStatusScreen(),
  'OutletTimingsScreen': OutletTimingsScreen(),
  'OutletInfoScreen': OutletInfoScreen(),
  'DeliverySettingsScreen': DeliverySettingsScreen(),
  'ZoneSetupScreen': ZoneSetupScreen(),
  'PayoutsScreen': PayoutsScreen(),
  'BankDetailsScreen': BankDetailsScreen(),
  'OffersScreen': OffersScreen(),
  'CreateCouponScreen': CreateCouponScreen(),
  'AnalyticsScreen': AnalyticsScreen(),
  'NotificationsScreen': NotificationsScreen(),
  'ComplaintsScreen': ComplaintsScreen(),
  'FeedbackScreen': FeedbackScreen(),
  'SupportScreen': SupportScreen(),
  'PrivacyPolicyScreen': PrivacyPolicyScreen(),
  'HelpCenterScreen': HelpCenterScreen(),
  'SettingsScreen': SettingsScreen(),
  'LoginScreen': LoginScreen(),
  'RegistrationScreen': RegistrationScreen(),
  'RegistrationSuccessScreen': RegistrationSuccessScreen(),
  'AccountStatusScreen': AccountStatusScreen(),
  // SplashScreen is deliberately absent: it owns a bootstrap timer and routes
  // itself away, so it needs its own harness — see splash_screen_layout_test.
};

/// Small = iPhone SE class, the narrowest phone worth supporting.
/// Large = Pixel 6a class.
///
/// The 1.5x case is the accessibility font-size setting, not an edge case —
/// it is one drag of a system slider and it broke 13 screens. Both themes are
/// covered because dark mode is user-selectable in Settings.
const cases = {
  'small 320x568': (Size(320, 568), 1.0, true),
  'large 412x915': (Size(412, 915), 1.0, true),
  'small 320x568 @1.5x text': (Size(320, 568), 1.5, true),
  'large 412x915 @1.5x text': (Size(412, 915), 1.5, true),
  'large 412x915 dark': (Size(412, 915), 1.0, false),
};

void main() {
  for (final testCase in cases.entries) {
    final (size, textScale, isLight) = testCase.value;
    group(testCase.key, () {
      for (final screen in screens.entries) {
        testWidgets('${screen.key} lays out cleanly', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          // Collect details ourselves: takeException() surfaces only the
          // exception object, and the widget that caused an overflow lives in
          // the details. Without this a failure says "overflowed by 384px"
          // and nothing about where.
          final errors = <FlutterErrorDetails>[];
          final previousOnError = FlutterError.onError;
          FlutterError.onError = errors.add;
          try {
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  theme: isLight ? AppTheme.light : AppTheme.dark,
                  builder: (context, child) =>
                      MediaQuery.withClampedTextScaling(
                        minScaleFactor: textScale,
                        maxScaleFactor: textScale,
                        child: child!,
                      ),
                  home: screen.value,
                ),
              ),
            );
            // Bounded pumps, not pumpAndSettle: mock repositories resolve
            // behind a Future.delayed that schedules no frames, and screens
            // with a progress spinner never settle at all. Two timed pumps
            // reach the loaded state without depending on quiescence.
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump(const Duration(milliseconds: 400));
          } finally {
            FlutterError.onError = previousOnError;
          }

          expect(
            errors,
            isEmpty,
            reason:
                '${screen.key} @ ${testCase.key}\n'
                '${errors.map((e) => e.toString()).join('\n---\n')}',
          );
        });
      }
    });
  }
}
