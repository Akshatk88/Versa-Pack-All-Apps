import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/core/widgets/async_state_view.dart';
import 'package:quick_commerce_seller/features/explore/domain/store_settings_model.dart';
import 'package:quick_commerce_seller/features/explore/presentation/controllers/explore_controller.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';

class RestaurantStatusScreen extends ConsumerWidget {
  const RestaurantStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          'Store Availability',
          style: AppTextStyles.h3.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        // This screen exists to show and set availability, so it must not
        // render a guessed state: no value, no radios.
        child: AsyncStateView<StoreProfileModel>(
          value: profileAsync,
          onRetry: () => ref.invalidate(storeProfileProvider),
          enableRefresh: false, // body is a Column, not a scrollable
          builder: (profile) {
            final isOnline = profile.isOnline;
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Status Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isOnline
                                ? AppColors.successBg
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isOnline
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFFFCA5A5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Status',
                                style: AppTextStyles.caption.copyWith(
                                  color: isOnline
                                      ? AppColors.successText
                                      : const Color(0xFFDC2626),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isOnline
                                    ? 'Online (Accepting Orders)'
                                    : 'Offline (Paused)',
                                style: AppTextStyles.h2.copyWith(
                                  color: isOnline
                                      ? AppColors.successText
                                      : const Color(0xFFDC2626),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isOnline
                                    ? 'Your store is currently online and accepting customer orders on the quick commerce app.'
                                    : 'Your store is paused and hidden from search. Customers cannot place orders right now.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isOnline
                                      ? AppColors.successText
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        Text(
                          'Store Availability Toggle',
                          style: AppTextStyles.h4.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: Icon(
                                  isOnline
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: const Color(0xFF22C55E),
                                ),
                                title: const Text(
                                  'Open / Online',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: const Text(
                                  'Store is active and taking new orders.',
                                ),
                                onTap: () {
                                  ref
                                      .read(storeProfileProvider.notifier)
                                      .setOnlineStatus(true);
                                  AppToast.show(
                                    context,
                                    'Store is now Online!',
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: Icon(
                                  !isOnline
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: const Color(0xFFEF4444),
                                ),
                                title: const Text(
                                  'Closed / Offline',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: const Text(
                                  'Temporarily pause orders for maintenance or rush hours.',
                                ),
                                onTap: () {
                                  ref
                                      .read(storeProfileProvider.notifier)
                                      .setOnlineStatus(
                                        false,
                                        reason: 'Manual Pause',
                                      );
                                  AppToast.show(
                                    context,
                                    'Store is now Offline!',
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
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
