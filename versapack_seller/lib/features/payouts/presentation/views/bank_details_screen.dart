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

class BankDetailsScreen extends ConsumerStatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  ConsumerState<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends ConsumerState<BankDetailsScreen> {
  late TextEditingController _holderCtrl;
  late TextEditingController _accountCtrl;
  late TextEditingController _ifscCtrl;
  late TextEditingController _bankCtrl;
  late TextEditingController _upiCtrl;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _holderCtrl = TextEditingController();
    _accountCtrl = TextEditingController();
    _ifscCtrl = TextEditingController();
    _bankCtrl = TextEditingController();
    _upiCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _accountCtrl.dispose();
    _ifscCtrl.dispose();
    _bankCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  void _populateControllers(BankDetailsModel bank) {
    if (!_isEditing) {
      _holderCtrl.text = bank.accountHolderName;
      _accountCtrl.text = bank.accountNumber;
      _ifscCtrl.text = bank.ifscCode;
      _bankCtrl.text = bank.bankName;
      _upiCtrl.text = bank.upiId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankAsync = ref.watch(bankDetailsControllerProvider);

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
          'Bank & Payout Account',
          style: AppTextStyles.h3.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              if (_isEditing) {
                // Read the loaded record here rather than closing over it: the
                // AppBar builds outside the AsyncStateView, so there may be no
                // record yet.
                final current = ref.read(bankDetailsControllerProvider).value;
                if (current == null) {
                  AppToast.showError(context, 'Bank details are still loading');
                  return;
                }
                final updated = current.copyWith(
                  accountHolderName: _holderCtrl.text,
                  accountNumber: _accountCtrl.text,
                  ifscCode: _ifscCtrl.text,
                  bankName: _bankCtrl.text,
                  upiId: _upiCtrl.text,
                );
                ref
                    .read(bankDetailsControllerProvider.notifier)
                    .updateBankDetails(updated);
                AppToast.show(context, 'Bank details updated successfully!');
              }
              setState(() => _isEditing = !_isEditing);
            },
            child: Text(
              _isEditing ? 'Save' : 'Edit',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        // Showing placeholder bank details on failure would be actively
        // dangerous — the seller could believe a wrong account is on file.
        child: AsyncStateView<BankDetailsModel>(
          value: bankAsync,
          onRetry: () => ref.invalidate(bankDetailsControllerProvider),
          builder: (bank) {
            _populateControllers(bank);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Settlement Status',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.successBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 12,
                                    color: AppColors.successText,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      color: AppColors.successText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          'Account Holder Name',
                          _holderCtrl,
                          _isEditing,
                        ),
                        const SizedBox(height: 16),
                        _buildField('Account Number', _accountCtrl, _isEditing),
                        const SizedBox(height: 16),
                        _buildField('IFSC Code', _ifscCtrl, _isEditing),
                        const SizedBox(height: 16),
                        _buildField('Bank Name', _bankCtrl, _isEditing),
                        const SizedBox(height: 16),
                        _buildField(
                          'UPI ID (Instant Settlement)',
                          _upiCtrl,
                          _isEditing,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    bool enabled,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          enabled: enabled,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: !enabled,
            fillColor: enabled ? Colors.white : const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: enabled
                  ? const BorderSide(color: Color(0xFFD1D5DB))
                  : BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
