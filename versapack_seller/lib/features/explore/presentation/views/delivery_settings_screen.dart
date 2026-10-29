import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/core/widgets/async_state_view.dart';
import 'package:quick_commerce_seller/features/explore/domain/store_settings_model.dart';
import 'package:quick_commerce_seller/features/explore/presentation/controllers/explore_controller.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';

class DeliverySettingsScreen extends ConsumerStatefulWidget {
  const DeliverySettingsScreen({super.key});

  @override
  ConsumerState<DeliverySettingsScreen> createState() =>
      _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState
    extends ConsumerState<DeliverySettingsScreen> {
  late TextEditingController _radiusCtrl;
  late TextEditingController _minOrderCtrl;
  late TextEditingController _packagingCtrl;
  late TextEditingController _freeDeliveryAboveCtrl;
  bool _isSelfDelivery = false;

  @override
  void initState() {
    super.initState();
    _radiusCtrl = TextEditingController();
    _minOrderCtrl = TextEditingController();
    _packagingCtrl = TextEditingController();
    _freeDeliveryAboveCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _radiusCtrl.dispose();
    _minOrderCtrl.dispose();
    _packagingCtrl.dispose();
    _freeDeliveryAboveCtrl.dispose();
    super.dispose();
  }

  void _populateControllers(DeliverySettingsModel settings) {
    if (_radiusCtrl.text.isEmpty) {
      _radiusCtrl.text = settings.deliveryRadiusKm.toStringAsFixed(1);
      _minOrderCtrl.text = settings.minOrderValue.toStringAsFixed(0);
      _packagingCtrl.text = settings.packagingCharge.toStringAsFixed(0);
      _freeDeliveryAboveCtrl.text = settings.freeDeliveryThreshold
          .toStringAsFixed(0);
      _isSelfDelivery = settings.isSelfDelivery;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(deliverySettingsProvider);

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
          'Delivery & Radius Settings',
          style: AppTextStyles.h3.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        // body is a Column, not a scrollable
        child: AsyncStateView<DeliverySettingsModel>(
          value: settingsAsync,
          onRetry: () => ref.invalidate(deliverySettingsProvider),
          enableRefresh: false,
          builder: (settings) {
            _populateControllers(settings);
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Radius (km)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _radiusCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            suffixText: 'km',
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
                          'Minimum Order Amount (₹)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _minOrderCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            prefixText: '₹ ',
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
                          'Packaging & Handling Charge (₹)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _packagingCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            prefixText: '₹ ',
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
                          'Free Delivery Threshold (₹)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _freeDeliveryAboveCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            prefixText: '₹ ',
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
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: SwitchListTile(
                            value: _isSelfDelivery,
                            title: const Text(
                              'Self Delivery Mode',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'Use store riders instead of partner platform fleet.',
                            ),
                            onChanged: (val) =>
                                setState(() => _isSelfDelivery = val),
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
                    // Disabled, because there is nothing behind it. These are
                    // platform-wide figures owned by an admin and there is no
                    // seller-facing endpoint that writes them — see
                    // `updateDeliverySettings`, which is deliberately inert.
                    //
                    // It previously substituted 5 / 99 / 15 / 499 for any field
                    // it could not parse, called that no-op, and reported
                    // "Delivery settings saved!" — so a seller could believe
                    // they had changed their radius and fees when nothing had
                    // happened at all.
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF181C2E),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Set by the platform',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
