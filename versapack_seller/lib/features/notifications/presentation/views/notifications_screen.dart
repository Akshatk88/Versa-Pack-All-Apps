import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/core/widgets/async_state_view.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/notifications/domain/notification_model.dart';
import 'package:quick_commerce_seller/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsControllerProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    // Labels only; the body below renders the real async state.
    final loaded = notificationsAsync.value ?? const <AppNotificationModel>[];

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.textPrimary,
            size: 18,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notifications',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h3.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // Icon, not a text button: "Mark all read" plus the back button and
          // centred title overflowed the AppBar at large system font sizes.
          if (unreadCount > 0)
            IconButton(
              tooltip: 'Mark all read',
              icon: Icon(Icons.done_all_rounded, color: context.textPrimary),
              onPressed: () {
                ref
                    .read(notificationsControllerProvider.notifier)
                    .markAllAsRead();
                AppToast.show(context, 'All notifications marked as read.');
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF181C2E),
          unselectedLabelColor: AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
          tabs: [
            Tab(text: 'All (${loaded.length})'),
            Tab(
              text:
                  'Orders '
                  '(${loaded.where((n) => n.type == NotificationType.order).length})',
            ),
            Tab(
              text:
                  'Payouts '
                  '(${loaded.where((n) => n.type == NotificationType.payout).length})',
            ),
            Tab(
              text:
                  'System '
                  '(${loaded.where((n) => n.type == NotificationType.system).length})',
            ),
          ],
        ),
      ),
      body: SafeArea(
        // TabBarView is not itself a scrollable
        child: AsyncStateView<List<AppNotificationModel>>(
          value: notificationsAsync,
          onRetry: () => ref.invalidate(notificationsControllerProvider),
          enableRefresh: false,
          builder: (notifs) => TabBarView(
            controller: _tabController,
            children: [
              _buildList(notifs),
              _buildList(
                notifs.where((n) => n.type == NotificationType.order).toList(),
              ),
              _buildList(
                notifs.where((n) => n.type == NotificationType.payout).toList(),
              ),
              _buildList(
                notifs.where((n) => n.type == NotificationType.system).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<AppNotificationModel> list) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No notifications',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final notif = list[index];
        return InkWell(
          onTap: () {
            ref
                .read(notificationsControllerProvider.notifier)
                .markAsRead(notif.id);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: notif.isRead ? Colors.white : const Color(0xFFFEFCE8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: notif.isRead
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFFFDE047),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFF181C2E),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: notif.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                          color: const Color(0xFF181C2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.body,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
