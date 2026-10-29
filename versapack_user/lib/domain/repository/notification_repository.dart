import '../model/notification_item.dart';
import '../model/paged_result.dart';

abstract interface class NotificationRepository {
  Future<({PagedResult<NotificationItem> page, int unreadCount})> inbox({
    int page,
    int pageSize,
  });

  Future<void> markRead(String id);

  Future<void> dismiss(String id);

  /// Bulk-reads all unread notifications in a single API call.
  Future<int> markAllRead();

  /// Clears (dismisses) every notification in the inbox.
  Future<int> dismissAll();
}
