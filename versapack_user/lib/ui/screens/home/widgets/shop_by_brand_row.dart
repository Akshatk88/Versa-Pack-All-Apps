import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/brand.dart';
import '../../../common/widgets/cards/brand_card.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';

/// "Shop by Brand" horizontal strip matching exact screenshot design.
class ShopByBrandRow extends StatelessWidget {
  const ShopByBrandRow({
    super.key,
    this.brands = const [],
    this.isLoading = false,
    this.onBrandTap,
    this.onSeeAll,
  });

  final List<Brand> brands;
  final bool isLoading;
  final ValueChanged<Brand>? onBrandTap;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && brands.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header Row: Shop by Brand | See all ->
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shop by Brand',
                style: context.text.titleLarge!.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: context.colors.onSurface,
                ),
              ),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: Row(
                    children: [
                      Text(
                        'See all',
                        style: context.text.labelSmall!.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: context.semantic.success,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: context.semantic.success,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Brand Cards Horizontal Strip
        SizedBox(
          height: 66,
          child: isLoading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: 5,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, _) => ShimmerBox(
                    width: 84,
                    height: 64,
                    radius: BorderRadius.circular(18),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: brands.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final brand = brands[index];
                    return BrandCard(
                      brand: brand,
                      onTap: () => onBrandTap?.call(brand),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
