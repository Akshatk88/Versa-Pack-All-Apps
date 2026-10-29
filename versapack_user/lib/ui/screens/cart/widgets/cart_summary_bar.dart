import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../di/app_providers.dart';
import '../../../../navigation/route_paths.dart';

/// Floating "N items · ₹X — View cart" bar shown above the bottom of browsing
/// screens whenever the cart is non-empty.
class CartSummaryBar extends ConsumerWidget {
  const CartSummaryBar({super.key, this.label = 'View cart'});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider.select((s) => s.cart));

    return AnimatedSlide(
      offset: cart.isEmpty ? const Offset(0, 1.4) : Offset.zero,
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: cart.isEmpty ? 0 : 1,
        duration: AppDurations.fast,
        child: cart.isEmpty
            ? const SizedBox(height: 0, width: double.infinity)
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: GestureDetector(
                    onTap: () => context.go(RoutePaths.cart),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: AppRadii.rMd,
                        boxShadow: context.semantic.floatingShadow,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${cart.itemCount} '
                                  '${cart.itemCount == 1 ? 'item' : 'items'}',
                                  style: context.text.labelMedium!
                                      .copyWith(
                                        color: context.colors.onPrimary
                                            .withValues(alpha: 0.7),
                                      ),
                                ),
                                Text(
                                  (cart.pricing.total > 0
                                          ? cart.pricing.total
                                          : cart.provisionalSubtotal)
                                      .asCurrency,
                                  style: context.text.price
                                      .copyWith(color: context.colors.onPrimary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            label,
                            style: context.text.labelLarge!
                                .copyWith(color: context.colors.onPrimary),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: context.colors.onPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
