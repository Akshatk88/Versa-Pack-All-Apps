import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/providers/repository_providers.dart';
import 'package:quick_commerce_seller/features/notifications/domain/notification_model.dart';

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<AppNotificationModel>>(
      NotificationsController.new,
    );

class NotificationsController
    extends AsyncNotifier<List<AppNotificationModel>> {
  late final NotificationRepository _repository;

  @override
  Future<List<AppNotificationModel>> build() async {
    _repository = ref.watch(notificationRepositoryProvider);
    return _repository.getNotifications();
  }

  Future<void> markAsRead(String notificationId) async {
    await _repository.markAsRead(notificationId);
    state = await AsyncValue.guard(() => _repository.getNotifications());
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    state = await AsyncValue.guard(() => _repository.getNotifications());
  }
}

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsControllerProvider).value ?? [];
  return notifs.where((n) => !n.isRead).length;
});
