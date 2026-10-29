import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../domain/model/notification_item.dart';
import '../../domain/model/paged_result.dart';
import '../../domain/repository/notification_repository.dart';
import '../dto/json_reader.dart';
import '../dto/notification_dto.dart';
import '../mapper/notification_mapper.dart';
import 'api_paths.dart';

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._client);

  final ApiClient _client;

  @override
  Future<({PagedResult<NotificationItem> page, int unreadCount})> inbox({
    int page = 1,
    int pageSize = 20,
  }) async {
    debugPrint('🔔 [inbox] calling GET ${ApiPaths.notificationInbox} page=$page limit=$pageSize');

    final json = await _client.get(
      ApiPaths.notificationInbox,
      query: {'page': page, 'limit': pageSize},
      requiresAuth: true,
    );

    debugPrint('🔔 [inbox] raw response type=${json.runtimeType}');
    debugPrint('🔔 [inbox] raw response body=$json');

    if (json is! Map<String, dynamic>) {
      debugPrint('🔔 [inbox] response is NOT a Map — returning empty');
      return (page: PagedResult.empty<NotificationItem>(), unreadCount: 0);
    }

    debugPrint('🔔 [inbox] top-level keys=${json.keys.toList()}');

    final rawItems = json.objects('items');
    debugPrint('🔔 [inbox] raw items count (before mapping)=${rawItems.length}');

    final dtos = rawItems.map(NotificationDto.fromJson).toList();
    debugPrint('🔔 [inbox] dtos parsed count=${dtos.length}');

    final meta = PageMeta.from(json, fallbackCount: dtos.length);
    debugPrint('🔔 [inbox] meta: total=${meta.total} page=${meta.page} pageSize=${meta.pageSize}');

    final unreadCount = json.integer('unreadCount');
    debugPrint('🔔 [inbox] unreadCount=$unreadCount');

    final domainItems = NotificationMapper.toDomainList(dtos);
    debugPrint('🔔 [inbox] domain items count=${domainItems.length}');

    return (
    page: PagedResult(
      items: domainItems,
      total: meta.total,
      page: meta.page,
      pageSize: meta.pageSize,
    ),
    unreadCount: unreadCount,
    );
  }

  @override
  Future<void> markRead(String id) =>
      _client.patch(ApiPaths.notificationRead(id), requiresAuth: true);

  @override
  Future<void> dismiss(String id) =>
      _client.delete(ApiPaths.notificationDismiss(id), requiresAuth: true);

  /// PATCH /v1/food/notifications/inbox/read-all
  /// Marks every unread notification as read in a single request.
  /// Returns [modifiedCount] from the server response.
  @override
  Future<int> markAllRead() async {
    final json = await _client.patch(
      ApiPaths.notificationReadAll,
      requiresAuth: true,
    );
    if (json is Map<String, dynamic>) {
      return (json['modifiedCount'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  /// DELETE /v1/food/notifications/inbox/all
  /// Dismisses (soft-deletes) every notification so the inbox is cleared.
  /// Returns [modifiedCount] from the server response.
  @override
  Future<int> dismissAll() async {
    final json = await _client.delete(
      ApiPaths.notificationDismissAll,
      requiresAuth: true,
    );
    if (json is Map<String, dynamic>) {
      return (json['modifiedCount'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
}