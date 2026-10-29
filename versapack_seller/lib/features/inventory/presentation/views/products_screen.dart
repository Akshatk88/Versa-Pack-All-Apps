import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:quick_commerce_seller/config/constants/app_constants.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:quick_commerce_seller/core/widgets/app_drawer.dart';
import 'package:quick_commerce_seller/features/inventory/domain/product_model.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/controllers/inventory_controller.dart';
import 'package:quick_commerce_seller/features/notifications/presentation/controllers/notifications_controller.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  int _selectedCategoryIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => setState(() => _query = _searchController.text.trim()),
    );
  }

  /// The seller's real catalogue, in the map shape this screen was written
  /// against, so the cards and sheets below are untouched.
  List<Map<String, dynamic>> get _products {
    final products = ref.watch(inventoryControllerProvider).value ?? const [];
    return products.map(_cardFor).toList();
  }

  Map<String, dynamic> _cardFor(ProductModel p) {
    // Out of stock is a different state from switched off: one is a count, the
    // other a decision. Only the seller's decision reads as Inactive.
    final outOfStock = p.stockQuantity <= 0;
    return {
      'id': p.id,
      'name': p.name,
      'sku': p.unit.isEmpty ? p.categoryName : p.unit,
      'category': p.categoryName,
      'price': '₹${p.price.toStringAsFixed(2)}',
      'mrp': p.originalPrice == null
          ? ''
          : '₹${p.originalPrice!.toStringAsFixed(2)}',
      'stock': '${p.stockQuantity}',
      'image': p.imageUrl ?? '',
      'isInactive': !p.isAvailable,
      // Read by the stock label. Absent since the switch to live data, which
      // threw 'Null is not a subtype of bool' on every render.
      'isOutOfStock': outOfStock,
      'status': !p.isAvailable
          ? 'Inactive'
          : (outOfStock ? 'Out of stock' : 'Active'),
    };
  }

  /// Search term plus the selected category chip.
  List<Map<String, dynamic>> get _visibleProducts {
    final query = _query.toLowerCase();
    final categories = _categories;
    // The chip list is derived from live products now, so a selection made
    // when there were more categories can point past the end of a shorter
    // one -- which throws rather than merely showing the wrong chip.
    final index = _selectedCategoryIndex < categories.length
        ? _selectedCategoryIndex
        : 0;
    final category = categories.isEmpty
        ? 'All'
        : categories[index]['label'].toString();
    return _products.where((p) {
      if (query.isNotEmpty) {
        final haystack = '${p['name']} ${p['sku']} ${p['category']}'
            .toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      // The chip labels are abbreviated ("Dairy" for "Dairy & Eggs"), so match
      // on prefix rather than equality.
      if (category != 'All' &&
          !p['category'].toString().toLowerCase().startsWith(
            category.toLowerCase(),
          )) {
        return false;
      }
      return true;
    }).toList();
  }

  /// The product's own photo once one has been uploaded, otherwise a neutral
  /// glyph. The previous code cast `p['icon']` straight to `IconData`, but live
  /// products carry no icon — only mock rows did — so it threw on every build.
  Widget _buildProductThumb(Map<String, dynamic> p) {
    final url = AppConstants.resolveMediaUrl(p['image']?.toString());
    if (url.isEmpty) {
      return const Icon(
        Icons.inventory_2_outlined,
        color: Color(0xFFD97706),
        size: 26,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: 50,
      height: 50,
      memCacheWidth: 150,
      placeholder: (_, _) => const ColoredBox(color: Color(0xFFFEF3C7)),
      errorWidget: (_, _, _) => const Icon(
        Icons.inventory_2_outlined,
        color: Color(0xFFD97706),
        size: 26,
      ),
    );
  }

  void _openCategoryFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                for (var i = 0; i < _categories.length; i++)
                  ListTile(
                    leading: Icon(
                      _selectedCategoryIndex == i
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: _selectedCategoryIndex == i
                          ? const Color(0xFFD97706)
                          : context.textSecondary,
                    ),
                    title: Text(_categories[i]['label'].toString()),
                    onTap: () {
                      setState(() => _selectedCategoryIndex = i);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: context.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'No products match',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _query.isNotEmpty
                ? 'Nothing matches "$_query" in this category.'
                : 'No products in this category yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _selectedCategoryIndex = 0);
            },
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }

  /// The seller's own categories, with All pinned first because the filter
  /// logic treats index 0 as "no filter". Counts are of products actually
  /// loaded, not of what a category claims to hold.
  List<Map<String, dynamic>> get _categories {
    final products = ref.watch(inventoryControllerProvider).value ?? const [];
    final names = <String>{
      for (final p in products)
        if (p.categoryName.isNotEmpty) p.categoryName,
    }.toList()..sort();

    return [
      {'label': 'All', 'count': '${products.length}'},
      for (final name in names)
        {
          'label': name,
          'count': '${products.where((p) => p.categoryName == name).length}',
        },
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(inventoryControllerProvider).value ?? const [];

    return Scaffold(
      backgroundColor: context.pageBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(
              Icons.menu_rounded,
              color: context.textPrimary,
              size: 26,
            ),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Column(
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Inter',
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(
                    text: 'Versa',
                    style: TextStyle(color: context.textPrimary),
                  ),
                  TextSpan(
                    text: 'pack',
                    style: TextStyle(color: Color(0xFF0F9D58)),
                  ),
                ],
              ),
            ),
            Text(
              'Quick Seller',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: context.textPrimary,
                  size: 26,
                ),
                onPressed: () => context.push('/notifications'),
              ),
              // Hidden at zero: a badge reading "0" is worse than no badge.
              if (ref.watch(unreadNotificationsCountProvider) > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${ref.watch(unreadNotificationsCountProvider)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header Title & Add Product Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Products',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage your store products and stock',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/add-product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFD9027),
                        foregroundColor: const Color(0xFF181C2E),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: context.textPrimary,
                      ),
                      label: Text(
                        'Add Product',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4 Summary Metric Cards Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMetricCard(
                      icon: Icons.widgets_rounded,
                      iconBg: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFFFBEB),
                      label: 'Total Products',
                      count: '${products.length}',
                      subtitle: 'All Products',
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      icon: Icons.check_rounded,
                      iconBg: const Color(0xFFA7F3D0),
                      iconColor: const Color(0xFF059669),
                      bgColor: const Color(0xFFECFDF5),
                      label: 'Active Products',
                      count: '${products.where((p) => p.isAvailable).length}',
                      subtitle: 'Visible to customers',
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      icon: Icons.visibility_off_outlined,
                      iconBg: const Color(0xFFFCA5A5),
                      iconColor: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEF2F2),
                      label: 'Inactive Products',
                      count: '${products.where((p) => !p.isAvailable).length}',
                      subtitle: 'Hidden from store',
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      icon: Icons.inventory_2_outlined,
                      iconBg: const Color(0xFFDDD6FE),
                      iconColor: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFF5F3FF),
                      label: 'Out of Stock',
                      count: '${products.where((p) => p.stockQuantity <= 0).length}',
                      subtitle: 'Not available',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search Input & Filter Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Search products by name, category, barcode...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: context.textSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _openCategoryFilterSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            size: 16,
                            color: context.textPrimary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Filter',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: context.textPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Category Pills Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...List.generate(_categories.length, (index) {
                      final isSelected = _selectedCategoryIndex == index;
                      final c = _categories[index];

                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategoryIndex = index),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFEF3C7)
                                : context.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFD9027)
                                  : context.borderColor,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                c['label'].toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                c['count'].toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'More',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: context.textPrimary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Product Cards List
              Container(
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: _visibleProducts.isEmpty
                    ? _buildEmptyState()
                    : Column(
                        children: List.generate(_visibleProducts.length, (
                          index,
                        ) {
                          final p = _visibleProducts[index];
                          final isLast = index == _visibleProducts.length - 1;

                          return Column(
                            children: [
                              InkWell(
                                // Tapping a product opens its details, not a
                                // blank create form.
                                onTap: () => context.push(
                                  '/product-details/${p['id']}',
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: _buildProductThumb(p),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p['name'].toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: context.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'SKU: ${p['sku']}  •  ${p['category']}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: context.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // Wrap, not Row: on narrow phones the badge
                                            // and stock label need to fall to a second line.
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (p['isInactive']
                                                            as bool)
                                                        ? const Color(
                                                            0xFFFEF2F2,
                                                          )
                                                        : const Color(
                                                            0xFFECFDF5,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    p['status'].toString(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          (p['isInactive']
                                                              as bool)
                                                          ? const Color(
                                                              0xFFDC2626,
                                                            )
                                                          : const Color(
                                                              0xFF059669,
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  p['stock'].toString(),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        (p['isOutOfStock']
                                                            as bool)
                                                        ? const Color(
                                                            0xFFDC2626,
                                                          )
                                                        : const Color(
                                                            0xFF10B981,
                                                          ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            p['price'].toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: context.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'MRP: ${p['mrp']}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: context.textSecondary,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (!isLast)
                                Divider(height: 1, color: context.borderColor),
                            ],
                          );
                        }),
                      ),
              ),
              const SizedBox(height: 14),

              // Every product is rendered in one list, so the page numbers
              // that used to sit here (1 2 3 ... 13) pointed at nothing. Only
              // the count is real.
              Text(
                'Showing ${_visibleProducts.length} of ${products.length} products',
                style: TextStyle(fontSize: 11, color: context.textSecondary),
              ),
              const SizedBox(height: 16),

              // Bottom Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFEF08A)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFD9027),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.sell_rounded,
                        color: context.textPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keep your catalog updated',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Update prices and stock regularly to increase your sales.',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String count,
    required String subtitle,
  }) {
    return Container(
      width: 125,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF181C2E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
