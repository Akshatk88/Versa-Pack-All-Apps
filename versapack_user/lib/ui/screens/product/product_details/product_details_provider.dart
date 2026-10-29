import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../di/repository_providers.dart';
import '../../../../domain/model/addon.dart';
import '../../../../domain/model/product.dart';
import '../../../../domain/model/product_variant.dart';
import 'product_details_state.dart';

/// Identifies a product details screen. Carries the product when we already
/// have it (navigating from a card) so the page renders instantly and only the
/// extras stream in.
class ProductDetailsArgs {
  const ProductDetailsArgs({required this.productId, this.product});

  final String productId;
  final Product? product;

  @override
  bool operator ==(Object other) =>
      other is ProductDetailsArgs && other.productId == productId;

  @override
  int get hashCode => productId.hashCode;
}

class ProductDetailsController
    extends FamilyNotifier<ProductDetailsState, ProductDetailsArgs> {
  @override
  ProductDetailsState build(ProductDetailsArgs args) {
    Future.microtask(load);

    final product = args.product;
    if (product == null) return const ProductDetailsState();

    return ProductDetailsState(
      product: product,
      selectedVariant: product.variants.isEmpty ? null : product.variants.first,
      isLoading: false,
    );
  }

  Future<void> load() async {
    if (state.product == null) {
      state = state.copyWith(isLoading: true, clearFailure: true);
      try {
        final product = await ref
            .read(productRepositoryProvider)
            .getById(arg.productId, sellerId: arg.product?.sellerId);
        state = state.copyWith(
          product: product,
          selectedVariant:
              product.variants.isEmpty ? null : product.variants.first,
          isLoading: false,
        );
      } catch (e) {
        state = state.copyWith(
          isLoading: false,
          isLoadingExtras: false,
          failure: ErrorMapper.toFailure(e),
        );
        return;
      }
    }

    await _loadExtras();
  }

  Future<void> _loadExtras() async {
    final product = state.product;
    if (product == null) return;

    state = state.copyWith(isLoadingExtras: true);

    final products = ref.read(productRepositoryProvider);
    final reviews = ref.read(reviewRepositoryProvider);

    // Each extra degrades independently: a missing review list must not remove
    // the add-ons section.
    final addons = await products
        .addonsFor(sellerId: product.sellerId, productId: product.id)
        .catchError((_) => <AddonGroup>[]);

    final related = await products
        .list(categoryId: product.categoryId, pageSize: 12)
        .then((page) => page.items.where((p) => p.id != product.id).toList())
        .catchError((_) => <Product>[]);

    final ratings = await reviews.forProduct(product.id).catchError(
          (_) => (summary: state.ratingSummary, reviews: state.reviews),
        );

    final rateable = await reviews.rateableOrders(product.id).catchError(
          (_) => <({String orderId, String displayId, DateTime placedAt})>[],
        );

    state = state.copyWith(
      addonGroups: addons,
      related: related,
      reviews: ratings.reviews,
      ratingSummary: ratings.summary,
      rateableOrders: rateable,
      isLoadingExtras: false,
    );
  }

  void selectVariant(ProductVariant variant) =>
      state = state.copyWith(selectedVariant: variant);

  void setAddons(List<Addon> addons) =>
      state = state.copyWith(selectedAddons: addons);

  void toggleAddon(AddonGroup group, Addon addon) {
    final selected = [...state.selectedAddons];
    final existing = selected.indexWhere((a) => a.id == addon.id);

    if (existing >= 0) {
      selected.removeAt(existing);
    } else {
      if (group.isSingleSelect) {
        selected.removeWhere((a) => group.options.any((o) => o.id == a.id));
      } else if (group.hasLimit) {
        final chosen =
            selected.where((a) => group.options.any((o) => o.id == a.id)).length;
        if (chosen >= group.maxSelect) return;
      }
      selected.add(addon);
    }
    state = state.copyWith(selectedAddons: selected);
  }

  void setQuantity(int quantity) {
    final max = state.product?.maxOrderableQty ?? 1;
    state = state.copyWith(quantity: quantity.clamp(1, max));
  }

  Future<void> submitReview({
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    final product = state.product;
    if (product == null) return;

    final review = await ref.read(reviewRepositoryProvider).submit(
          orderId: orderId,
          productId: product.id,
          rating: rating,
          comment: comment,
        );

    // Append the server's response rather than optimistically guessing it.
    state = state.copyWith(
      reviews: [review, ...state.reviews],
      rateableOrders:
          state.rateableOrders.where((o) => o.orderId != orderId).toList(),
    );
    await _loadExtras();
  }
}

final productDetailsProvider = NotifierProvider.family<ProductDetailsController,
    ProductDetailsState, ProductDetailsArgs>(ProductDetailsController.new);
