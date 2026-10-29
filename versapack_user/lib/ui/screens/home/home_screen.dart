import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/logger.dart';
import '../../../di/app_providers.dart';
import '../../../domain/model/banner.dart';
import '../../../navigation/route_paths.dart';
import '../../common/smart_scan.dart';
import '../../common/widgets/inputs/search_bar_widget.dart';
import '../../common/widgets/misc/section_header.dart';
import '../../common/widgets/misc/sound_refresh_indicator.dart';
import '../../common/widgets/states/error_state_widget.dart';
import '../../common/widgets/states/offline_banner.dart';
import '../../common/widgets/feedback/app_dialog.dart';
import '../product/product_listing/product_listing_args.dart';
import 'home_provider.dart';
import 'home_state.dart';
import 'widgets/active_order_card.dart';
import 'widgets/offer_coupons_row.dart';
import 'widgets/product_row.dart';
import 'widgets/quick_category_row.dart';
import 'widgets/shop_by_brand_row.dart';
import 'widgets/top_sellers_row.dart';
import 'widgets/delivery_header.dart';
import 'widgets/banner_carousel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ScrollController _scrollController;
  bool _headerCollapsed = false;
  bool _addressPromptShown = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptForAddress());
  }

  Future<void> _promptForAddress() async {
    if (!mounted || _addressPromptShown) return;

    // The address provider loads asynchronously when authentication becomes
    // available. Awaiting it here keeps the prompt from flashing before the
    // saved address list has been checked.
    await ref.read(addressBookProvider.notifier).load();
    if (!mounted || _addressPromptShown) return;
    if (ref.read(addressBookProvider).addresses.isNotEmpty) return;

    _addressPromptShown = true;
    AppLogger.action('address_prompt_shown', scope: 'location');
    final addLocation = await AppDialog.confirm(
      context,
      icon: Icons.location_on_outlined,
      title: 'Add your delivery location',
      message: 'Add an address to see products and delivery times available near you.',
      confirmLabel: 'Add location',
      cancelLabel: 'Maybe later',
    );
    if (!addLocation || !mounted) return;

    AppLogger.action('address_prompt_confirmed', scope: 'location');
    await context.push(RoutePaths.locationPermission);
  }

  void _handleScroll() {
    final isCollapsed =
        _scrollController.hasClients && _scrollController.offset > 180;
    if (isCollapsed != _headerCollapsed) {
      setState(() => _headerCollapsed = isCollapsed);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            _headerCollapsed ? Brightness.dark : Brightness.light,
        statusBarBrightness:
            _headerCollapsed ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.colors.surface,
        body: Stack(
          children: [
            Column(
              children: [
                const OfflineBanner(),
                Expanded(
                  child: _buildBody(context, state, topPadding),
                ),
              ],
            ),

            // Active Order Floating Card above bottom navigation
            const Positioned(
              left: 0,
              right: 0,
              bottom: 4,
              child: ActiveOrderFloatingCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HomeState state, double topPadding) {
    if (state.failure != null &&
        state.sections.isEmpty &&
        state.categories.isEmpty) {
      return ErrorStateWidget(
        failure: state.failure!,
        onRetry: () => ref.read(homeProvider.notifier).load(refresh: true),
      );
    }

    return SoundRefreshIndicator(
      onRefresh: () => ref.read(homeProvider.notifier).load(refresh: true),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // 1. Static Gradient Header with Search
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.colors.primary,
                    context.colors.primary.withValues(alpha: 0.72),
                    context.semantic.brandSurfaceSoft,
                    context.colors.surface,
                    context.colors.surface,
                  ],
                  stops: const [0.0, 0.4, 0.7, 0.9, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const DeliveryHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                      child: SearchBarWidget(
                        readOnly: true,
                        categories: state.categories.map((c) => c.name).toList(),
                        onTap: () => context.push(RoutePaths.search),
                        onScanTap: () => SmartScan.run(context, ref),
                        onMicTap: () => context.push('${RoutePaths.search}?voice=1'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Quick category icon strip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: QuickCategoryRow(
                categories: state.categories,
                isLoading: state.isLoadingCategories,
                onAllTap: () => context.go(RoutePaths.categories),
                onCategoryTap: (catId) =>
                    context.push(RoutePaths.subCategoryOf(catId)),
              ),
            ),
          ),

          // 3. Promo Banner Carousel
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BannerCarousel(
                banners: state.banners,
                isLoading: state.isLoadingBanners,
                onTap: (banner) => _openBanner(context, banner),
              ),
            ),
          ),

          // 3. Live offer cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: OfferCouponsRow(
                coupons: state.coupons,
                isLoading: state.isLoadingCoupons,
                onOfferTap: (_) => context.push(RoutePaths.coupons),
              ),
            ),
          ),

          // 4. Top Sellers section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TopSellersRow(
                sellers: state.sellers,
                isLoading: state.isLoadingSections,
                onSeeAll: () => context.push(
                  RoutePaths.productListing,
                  extra: const ProductListingArgs(title: 'Top Sellers'),
                ),
                onSellerTap: (seller) => context.push(
                  RoutePaths.productListing,
                  extra: ProductListingArgs(
                    title: seller.name,
                    sellerId: seller.id,
                  ),
                ),
              ),
            ),
          ),

          // 5. Brands row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ShopByBrandRow(
                brands: state.brands,
                isLoading: state.isLoadingSections,
                onSeeAll: () => context.push(
                  RoutePaths.productListing,
                  extra: const ProductListingArgs(title: 'Shop by Brand'),
                ),
                onBrandTap: (brand) => context.push(
                  RoutePaths.productListing,
                  extra: ProductListingArgs(
                    title: brand.name,
                    brandName: brand.name,
                  ),
                ),
              ),
            ),
          ),

          // 6. Dynamic catalog sections (Bestsellers, Mega Deals, etc.)
          ...state.sections.map((section) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SectionHeader(
                      title: section.title,
                      subtitle: section.subtitle,
                      onSeeAll: () => context.push(
                        RoutePaths.productListing,
                        extra: ProductListingArgs(
                          title: section.title,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ProductRow(
                      products: section.products,
                      heroTag: 'home_${section.id}',
                      onProductTap: (product) => context.push(
                        RoutePaths.productDetailsOf(product.id),
                        extra: product,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xl * 2),
          ),
        ],
      ),
    );
  }



  void _openBanner(BuildContext context, PromoBanner banner) {
    switch (banner.target) {
      case BannerTarget.offers:
        context.push(RoutePaths.coupons);
        break;
      case BannerTarget.category:
        if (banner.targetId.isNotEmpty) {
          context.push(RoutePaths.subCategoryOf(banner.targetId));
        } else {
          context.go(RoutePaths.categories);
        }
        break;
      case BannerTarget.restaurant:
        context.push(
          RoutePaths.productListing,
          extra: ProductListingArgs(
            title: banner.title,
            sellerId: banner.targetId,
          ),
        );
        break;
      case BannerTarget.products:
      case BannerTarget.none:
        context.push(
          RoutePaths.productListing,
          extra: ProductListingArgs(
            title: banner.title.isEmpty ? 'Featured Products' : banner.title,
          ),
        );
        break;
    }
  }
}
