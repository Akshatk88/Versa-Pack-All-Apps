import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/core/widgets/async_state_view.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/explore/domain/store_settings_model.dart';
import 'package:quick_commerce_seller/features/explore/presentation/controllers/explore_controller.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';

class OutletInfoScreen extends ConsumerStatefulWidget {
  const OutletInfoScreen({super.key});

  @override
  ConsumerState<OutletInfoScreen> createState() => _OutletInfoScreenState();
}

class _OutletInfoScreenState extends ConsumerState<OutletInfoScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _fssaiCtrl;
  late TextEditingController _gstCtrl;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _fssaiCtrl = TextEditingController();
    _gstCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _fssaiCtrl.dispose();
    _gstCtrl.dispose();
    super.dispose();
  }

  void _populateControllers(StoreProfileModel profile) {
    if (!_isEditing) {
      _nameCtrl.text = profile.name;
      _phoneCtrl.text = profile.phone;
      _emailCtrl.text = profile.email;
      _addressCtrl.text = profile.address;
      _fssaiCtrl.text = profile.fssaiLicense;
      _gstCtrl.text = profile.gstNumber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(storeProfileProvider);

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
          'Outlet Information',
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
                final current = ref.read(storeProfileProvider).value;
                if (current == null) {
                  AppToast.showError(context, 'Store profile is still loading');
                  return;
                }
                final updated = current.copyWith(
                  name: _nameCtrl.text,
                  phone: _phoneCtrl.text,
                  email: _emailCtrl.text,
                  address: _addressCtrl.text,
                  fssaiLicense: _fssaiCtrl.text,
                  gstNumber: _gstCtrl.text,
                );
                ref.read(storeProfileProvider.notifier).updateProfile(updated);
                AppToast.show(context, 'Store profile updated!');
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
        child: AsyncStateView<StoreProfileModel>(
          value: profileAsync,
          onRetry: () => ref.invalidate(storeProfileProvider),
          builder: (profile) {
            _populateControllers(profile);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Banner
                  Container(
                    // minHeight, not a fixed height: the store name grows with the
                    // system font-size setting and used to overflow the banner.
                    constraints: const BoxConstraints(minHeight: 140),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 48,
                            color: context.textPrimary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            profile.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.h3.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
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
                      children: [
                        _buildField('Store Name', _nameCtrl, _isEditing),
                        const SizedBox(height: 14),
                        _buildField('Phone Number', _phoneCtrl, _isEditing),
                        const SizedBox(height: 14),
                        _buildField('Support Email', _emailCtrl, _isEditing),
                        const SizedBox(height: 14),
                        _buildField(
                          'Store Address',
                          _addressCtrl,
                          _isEditing,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          'FSSAI License No.',
                          _fssaiCtrl,
                          _isEditing,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          'GST Registration No.',
                          _gstCtrl,
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
    bool enabled, {
    int maxLines = 1,
  }) {
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
          maxLines: maxLines,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF181C2E),
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
