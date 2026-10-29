import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../di/app_providers.dart';
import '../../../domain/model/product.dart';
import '../../../domain/usecase/add_to_cart_usecase.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/buttons/secondary_button.dart';
import '../../common/widgets/cards/product_card.dart';
import '../../common/widgets/feedback/app_toast.dart';
import '../../common/widgets/loaders/product_card_skeleton.dart';
import '../../common/widgets/misc/staggered_entrance.dart';
import '../../common/widgets/states/empty_state_widget.dart';
import '../../common/widgets/states/error_state_widget.dart';
import '../cart/widgets/cart_summary_bar.dart';
import 'wishlist_provider.dart';
import '../../common/widgets/misc/sound_refresh_indicator.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider).isSignedIn;
    final products = ref.watch(wishlistProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      bottomNavigationBar: const CartSummaryBar(),
      body: SafeArea(
        child: !signedIn
            ? EmptyStateWidget(
                icon: Icons.favorite_border_rounded,
                title: 'Sign in to see your wishlist',
                message: 'Saved items follow you across every device.',
                actionLabel: 'Sign in',
                onAction: () => context.push(RoutePaths.login),
              )
            : products.when(
                loading: () =>
                    ProductGridSkeleton(columns: context.productGridColumns),
                error: (error, _) => ErrorStateWidget(
                  failure: ErrorMapper.toFailure(error),
                  onRetry: () => ref.invalidate(wishlistProductsProvider),
                ),
                data: (items) => items.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.favorite_border_rounded,
                        title: 'Nothing saved yet',
                        message:
                            'Tap the heart on any product to keep it here for later.',
                        actionLabel: 'Start shopping',
                        onAction: () => context.go(RoutePaths.home),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              0,
                            ),
                            child: SecondaryButton(
                              label: 'Add all in-stock items to cart',
                              icon: Icons.add_shopping_cart_rounded,
                              expand: true,
                              onPressed: () => _addAll(context, ref, items),
                            ),
                          ),
                          Expanded(
                            child: SoundRefreshIndicator(
                              onRefresh: () async =>
                                  ref.invalidate(wishlistProductsProvider),
                              child: GridView.builder(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                itemCount: items.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: context.productGridColumns,
                                  mainAxisSpacing: AppSpacing.md,
                                  crossAxisSpacing: AppSpacing.md,
                                  childAspectRatio: 0.52,
                                ),
                                itemBuilder: (context, index) {
                                  final product = items[index];
                                  return StaggeredEntrance(
                                    index: index,
                                    child: ProductCard(
                                      product: product,
                                      width: double.infinity,
                                      heroTag: 'wishlist',
                                      onTap: () => context.push(
                                        RoutePaths.productDetailsOf(product.id),
                                        extra: product,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
      ),
    );
  }

  Future<void> _addAll(
    BuildContext context,
    WidgetRef ref,
    List<Product> items,
  ) async {
    final available = items.where((p) => p.isPurchasable).toList();
    if (available.isEmpty) {
      AppToast.error(context, 'None of your saved items are in stock');
      return;
    }

    var added = 0;
    var skipped = 0;

    for (final product in available) {
      // Variant products need an explicit pack choice, so they are left alone.
      if (product.hasVariants) {
        skipped++;
        continue;
      }

      final outcome = await ref.read(cartProvider.notifier).add(
            product,
            skipVariantPrompt: true,
          );
      if (!context.mounted) return;

      if (outcome is CartUpdated) {
        added++;
      } else {
        // A different seller or a stock cap — reported, never silently dropped.
        skipped++;
      }
    }

    AppToast.success(
      context,
      skipped == 0
          ? '$added items added to your cart'
          : '$added added · $skipped need a choice or are unavailable',
    );
  }
}
