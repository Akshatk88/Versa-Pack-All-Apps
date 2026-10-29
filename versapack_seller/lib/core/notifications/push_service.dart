import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quick_commerce_seller/core/logging/push_log.dart';
import 'package:quick_commerce_seller/core/logging/startup_log.dart';

/// Runs in its own isolate when a message arrives with the app backgrounded or
/// killed, so nothing from the running app is in scope here.
///
/// It exists to make the delivery visible in a debug run: the backend sends the
/// new-order alert as two messages (a notification leg Android draws by itself,
/// then a data-only leg), and without this the data-only leg leaves no trace at
/// all — making "the push never arrived" indistinguishable from "it arrived and
/// the tap did nothing".
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  PushService.printFcmData('BACKGROUND ISOLATE', message);
  pushLog('background message', PushService.describe(message));
  // No overlay call here: SellerMessagingService has already drawn it natively,
  // and the overlay channel lives on MainActivity, which this isolate cannot
  // reach — calling it only logged a MissingPluginException on every order.
}

/// Firebase Cloud Messaging: registration, and routing a tapped new-order
/// notification to the order it refers to.
///
/// There is no separate "save my token" call at sign-in: the backend attaches
/// [token] to the seller on `verify-otp` and detaches it on `logout`. See
/// `auth_controller.dart` for both ends and `app.dart` for the re-registration
/// that covers an already-signed-in seller.
class PushService {
  const PushService._();

  static const MethodChannel _launchChannel =
      MethodChannel('com.versapack.seller/launch_order');

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Triggers native Android system overlay window for new orders.
  static Future<void> showNativeOverlay(RemoteMessage message) async {
    final orderId = orderIdOf(message);
    if (orderId == null || orderId.isEmpty) return;
    try {
      await _launchChannel.invokeMethod('showOverlay', {
        'orderId': orderId,
        'orderDisplayId': (message.data['orderDisplayId'] ?? '').toString(),
        'customerName': (message.data['customerName'] ?? '').toString(),
        'itemCount': (message.data['itemCount'] ?? '').toString(),
        'body': message.notification?.body ?? (message.data['body'] ?? '').toString(),
        'address': (message.data['address'] ?? '').toString(),
        'itemsList': (message.data['itemsList'] ?? '').toString(),
        'total': (message.data['total'] ?? '').toString(),
      });
    } catch (e) {
      debugPrint('Failed to show native overlay from Dart: $e');
    }
  }

  /// Prints full FCM message details to console in formatted JSON.
  static void printFcmData(String triggerState, RemoteMessage message) {
    if (!kDebugMode) return;
    const encoder = JsonEncoder.withIndent('  ');

    final Map<String, dynamic> parsedData = {};
    message.data.forEach((key, value) {
      if (value is String) {
        final trimmed = value.trim();
        if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
            (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
          try {
            parsedData[key] = jsonDecode(trimmed);
          } catch (_) {
            parsedData[key] = value;
          }
        } else {
          parsedData[key] = value;
        }
      } else {
        parsedData[key] = value;
      }
    });

    final payloadMap = {
      'triggerState': triggerState,
      'messageId': message.messageId,
      'sentTime': message.sentTime?.toIso8601String(),
      'notification': message.notification == null
          ? null
          : {
              'title': message.notification?.title,
              'body': message.notification?.body,
              'androidChannelId': message.notification?.android?.channelId,
            },
      'data': parsedData,
    };

    final jsonString = encoder.convert(payloadMap);
    debugPrint(
      '\n=================== 📩 FCM NOTIFICATION JSON ($triggerState) ===================\n'
      '$jsonString\n'
      '===================================================================================\n',
    );
  }

  /// The device's FCM token, or null when push is unavailable — Firebase not
  /// configured for this platform, or the seller declined the permission.
  static String? token;

  /// The `type` the backend stamps on a new-order push. Defined by
  /// `notifyRestaurantNewOrder` in the backend's `order.helpers.js`; this app
  /// reads that payload rather than asking for a new one.
  static const String newOrderType = 'new_order';

