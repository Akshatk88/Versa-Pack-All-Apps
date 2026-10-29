import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/constants/app_constants.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:quick_commerce_seller/core/network/api_exception.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/core/widgets/async_state_view.dart';
import 'package:quick_commerce_seller/features/inventory/domain/product_model.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/controllers/inventory_controller.dart';

/// Everything the backend holds about one product, plus the actions a seller
/// can take on it.
///
/// The product is read from the live catalogue rather than fetched separately,
/// so an edit saved here is reflected the moment the list refreshes — here, on
/// the products list and anywhere else the same provider is watched.
class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(inventoryControllerProvider);
    final product = ref.watch(productByIdProvider(productId));

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left_rounded,
            color: context.textPrimary,
            size: 28,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Product Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (product != null)
            IconButton(
              tooltip: 'Delete product',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
              ),
              onPressed: () => _confirmDelete(context, ref, product),
            ),
        ],
      ),
      body: SafeArea(
        child: AsyncStateView<List<ProductModel>>(
          value: catalogue,
          onRetry: () =>
              ref.read(inventoryControllerProvider.notifier).refresh(),
          isEmpty: (_) => product == null,
          emptyIcon: Icons.inventory_2_outlined,
          emptyTitle: 'Product not found',
          emptyMessage: 'It may have been deleted from your catalogue.',
          enableRefresh: false,
          builder: (_) {
            final p = product!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Gallery(images: p.images),
                const SizedBox(height: 16),
                _header(context, p),
                const SizedBox(height: 16),
                _pricingCard(context, p),
                if (p.hasVariants) ...[
                  const SizedBox(height: 16),
                  _variantsCard(context, p),
                ],
                const SizedBox(height: 16),
                _stockCard(context, ref, p),
                if (p.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionCard(context, 'Description', [
                    Text(
                      p.description.trim(),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: context.textSecondary,
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 16),
                _detailsCard(context, p),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: product == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/add-product/${product.id}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFD9027),
                      foregroundColor: const Color(0xFF181C2E),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: const Text(
                      'Edit Product',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _header(BuildContext context, ProductModel p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _VegBadge(foodType: p.foodType),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (p.brand.trim().isNotEmpty)
              _chip(context, p.brand.trim(), Icons.sell_outlined),
            if (p.categoryName.trim().isNotEmpty)
              _chip(context, p.categoryName.trim(), Icons.category_outlined),
            if (p.unit.trim().isNotEmpty)
              _chip(context, p.unit.trim(), Icons.straighten_rounded),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _ApprovalBadge(product: p),
            const SizedBox(width: 8),
            if (p.totalRatings > 0)
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${p.rating.toStringAsFixed(1)} (${p.totalRatings})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (p.approval == ProductApproval.rejected &&
            p.rejectionReason.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text(
              p.rejectionReason.trim(),
              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pricingCard(BuildContext context, ProductModel p) {
    final discount = p.discountPercent;
    return _sectionCard(context, 'Pricing', [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₹${p.price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          if (p.originalPrice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '₹${p.originalPrice!.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  decoration: TextDecoration.lineThrough,
                  color: context.textSecondary,
                ),
              ),
            ),
          const Spacer(),
          if (discount != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$discount% OFF',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
              ),
            ),
        ],
      ),
      if (p.gstRate != null) ...[
        const SizedBox(height: 8),
        Text(
          'GST ${p.gstRate!.toStringAsFixed(p.gstRate! % 1 == 0 ? 0 : 2)}%',
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
      ],
    ]);
  }

  Widget _variantsCard(BuildContext context, ProductModel p) {
    return _sectionCard(context, 'Variants', [
      for (final v in p.variants)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  v.name,
                  style: TextStyle(fontSize: 13, color: context.textPrimary),
                ),
              ),
              if (v.otherPrice != null) ...[
                Text(
                  '₹${v.otherPrice!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    decoration: TextDecoration.lineThrough,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '₹${v.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _stockCard(BuildContext context, WidgetRef ref, ProductModel p) {
    final outOfStock = p.stockQuantity <= 0;
    final (label, bg, fg) = !p.isAvailable
        ? ('Hidden', const Color(0xFFF3F4F6), const Color(0xFF6B7280))
        : outOfStock
        ? ('Out of stock', const Color(0xFFFEE2E2), const Color(0xFFDC2626))
        : p.isLowStock
        ? ('Low stock', const Color(0xFFFFFBEB), const Color(0xFFD97706))
        : ('In stock', const Color(0xFFECFDF5), const Color(0xFF059669));

    return _sectionCard(context, 'Stock & availability', [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${p.stockQuantity} in stock',
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: Text(
              p.isAvailable ? 'Visible to customers' : 'Hidden from customers',
              style: TextStyle(fontSize: 13, color: context.textPrimary),
            ),
          ),
          Switch(
            value: p.isAvailable,
            onChanged: (value) async {
              try {
                await ref
                    .read(inventoryControllerProvider.notifier)
                    .toggleStock(p.id, value);
                if (!context.mounted) return;
                AppToast.show(
                  context,
                  value ? 'Now visible to customers' : 'Hidden from customers',
                );
              } catch (e) {
                if (!context.mounted) return;
                AppToast.showError(context, _messageFor(e));
              }
            },
          ),
        ],
      ),
    ]);
  }

  Widget _detailsCard(BuildContext context, ProductModel p) {
    final rows = <(String, String)>[
      if (p.unit.trim().isNotEmpty) ('Pack size', p.unit.trim()),
      if (p.brand.trim().isNotEmpty) ('Brand', p.brand.trim()),
      ('Food type', p.foodType),
      if (p.lowStockThreshold != null)
        ('Low stock alert at', '${p.lowStockThreshold}'),
      if (p.maxQtyPerOrder != null)
        ('Max per order', '${p.maxQtyPerOrder}'),
      if (p.preparationTime.trim().isNotEmpty)
        ('Preparation time', p.preparationTime.trim()),
      ('Recommended', p.isRecommended ? 'Yes' : 'No'),
    ];

    return _sectionCard(context, 'Details', [
      for (final (label, value) in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _sectionCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.pageBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ProductModel p) {
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          '"${p.name}" will be removed from your catalogue. This cannot be '
          'undone — to take it off sale temporarily, switch it off instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true || !context.mounted) return;
      try {
        await ref
            .read(inventoryControllerProvider.notifier)
            .deleteProduct(p.id);
        if (!context.mounted) return;
        AppToast.show(context, '"${p.name}" deleted');
        context.pop();
      } catch (e) {
        if (!context.mounted) return;
        AppToast.showError(context, _messageFor(e));
      }
    });
  }

  static String _messageFor(Object error) {
    if (error is DioException && error.error is ApiException) {
      return (error.error as ApiException).message;
    }
    return 'Something went wrong. Please try again.';
  }
}

/// Swipeable photos, with a page indicator once there is more than one.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.images});

  final List<String> images;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Icon(
            Icons.inventory_2_outlined,
            size: 56,
            color: Color(0xFFD97706),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: AppConstants.resolveMediaUrl(widget.images[i]),
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (_, _) =>
                    const ColoredBox(color: Color(0xFFFEF3C7)),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: Color(0xFFFEF3C7),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.images.length; i++)
                Container(
                  width: _page == i ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _page == i
                        ? const Color(0xFFFD9027)
                        : context.borderColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _VegBadge extends StatelessWidget {
  const _VegBadge({required this.foodType});

  final String foodType;

  @override
  Widget build(BuildContext context) {
    final isVeg = foodType.toLowerCase() != 'non-veg';
    final color = isVeg ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (product.approval) {
      ProductApproval.approved => (
        const Color(0xFFECFDF5),
        const Color(0xFF059669),
      ),
      ProductApproval.pending => (
        const Color(0xFFFFFBEB),
        const Color(0xFFD97706),
      ),
      ProductApproval.rejected => (
        const Color(0xFFFEE2E2),
        const Color(0xFFDC2626),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        product.approval.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
