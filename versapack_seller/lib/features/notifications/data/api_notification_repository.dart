import 'package:dio/dio.dart';
import 'package:quick_commerce_seller/features/notifications/domain/notification_model.dart';

/// The seller's notification inbox.
class ApiNotificationRepository implements NotificationRepository {
  const ApiNotificationRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<AppNotificationModel>> getNotifications() async {
    final response = await _dio.get<dynamic>(
      '/food/notifications/inbox',
      queryParameters: {'limit': 50},
    );

    final data = response.data;
    final list = data is List ? data : _asList(_asMap(data)['items']);

    return list
        .map(
          (n) => AppNotificationModel(
            id: (n['_id'] ?? n['id'] ?? '').toString(),
            title: (n['title'] ?? '').toString(),
            body: (n['body'] ?? n['message'] ?? '').toString(),
            timestamp: _asDate(n['createdAt'] ?? n['at']) ?? DateTime.now(),
            // The backend records when it was read rather than a flag, so any
            // timestamp at all means read.
            isRead: n['isRead'] == true || n['readAt'] != null,
            type: _toType((n['type'] ?? n['category'] ?? '').toString()),
            targetRoute: _nullIfEmpty(n['link'] ?? n['route']),
          ),
        )
        .toList();
  }

  @override
  Future<void> markAsRead(String notificationId) =>
      _dio.patch<dynamic>('/food/notifications/$notificationId/read');

  @override
  Future<void> markAllAsRead() =>
      _dio.patch<dynamic>('/food/notifications/inbox/read-all');

  /// Anything unrecognised is `system`, which is the bucket that renders with
  /// no special affordance -- the safe place for a type this app has not met.
  static NotificationType _toType(String wire) {
    final w = wire.toLowerCase();
    if (w.contains('order')) return NotificationType.order;
    if (w.contains('payout') || w.contains('payment') || w.contains('wallet')) {
      return NotificationType.payout;
    }
    if (w.contains('offer') || w.contains('coupon') || w.contains('promo')) {
      return NotificationType.offer;
    }
    return NotificationType.system;
  }

  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<Map<String, dynamic>> _asList(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  static DateTime? _asDate(dynamic v) =>
      DateTime.tryParse((v ?? '').toString())?.toLocal();

  static String? _nullIfEmpty(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}
