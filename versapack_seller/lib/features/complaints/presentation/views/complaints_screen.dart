import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/core/widgets/async_state_view.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/complaints/domain/complaint_model.dart';
import 'package:quick_commerce_seller/features/complaints/presentation/controllers/complaints_controller.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';

class ComplaintsScreen extends ConsumerStatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  ConsumerState<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends ConsumerState<ComplaintsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final complaintsAsync = ref.watch(complaintsControllerProvider);
    // Tab labels need a count before the body resolves; an empty count on a
    // label is harmless, whereas an empty *list* passed off as loaded is not —
    // that is why only the labels read `.value` and the body goes through
    // AsyncStateView.
    final loaded = complaintsAsync.value ?? const <ComplaintModel>[];
    final openComplaints = loaded
        .where((c) => c.status == ComplaintStatus.open)
        .toList();
    final resolvedComplaints = loaded
        .where((c) => c.status == ComplaintStatus.resolved)
        .toList();

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
          'Complaints & Issues',
          style: AppTextStyles.h3.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
            Tab(text: 'Open (${openComplaints.length})'),
            Tab(text: 'Resolved (${resolvedComplaints.length})'),
          ],
        ),
      ),
      body: SafeArea(
        child: AsyncStateView<List<ComplaintModel>>(
          value: complaintsAsync,
          onRetry: () => ref.invalidate(complaintsControllerProvider),
          enableRefresh: false, // TabBarView is not itself a scrollable
          builder: (complaints) => TabBarView(
            controller: _tabController,
            children: [
              _buildComplaintsList(complaints),
              _buildComplaintsList(
                complaints
                    .where((c) => c.status == ComplaintStatus.open)
                    .toList(),
              ),
              _buildComplaintsList(
                complaints
                    .where((c) => c.status == ComplaintStatus.resolved)
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComplaintsList(List<ComplaintModel> list) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No complaints found',
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
        final item = list[index];
        final isOpen = item.status == ComplaintStatus.open;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.orderId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF181C2E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOpen ? 'OPEN' : 'RESOLVED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOpen
                            ? const Color(0xFFD97706)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${item.customerName} • ${item.issueType}',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF181C2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.description,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              if (item.sellerResponse != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.pageBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Response: ${item.sellerResponse}',
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF181C2E),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              if (isOpen) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ref
                              .read(complaintsControllerProvider.notifier)
                              .reject(item.id, 'Issue non-verifiable');
                          AppToast.show(
                            context,
                            'Complaint marked as non-verifiable.',
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ref
                              .read(complaintsControllerProvider.notifier)
                              .resolve(item.id, 'Refund processed');
                          AppToast.show(
                            context,
                            'Complaint resolved & customer notified!',
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF181C2E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Resolve'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
