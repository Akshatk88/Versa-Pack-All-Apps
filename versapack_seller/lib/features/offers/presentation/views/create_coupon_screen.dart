import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/offers/domain/offer_model.dart';
import 'package:quick_commerce_seller/features/offers/presentation/controllers/offers_controller.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';

class CreateCouponScreen extends ConsumerStatefulWidget {
  const CreateCouponScreen({super.key});

  @override
  ConsumerState<CreateCouponScreen> createState() => _CreateCouponScreenState();
}

class _CreateCouponScreenState extends ConsumerState<CreateCouponScreen> {
  // Empty, not pre-filled. These used to open on a ready-made "SUPER50 / Flat
  // 50 OFF / 50 / 299" coupon, which a seller could publish to real customers
  // with one tap without ever having chosen any of it.
  final TextEditingController _code = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _val = TextEditingController();
  final TextEditingController _minOrder = TextEditingController();
  DiscountType _discountType = DiscountType.fixedAmount;
  bool _saving = false;

  /// Validates, then reports what actually happened.
  ///
  /// Every value sent is one the seller typed: the old version substituted 50
  /// for an unparseable discount and 199 for an unparseable minimum, so a
  /// mistyped field silently published a coupon nobody had agreed to.
  Future<void> _create() async {
    final code = _code.text.trim().toUpperCase();
    final discountValue = double.tryParse(_val.text.trim());
    final minOrder = double.tryParse(_minOrder.text.trim());

    final String? problem;
    if (code.isEmpty) {
      problem = 'Enter a coupon code.';
    } else if (discountValue == null || discountValue <= 0) {
      problem = 'Enter a discount value greater than zero.';
    } else if (_discountType == DiscountType.percentage && discountValue > 100) {
      problem = 'A percentage discount cannot be more than 100.';
    } else if (minOrder == null || minOrder < 0) {
      problem = 'Enter a minimum order amount.';
    } else {
      problem = null;
    }

    if (problem != null) {
      AppToast.showError(context, problem);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(offersControllerProvider.notifier)
          .createCoupon(
            CouponModel(
              // The backend assigns the id; the client used to mint a
              // `c_<timestamp>` that matched nothing in the database.
              id: '',
              code: code,
              title: _title.text.trim().isEmpty ? code : _title.text.trim(),
              description:
                  'Valid on orders above ₹${minOrder!.toStringAsFixed(0)}',
              discountType: _discountType,
              discountValue: discountValue!,
              minOrderAmount: minOrder,
              validFrom: DateTime.now(),
              // ponytail: fixed 30-day validity — there is no field for it on
              // this form. Add a date picker and pass it through when sellers
              // need to choose the window.
              validTill: DateTime.now().add(const Duration(days: 30)),
              isActive: true,
            ),
          );
      if (!mounted) return;
      AppToast.show(context, 'Coupon created.');
      context.pop();
    } catch (e, stack) {
      debugPrint('CreateCouponScreen Exception: $e');
      debugPrint('StackTrace: $stack');
      if (!mounted) return;
      AppToast.showError(context, 'Could not create the coupon. Please retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _val.dispose();
    _minOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          'Create Coupon Code',
          style: AppTextStyles.h3.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coupon Code',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        hintText: 'e.g. SAVE50',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Coupon Title',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _title,
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        hintText: 'e.g. 50% OFF on Dairy',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Discount Type',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Flat Amount (₹)'),
                            selected: _discountType == DiscountType.fixedAmount,
                            onSelected: (_) {
                              setState(
                                () => _discountType = DiscountType.fixedAmount,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Percentage (%)'),
                            selected: _discountType == DiscountType.percentage,
                            onSelected: (_) {
                              setState(
                                () => _discountType = DiscountType.percentage,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Discount Value',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _val,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Minimum Order Value (₹)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _minOrder,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF181C2E),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _saving ? 'Publishing…' : 'Save & Publish Coupon',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
