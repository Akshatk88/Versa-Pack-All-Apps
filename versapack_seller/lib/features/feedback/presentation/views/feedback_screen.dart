import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/core/widgets/async_state_view.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/feedback/domain/feedback_model.dart';
import 'package:quick_commerce_seller/features/feedback/presentation/controllers/feedback_controller.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';

class FeedbackScreen extends ConsumerWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(feedbackControllerProvider);

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
          'Customer Ratings & Reviews',
          style: AppTextStyles.h3.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: AsyncStateView<List<FeedbackModel>>(
        value: feedbackAsync,
        onRetry: () => ref.invalidate(feedbackControllerProvider),
        builder: (reviews) {
          final double avgRating = reviews.isEmpty
              ? 0.0
              : (reviews.fold<double>(0, (sum, r) => sum + r.rating) /
                    reviews.length);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Overall Rating Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average Store Rating',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          reviews.isEmpty ? '0.0' : avgRating.toStringAsFixed(1),
                          style: AppTextStyles.h1.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 36,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    Icons.star_rounded,
                                    color: i < avgRating.round()
                                        ? const Color(0xFFFFC107)
                                        : Colors.grey.shade300,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Based on ${reviews.length} ${reviews.length == 1 ? 'rating' : 'ratings'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            Text(
              'Recent Customer Reviews',
              style: AppTextStyles.h4.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (reviews.isEmpty)
              Center(
                child: Text(
                  'No reviews available',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              )
            else
              ...reviews.map(
                (review) => _buildReviewCard(context, ref, review),
              ),
          ],
        );
      },
    ),
  );
}

  Widget _buildReviewCard(
    BuildContext context,
    WidgetRef ref,
    FeedbackModel review,
  ) {
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
                  review.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star_rounded,
                    color: i < review.rating
                        ? const Color(0xFFFFC107)
                        : Colors.grey.shade300,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Order ${review.orderId}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            review.reviewText,
            style: AppTextStyles.bodySmall.copyWith(color: context.textPrimary),
          ),
          if (review.sellerReply != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Store Response: ${review.sellerReply}',
                style: AppTextStyles.caption.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showReplyDialog(context, ref, review.id),
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: const Text('Reply to Customer'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showReplyDialog(
    BuildContext context,
    WidgetRef ref,
    String feedbackId,
  ) {
    final replyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reply to Customer Review'),
        content: TextField(
          controller: replyCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Type your response to the customer...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (replyCtrl.text.isNotEmpty) {
                ref
                    .read(feedbackControllerProvider.notifier)
                    .reply(feedbackId, replyCtrl.text);
                AppToast.show(context, 'Reply sent to customer!');
                Navigator.pop(ctx);
              }
            },
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );
  }
}
