import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/core/widgets/async_state_view.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/payouts/domain/payout_model.dart';
import 'package:quick_commerce_seller/features/payouts/presentation/controllers/payouts_controller.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';

class PayoutsScreen extends ConsumerWidget {
  const PayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(payoutSummaryProvider);
    final transactionsAsync = ref.watch(payoutTransactionsProvider);

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        title: Text(
          'Payouts & Revenue',
          style: AppTextStyles.h3.copyWith(
            color: const Color(0xFF181C2E),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_balance_outlined,
              color: Color(0xFF181C2E),
            ),
            onPressed: () => context.push('/bank-details'),
            tooltip: 'Bank Details',
          ),
        ],
      ),
      body: SafeArea(
        // Financial figures must never be faked while loading or on error —
        // this screen previously fell back to hardcoded balances.
        child: AsyncStateView<PayoutSummaryModel>(
          value: summaryAsync,
          onRetry: () {
            ref.invalidate(payoutSummaryProvider);
            ref.invalidate(payoutTransactionsProvider);
          },
          builder: (summary) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Available Balance Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Balance',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: const Color(0xFF181C2E),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${summary.availableBalance.toStringAsFixed(0)}',
                              style: AppTextStyles.h1.copyWith(
                                color: const Color(0xFF181C2E),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: summary.availableBalance > 0
                            ? () => _showInstantWithdrawDialog(
                                context,
                                ref,
                                summary.availableBalance,
                              )
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF181C2E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Withdraw',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Overview Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryBox(
                        context,
                        'Total Earnings',
                        '₹${summary.totalEarnings.toStringAsFixed(0)}',
                        Icons.trending_up_rounded,
                        const Color(0xFF22C55E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryBox(
                        context,
                        'Pending Payout',
                        '₹${summary.pendingPayout.toStringAsFixed(0)}',
                        Icons.hourglass_empty_rounded,
                        const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bank Details Action Card
                InkWell(
                  onTap: () => context.push('/bank-details'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
                            color: Color(0xFF181C2E),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Linked Settlement Account',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF181C2E),
                                ),
                              ),
                              Text(
                                'HDFC Bank •••• 2345 (Verified)',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondaryLight,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Transaction History
                Text(
                  'Recent Settlements',
                  style: AppTextStyles.h4.copyWith(
                    color: const Color(0xFF181C2E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                AsyncStateView<List<PayoutTransactionModel>>(
                  value: transactionsAsync,
                  onRetry: () => ref.invalidate(payoutTransactionsProvider),
                  enableRefresh:
                      false, // already inside this screen's scroll view
                  isEmpty: (list) => list.isEmpty,
                  emptyIcon: Icons.receipt_long_outlined,
                  emptyTitle: 'No settlement history yet',
                  builder: (transactions) => Column(
                    children: transactions
                        .map((tx) => _buildTransactionCard(context, tx))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBox(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    PayoutTransactionModel tx,
  ) {
    final isCompleted = tx.status == PayoutStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.call_made_rounded : Icons.sync_rounded,
                    color: isCompleted
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.referenceNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF181C2E),
                        ),
                      ),
                      Text(
                        // The method is dropped rather than shown blank when
                        // the backend did not report one, leaving just the date
                        // instead of a stray leading bullet.
                        [
                          if (tx.payoutMethod.trim().isNotEmpty) tx.payoutMethod,
                          '${tx.date.day}/${tx.date.month}/${tx.date.year}',
                        ].join(' • '),
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
          ),
          const SizedBox(width: 8),
          Text(
            '₹${tx.amount.toStringAsFixed(0)}',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF181C2E),
            ),
          ),
        ],
      ),
    );
  }

  void _showInstantWithdrawDialog(
    BuildContext context,
    WidgetRef ref,
    double availableBalance,
  ) {
    final amountCtrl = TextEditingController(
      text: availableBalance.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Instant Payout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Balance: ₹${availableBalance.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Withdrawal Amount (₹)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(amountCtrl.text) ?? 0.0;
              if (val > 0 && val <= availableBalance) {
                final navigator = Navigator.of(ctx);
                final success = await ref
                    .read(payoutSummaryProvider.notifier)
                    .requestPayout(val);
                navigator.pop();
                if (context.mounted) {
                  if (success) {
                    AppToast.show(
                      context,
                      'Withdrawal request submitted successfully!',
                    );
                  } else {
                    AppToast.show(
                      context,
                      'Failed to submit withdrawal request. Please try again.',
                    );
                  }
                }
              }
            },
            child: const Text('Confirm Payout'),
          ),
        ],
      ),
    );
  }
}
