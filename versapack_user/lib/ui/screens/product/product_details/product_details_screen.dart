import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/network/share_links.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../di/app_providers.dart';

import '../../../../domain/model/product.dart';
import '../../../../domain/model/product_variant.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/cart_actions.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/badges/delivery_time_badge.dart';
import '../../../common/widgets/loaders/full_page_loader.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../../../common/widgets/misc/quantity_stepper.dart';
import '../../../common/widgets/misc/section_header.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../../home/widgets/product_row.dart';
import '../product_listing/product_listing_args.dart';
import 'product_details_provider.dart';
import 'product_details_state.dart';
import 'widgets/product_image_carousel.dart';
import 'widgets/reviews_section.dart';
import 'widgets/write_review_sheet.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.productId,
    this.product,
    this.heroTag,
  });

  final String productId;
  final Product? product;
  final String? heroTag;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  late final ProductDetailsArgs _args = ProductDetailsArgs(
    productId: widget.productId,
    product: widget.product,
  );

  final _imageKey = GlobalKey();

  Future<void> _addToCart(ProductDetailsState state) async {
    final product = state.product;
    if (product == null) return;

    await CartActions.add(
      context,
      ref,
      product: product,
      variant: state.selectedVariant,
      addons: state.selectedAddons,
      quantity: state.quantity,
      sourceKey: _imageKey,
      askForAddons: false,
    );
  }

  Future<void> _writeReview(ProductDetailsState state) async {
    final product = state.product;
    if (product == null) return;

    final draft = await WriteReviewSheet.show(
      context,
      productName: product.name,
      orders: state.rateableOrders,
    );
    if (draft == null || !mounted) return;

    try {
      await ref.read(productDetailsProvider(_args).notifier).submitReview(
            orderId: draft.orderId,
            rating: draft.rating,
            comment: draft.comment,
          );
      if (mounted) {
        AppToast.success(context, 'Thanks for your review');
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not submit your review');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productDetailsProvider(_args));

    if (state.isLoading && state.product == null) {
      return const Scaffold(body: FullPageLoader(message: 'Loading product…'));
    }

    final product = state.product;
    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorStateWidget(
          failure: state.failure ??
              const NotFoundFailure('We could not load this product right now.'),
          onRetry: () => ref.read(productDetailsProvider(_args).notifier).load(),
        ),
      );
    }

    final inCartQuantity =
        ref.watch(cartProvider.select((s) => s.cart.quantityOf(product.id)));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      bottomNavigationBar: _StickyBottomBar(
        state: state,
        inCartQuantity: inCartQuantity,
        onAdd: () => _addToCart(state),
        onViewCart: () => context.go(RoutePaths.cart),
        onSelectVariant: (v) => ref
            .read(productDetailsProvider(_args).notifier)
            .selectVariant(v),
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Top Yellow Header with Versapack Logo & Action Buttons
          _buildTopHeader(context, product, state),

          // 2. Product Image Gallery Section
          SliverToBoxAdapter(child: _buildImageGallerySection(context, product)),

          // 3. Delivery Time & Rating Banner Card
          SliverToBoxAdapter(child: _buildDeliveryAndRatingCard(context, product)),

          // 4. Product Name, Unit Subtitle & Select Unit Grid
          SliverToBoxAdapter(child: _buildProductTitleAndVariants(context, state)),

          // 5. Pricing & Discount Row
          SliverToBoxAdapter(child: _buildPricingRow(context, state)),

          // 6. View Product Details Accordion
          SliverToBoxAdapter(child: _buildViewProductDetailsAccordion(context, product)),

          // 7. Store / Seller Card ("Sold by Amul Official Store")
          SliverToBoxAdapter(child: _buildSellerCard(context, product)),

          // 8. Reviews & Ratings Section
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Ratings & reviews'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ReviewsSection(
                    summary: state.ratingSummary,
                    reviews: state.reviews,
                    canWrite: state.canRate,
                    onWrite: () => _writeReview(state),
                  ),
                ),
              ],
            ),
          ),

          // 9. Similar Products Horizontal Strip
          if (state.related.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Similar products',
                    onSeeAll: () => context.push(
                      RoutePaths.productListing,
                      extra: ProductListingArgs(
                        title: 'Similar Products',
                        categoryId: product.categoryId,
                      ),
                    ),
                  ),
                  ProductRow(
                    products: state.related,
                    heroTag: 'related-${product.id}',
                    onProductTap: (p) => context.push(
                      RoutePaths.productDetailsOf(p.id),
                      extra: p,
                    ),
                  ),
                ],
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
      ),
    );
  }

  // 1. Top Yellow Header with Versapack Logo & Action Buttons
  Widget _buildTopHeader(
    BuildContext context,
    Product product,
    ProductDetailsState state,
  ) {
    final isWishlisted = ref.watch(isWishlistedProvider(product.id));

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: Colors.white,
      toolbarHeight: 56,
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Row(
        children: [
          // Left: Back button card
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Center: Versapack Logo & Groceries in 10 Mins
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'versa',
                      style: context.text.displaySmall!.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1F2937),
                        fontSize: 25,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: 'pack',
                      style: context.text.displaySmall!.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF16A34A),
                        fontSize: 25,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Groceries in 10 Mins',
                style: context.text.labelSmall!.copyWith(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                  height: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Right action cards: Search | Wishlist | Share
          _headerActionBtn(
            icon: Icons.search_rounded,
            onTap: () => context.push(RoutePaths.search),
          ),
          const SizedBox(width: 6),
          _headerActionBtn(
            icon: isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            iconColor: isWishlisted ? const Color(0xFFEF4444) : const Color(0xFF1F2937),
            onTap: () => CartActions.toggleWishlist(context, ref, product),
          ),
          const SizedBox(width: 6),
          _headerActionBtn(
            icon: Icons.share_outlined,
            onTap: () => Share.share(
              '${product.name} on Versapack — ${product.price.asCurrency}\n'
              '${ShareLinks.product(
                productId: product.id,
                sellerId: product.sellerId,
              )}',
              subject: product.name,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerActionBtn({
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 19,
          color: iconColor ?? const Color(0xFF1F2937),
        ),
      ),
    );
  }

  // 2. Product Image Gallery Section
  Widget _buildImageGallerySection(BuildContext context, Product product) {
    final images = product.gallery.isNotEmpty
        ? product.gallery
        : [product.imageUrl];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Stack(
        children: [
          // Gallery Carousel
          ProductImageCarousel(
            images: images,
            heroTag: '${widget.heroTag ?? 'product'}-${product.id}',
            height: 220,
            desaturated: !product.isPurchasable,
          ),
          // Veg Indicator Badge on top left
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: VegIndicator(isVeg: product.isVeg),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Delivery Time & Rating Banner Card
  Widget _buildDeliveryAndRatingCard(BuildContext context, Product product) {
    final address = ref.watch(selectedAddressProvider);
    final rating = product.rating;
    final ratingCount = product.ratingCount;
    final hasRating = rating > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Scooter icon + Delivery text
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBEB),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.two_wheeler_rounded,
              size: 17,
              color: Color(0xFFFFC107),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.deliveryMinutes != null
                      ? 'Delivered in ~${product.deliveryMinutes} mins'
                      : 'Delivery time at checkout',
                  style: context.text.titleSmall!.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        address?.shortLine ?? 'Set your delivery address',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall!.copyWith(
                          fontSize: 10.5,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Rating card — only when the product has been rated.
          if (hasRating)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: Color(0xFF1F2937),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: context.text.titleSmall!.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
                if (ratingCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '($ratingCount ${ratingCount == 1 ? 'review' : 'reviews'})',
                    style: context.text.bodySmall!.copyWith(
                      fontSize: 10,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // 4. Product Name, Unit Subtitle & Select Unit Grid
  Widget _buildProductTitleAndVariants(
    BuildContext context,
    ProductDetailsState state,
  ) {
    final product = state.product!;
    final variants = product.variants.isNotEmpty
        ? product.variants
        : [
            ProductVariant(
              id: 'default',
              name: product.unitLabel,
              price: product.price,
              comparePrice: product.strikePrice,
            )
          ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            product.name,
            style: context.text.titleLarge!.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: const Color(0xFF1F2937),
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          // Subtitle (e.g. 500 ml)
          Text(
            state.selectedVariant?.name ?? product.unitLabel,
            style: context.text.bodyMedium!.copyWith(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          // Select Unit Section Header
          Text(
            'Select Unit',
            style: context.text.titleSmall!.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          // Variant Grid / Horizontal Row
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: variants.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final v = variants[index];
                final isSelected = (state.selectedVariant?.id == v.id) ||
                    (state.selectedVariant == null && index == 0);

                return GestureDetector(
                  onTap: () {
                    AppHaptics.selection();
                    ref
                        .read(productDetailsProvider(_args).notifier)
                        .selectVariant(v);
                  },
                  child: Container(
                    width: 88,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFFC107) : const Color(0xFFE5E7EB),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          v.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall!.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '₹${v.price.toInt()}',
                          style: context.text.bodySmall!.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 5. Pricing & Discount Row
  Widget _buildPricingRow(BuildContext context, ProductDetailsState state) {
    final product = state.product!;
    final isPurchasable = product.isPurchasable;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                state.effectiveUnitPrice.asCurrency,
                style: context.text.displaySmall!.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 8),
              if (state.effectiveStrikePrice != null &&
                  state.effectiveStrikePrice! > state.effectiveUnitPrice) ...[
                Text(
                  'MRP ${state.effectiveStrikePrice!.asCurrency}',
                  style: context.text.bodyMedium!.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: const Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9C3),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${state.effectiveUnitPrice.discountPercentFrom(state.effectiveStrikePrice)}% OFF',
                    style: context.text.labelSmall!.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 9.5,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (!isPurchasable)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Out of stock',
                    style: context.text.labelSmall!.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFDC2626),
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            'Inclusive of all taxes',
            style: context.text.bodySmall!.copyWith(
              fontSize: 10.5,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  // 6. View Product Details Accordion
  Widget _buildViewProductDetailsAccordion(
    BuildContext context,
    Product product,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: context.theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          leading: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.assignment_outlined,
              size: 14,
              color: Color(0xFFD97706),
            ),
          ),
          title: Text(
            'View product details',
            style: context.text.titleSmall!.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: const Color(0xFF1F2937),
            ),
          ),
          trailing: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Color(0xFF1F2937),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.description.trim().isNotEmpty) ...[
              Text(
                'Description',
                style: context.text.titleSmall!.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                product.description,
                style: context.text.bodySmall!.copyWith(
                  fontSize: 11,
                  color: const Color(0xFF4B5563),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
            ],
            _specRow('Brand', product.brand),
            _specRow('Pack size', product.packSize),
            _specRow('Category', product.categoryName),
            _specRow(
              'Food type',
              product.isVeg ? 'Vegetarian' : 'Non-vegetarian',
            ),
            _specRow('Sold by', product.sellerName),
          ],
        ),
      ),
    );
  }

  Widget _specRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 7. Store / Seller Card ("Sold by Amul Official Store")
  Widget _buildSellerCard(BuildContext context, Product product) {
    final sellerName = product.sellerName.trim();
    if (sellerName.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: product.sellerImageUrl.trim().isNotEmpty
                ? AppNetworkImage(
                    url: product.sellerImageUrl,
                    width: 38,
                    height: 38,
                    fallbackIcon: Icons.storefront_outlined,
                  )
                : Container(
                    width: 38,
                    height: 38,
                    color: const Color(0xFFFFC107),
                    alignment: Alignment.center,
                    child: Text(
                      sellerName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sold by',
                  style: context.text.bodySmall!.copyWith(
                    fontSize: 10,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        sellerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall!.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  product.sellerAcceptingOrders
                      ? 'Accepting orders'
                      : 'Not accepting orders right now',
                  style: context.text.bodySmall!.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: product.sellerAcceptingOrders
                        ? const Color(0xFF15803D)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => context.push(
              RoutePaths.productListing,
              extra: ProductListingArgs(
                title: sellerName,
                sellerId: product.sellerId,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFC107), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Explore all products',
                    style: context.text.labelSmall!.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 9.5,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 13,
                    color: Color(0xFF1F2937),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom bar: quantity, live line price, and add/view-cart.
class _StickyBottomBar extends ConsumerWidget {
  const _StickyBottomBar({
    required this.state,
    required this.inCartQuantity,
    required this.onAdd,
    required this.onViewCart,
    required this.onSelectVariant,
  });

  final ProductDetailsState state;
  final int inCartQuantity;
  final VoidCallback onAdd;
  final VoidCallback onViewCart;
  final ValueChanged<ProductVariant> onSelectVariant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = state.product;
    if (product == null) return const SizedBox.shrink();

    final purchasable = product.isPurchasable && product.sellerAcceptingOrders;
    final selectedVariantName =
        state.selectedVariant?.name ?? product.unitLabel;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Variant Dropdown Pill
          GestureDetector(
            onTap: () {
              if (product.variants.isNotEmpty) {
                _showVariantPicker(
                  context,
                  product,
                  state.selectedVariant,
                  onSelectVariant,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  Text(
                    selectedVariantName,
                    style: context.text.titleSmall!.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: Color(0xFF1F2937),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Price Column
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.effectiveUnitPrice.asCurrency,
                  style: context.text.titleLarge!.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                Text(
                  'Inclusive of all taxes',
                  style: context.text.bodySmall!.copyWith(
                    fontSize: 9,
                    color: const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Add to Cart / Stepper Button
          if (!purchasable)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Out of stock',
                style: context.text.labelMedium!.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFDC2626),
                  fontSize: 12,
                ),
              ),
            )
          else if (inCartQuantity > 0)
            QuantityStepper(
              quantity: inCartQuantity,
              height: 44,
              canIncrement: true,
              onIncrement: onAdd,
              onDecrement: () => CartActions.decrement(ref, product),
            )
          else
            GestureDetector(
              onTap: () {
                AppHaptics.medium();
                onAdd();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      size: 18,
                      color: Color(0xFF1F2937),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add to Cart',
                      style: context.text.titleSmall!.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showVariantPicker(
    BuildContext context,
    Product product,
    ProductVariant? current,
    ValueChanged<ProductVariant> onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Unit',
                style: context.text.titleMedium!.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              for (final v in product.variants)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    v.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('₹${v.price.toInt()}'),
                  trailing: current?.id == v.id
                      ? const Icon(Icons.check_circle, color: Color(0xFFFFC107))
                      : null,
                  onTap: () {
                    onSelect(v);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