  /// Best-effort by design. Push is an enhancement; a missing
  /// `GoogleService-Info.plist` or a denied permission must never stop the
  /// seller from signing in and working.
  ///
  /// [onOrderTap] fires with the order id from a tapped new-order
  /// notification, in every app state — foreground, background and killed.
  /// [onForegroundMessage] receives the new-order id when that is what
  /// arrived, and null for every other push — so the caller can sound the
  /// new-order alert without having to know the payload format, and can never
  /// sound it for an unrelated notification.
  static Future<void> init({
    void Function(String? newOrderId)? onForegroundMessage,
    void Function(String token)? onToken,
    void Function(String orderId)? onOrderTap,
  }) async {
    try {
      await Firebase.initializeApp();

      final messaging = FirebaseMessaging.instance;
      // Android 13+ and iOS both gate the notification tray behind this. It is
      // a no-op on older Android.
      final settings = await messaging.requestPermission();
      pushLog('permission', settings.authorizationStatus.name);

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: (response) {
          final orderId = response.payload;
          if (orderId != null && orderId.isNotEmpty) onOrderTap?.call(orderId);
        },
      );

      // Must be registered before any await on a message stream, and only from
      // the main isolate.
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      token = await messaging.getToken();
      debugPrint('FCM TOKEN: $token');
      startupLog('push: token', token == null ? 'none' : 'acquired');
      // Tail only — enough to match against the backend's stored token in a
      // debug session without putting a working push credential in the log.
      final tail = token == null
          ? 'none'
          : '…${token!.length > 12 ? token!.substring(token!.length - 12) : token!}';
      pushLog('token', tail);
      if (token != null) onToken?.call(token!);

      // Tokens rotate on app restore or a cleared cache. The old one stops
      // delivering, so the backend has to hear about the new one immediately —
      // waiting for the next sign-in would silently drop every push until then.
      messaging.onTokenRefresh.listen((value) {
        token = value;
        pushLog('token refreshed');
        onToken?.call(value);
      });

      FirebaseMessaging.onMessage.listen((message) async {
        printFcmData('FOREGROUND', message);
        final msgType = (message.data['type'] ?? '').toString();
        final orderId = orderIdOf(message);
        debugPrint(
          'FCM foreground payload: type=$msgType orderId=$orderId data=${message.data}',
        );
        pushLog('foreground message', describe(message));

        final isNewOrder = msgType == newOrderType;

        if (isNewOrder) {
          showNativeOverlay(message);
        } else {
          await _showForegroundNotification(
            message,
            false,
          );
        }

        onForegroundMessage?.call(
          isNewOrder ? orderId : null,
        );
      });

      // App alive but backgrounded — the tap resumes it and delivers here.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        printFcmData('TAPPED (BACKGROUND)', message);
        final msgType = (message.data['type'] ?? '').toString();
        final orderId = orderIdOf(message);
        debugPrint(
          'FCM tapped background payload: type=$msgType orderId=$orderId data=${message.data}',
        );
        pushLog('notification tapped (background)', describe(message));
        _routeTap(message, onOrderTap);
      });

      // App was killed: the message that launched it is waiting here, once
      // only. Nothing else reports this case.
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        printFcmData('INITIAL (COLD START)', initial);
        final msgType = (initial.data['type'] ?? '').toString();
        final orderId = orderIdOf(initial);
        debugPrint(
          'FCM initial payload: type=$msgType orderId=$orderId data=${initial.data}',
        );
        pushLog('app launched from notification', describe(initial));
        _routeTap(initial, onOrderTap);
      }
    } catch (error) {
      // Most often: no google-services.json / GoogleService-Info.plist for this
      // platform. Logged rather than swallowed so it is visible in a debug run.
      startupLog('push: init failed', error);
      pushLog('init failed', error);
    }
  }

  static Future<void> _showForegroundNotification(
    RemoteMessage message,
    bool isNewOrder,
  ) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    final orderId = orderIdOf(message);
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title ?? 'Versapack Seller',
      body: body ?? 'You have a new update',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          isNewOrder ? 'new_order_channel' : 'high_importance_channel',
          isNewOrder ? 'New orders' : 'General notifications',
          channelDescription: isNewOrder
              ? 'Orders waiting to be accepted'
              : 'Order updates, payouts and announcements',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: orderId,
    );
  }

  static void _routeTap(
    RemoteMessage message,
    void Function(String orderId)? onOrderTap,
  ) {
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    final orderId = orderIdOf(message);

    pushLog('notification type', type.isEmpty ? '<none>' : type);
    pushLog('order id', orderId ?? '<none>');

    if (type != newOrderType || orderId == null) {
      // Any other push just opens the app. Guessing a destination from a
      // payload this app does not understand is how sellers end up on a blank
      // screen with no way back to what they were doing.
      pushLog('navigation destination', 'none (not a new-order push)');
      return;
    }

    onOrderTap?.call(orderId);
  }

  /// The Mongo id the order routes are keyed by.
  ///
  /// `orderId` is what the backend sends; `orderMongoId` is the same value
  /// under an older name. `orderDisplayId` is deliberately not a fallback — it
  /// is the human-facing reference (`order_id`) and the API would 404 on it.
  static String? orderIdOf(RemoteMessage message) {
    for (final key in const ['orderId', 'orderMongoId']) {
      final value = (message.data[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  /// Compact one-line summary for the debug log. Only the fields that decide
  /// routing — the payload also carries the rendered body, which is long and
  /// tells us nothing about why a tap went astray.
  static String describe(RemoteMessage message) {
    final data = message.data;
    return 'type=${data['type'] ?? '-'} '
        'orderId=${data['orderId'] ?? '-'} '
        'display=${data['orderDisplayId'] ?? '-'} '
        'hasNotification=${message.notification != null}';
  }
}
