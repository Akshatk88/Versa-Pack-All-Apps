import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/features/auth/data/auth_api.dart';
import 'package:quick_commerce_seller/config/router/app_router.dart';
import 'package:quick_commerce_seller/config/theme/app_theme.dart';
import 'package:quick_commerce_seller/config/theme/theme_mode_provider.dart';
import 'package:quick_commerce_seller/core/audio/app_sounds.dart';
import 'package:quick_commerce_seller/core/logging/push_log.dart';
import 'package:quick_commerce_seller/core/notifications/push_service.dart';
import 'package:quick_commerce_seller/core/providers/splash_provider.dart';
import 'package:quick_commerce_seller/core/widgets/no_network_overlay.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_controller.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_state.dart';
import 'package:quick_commerce_seller/features/home/presentation/controllers/store_summary_controller.dart';
import 'package:quick_commerce_seller/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:quick_commerce_seller/features/orders/domain/order_model.dart';
import 'package:quick_commerce_seller/features/orders/presentation/controllers/orders_controller.dart';

class SellerApp extends ConsumerStatefulWidget {
  const SellerApp({super.key});

  @override
  ConsumerState<SellerApp> createState() => _SellerAppState();
}

class _SellerAppState extends ConsumerState<SellerApp>
    with WidgetsBindingObserver {
  static const _launchOrderChannel = MethodChannel(
    'com.versapack.seller/launch_order',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // _launchOrderChannel.setMethodCallHandler((call) async {
    //   if (call.method == 'onNativeLaunchOrder') {
    //     final orderId = (call.arguments as Map?)?['orderId'] as String?;
    //     if (orderId != null && orderId.isNotEmpty) {
    //       _openOrderFromPush(orderId);
    //     }
    //   }
    //   return null;
    // });

    _launchOrderChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNativeLaunchOrder') {
        final args = call.arguments as Map?;

        final orderId = args?['orderId'] as String?;
        final action = args?['action'] as String?;

        if (orderId == null || orderId.isEmpty) {
          return null;
        }

        if (action == 'accept' || action == 'reject') {
          await _handleNativeNotificationAction(
            orderId,
            action!,
          );
        } else {
          _openOrderFromPush(orderId);
        }
      }
      return null;
    });

    _checkAndRequestOverlayPermission();

    // Started here rather than in `main` so the foreground handler has a `ref`
    // to refresh the inbox with. Deliberately not awaited — the first frame
    // must not wait on a permission dialog.
    PushService.init(
      onForegroundMessage: _onPushReceived,
      onToken: (_) => _registerForPush(),
      onOrderTap: _openOrderFromPush,
    );
  }

  Future<void> _checkAndRequestOverlayPermission() async {
    try {
      final bool hasPermission =
          await _launchOrderChannel.invokeMethod('hasOverlayPermission') ?? false;
      pushLog('overlay permission', hasPermission ? 'granted' : 'not granted');
      // Always handed to the native side: it explains and asks only for what
      // is still missing — the overlay, then (Android 14+) full-screen alerts.
      await _launchOrderChannel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      pushLog('overlay permission error', '$e');
    }
  }

  /// A push landed while the app was on screen. Android draws nothing in this
  /// state, so the only way the new order appears is by refetching.
  ///
  /// [newOrderId] is non-null only for a new-order push; every other type
  /// refreshes silently.
  void _onPushReceived(String? newOrderId) {
    ref.invalidate(notificationsControllerProvider);
    ref.read(ordersControllerProvider.notifier).refresh();
    if (newOrderId != null) AppSounds.startNewOrderAlert(newOrderId);
  }

  /// The alert follows the orders, not the push.
  ///
  /// A push only reaches Dart when the app is already on screen, so keying the
  /// alert to it left the common case silent: the order arrives with the app
  /// backgrounded, the seller opens it, and nothing rings. Driving it from the
  /// list instead means every route into an unanswered order sounds — a
  /// foreground push, a notification tap, a cold start, or simply reopening
  /// the app — and it goes quiet the moment none are left, whether that is an
  /// accept, a reject, a customer cancelling, or the window expiring.
  void _syncAlertToOrders(AsyncValue<List<OrderModel>> orders) {
    // Mid-load and error states say nothing about what is waiting; acting on
    // them would cut the alert off every time the list refetches.
    final data = orders.value;
    if (data == null) return;

    final waiting = data.where((o) => o.status == OrderStatus.newOrder);
    if (waiting.isEmpty) {
      AppSounds.stopNewOrderAlert();
      return;
    }
    // Dedupes per order id, so this is a no-op for one already sounding.
    for (final order in waiting) {
      AppSounds.startNewOrderAlert(order.id);
    }
  }

  /// The order a tapped notification asked for, held until it can be shown.
  String? _pendingOrderId;

  Future<void> _handleNativeNotificationAction(
    String orderId,
    String action,
  ) async {
    pushLog(
      'native notification action',
      'action=$action orderId=$orderId',
    );

    try {
      if (action == 'accept') {
        await ref
            .read(ordersControllerProvider.notifier)
            .updateStatus(
              orderId,
              OrderStatus.newOrder,
            );
        AppSounds.stopNewOrderAlert();
        ref.read(ordersControllerProvider.notifier).refresh();
        pushLog('native accept completed', 'orderId=$orderId');
        _navigateToOrdersScreen();
        return;
      }

      if (action == 'reject') {
        await ref
            .read(ordersControllerProvider.notifier)
            .updateStatus(
              orderId,
              OrderStatus.cancelled,
            );
        AppSounds.stopNewOrderAlert();
        ref.read(ordersControllerProvider.notifier).refresh();
        pushLog('native reject completed', 'orderId=$orderId');
        _navigateToOrdersScreen();
        return;
      }
    } catch (e) {
      pushLog('native notification action error', '$e');
      _navigateToOrdersScreen();
    }
  }

  void _navigateToOrdersScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      pushLog('navigation destination', '/orders');
      ref.read(goRouterProvider).go('/orders');
    });
  }

  void _openOrderFromPush(String orderId) {
    // The tap only ever reaches here for a new-order push, so the alert starts
    // on a cold launch too — the seller still has to accept or reject it.
    AppSounds.startNewOrderAlert(orderId);

    // A tap may arrive before the order list or single-order cache has been
    // refreshed. Invalidating both forces a fresh fetch so the details screen
    // sees the current backend state and keeps the Accept/Reject actions live
    // for a newly created order.
    ref.invalidate(orderByIdProvider(orderId));
    ref.read(ordersControllerProvider.notifier).refresh();

    // Held rather than pushed: a tap that launched the app from cold arrives
    // while the splash is still resolving the session, and the router's
    // redirect would bounce any route pushed before then straight back.
    _pendingOrderId = orderId;
    _openPendingOrder();
  }

  void _openPendingOrder() {
    final orderId = _pendingOrderId;
    if (orderId == null) return;
    if (!ref.read(splashCompletedProvider)) return;
    if (ref.read(authControllerProvider) is! AuthAuthenticated) return;

    _pendingOrderId = null;
    // After the frame in which the redirect settles on /home, so the details
    // screen is pushed on top of it and Back returns somewhere that exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      pushLog('navigation destination', '/order-details/$orderId');
      ref.read(goRouterProvider).push('/order-details/$orderId');
    });
  }

  /// Tells the backend which device to push to.
  ///
  /// The token and the session arrive in either order — a returning seller is
  /// authenticated before the token lands, a new one signs in long after it —
  /// so this is called from both sides and does nothing until it has both.
  /// The backend upserts, so calling it twice is free.
  Future<void> _registerForPush() async {
    final token = PushService.token;
    if (token == null) return;
    if (ref.read(authControllerProvider) is! AuthAuthenticated) return;

    try {
      await ref.read(authApiProvider).saveFcmToken(token);
    } on DioException {
      // A device that fails to register just misses pushes until the next
      // launch or token refresh retries. Never worth interrupting the seller.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The process is going away — release the audio players rather than leave
    // an Android MediaPlayer and an audio focus request behind.
    if (state == AppLifecycleState.detached) {
      AppSounds.dispose();
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    // The server is the source of truth. Anything that changed while the app
    // was backgrounded — including a session evicted by a sign-in elsewhere —
    // surfaces on this refresh rather than on the seller's next tap.
    if (ref.read(authControllerProvider) is AuthAuthenticated) {
      ref.read(storeSummaryControllerProvider.notifier).refresh();
      // Orders arrive while the app is backgrounded — that is the whole point
      // of the push. Without this the seller returns to the list they left and
      // the new order is simply missing from it.
      ref.read(ordersControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    // The other half of the race described on [_registerForPush]: covers the
    // seller who signs in after the token has already been acquired.
    ref.listen(authControllerProvider, (_, next) {
      if (next is! AuthAuthenticated) return;
      _registerForPush();
      _openPendingOrder();
    });

    // A cold start from a notification reaches this before it reaches auth.
    ref.listen(splashCompletedProvider, (_, done) {
      if (done) _openPendingOrder();
    });

    ref.listen(ordersControllerProvider, (_, next) => _syncAlertToOrders(next));

    return MaterialApp.router(
      title: 'Versapack Seller',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) =>
          NoNetworkOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
