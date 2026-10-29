import '../model/brand.dart';
import '../model/product.dart';
import '../model/seller.dart';
import '../model/sub_category.dart';

/// Derives the groupings the backend does not model.
///
/// The catalog is a flat category → item tree with a free-text `brand` field,
/// so sub-categories, brands and sellers are computed from the items themselves. Both
/// gaps are documented in the README.
class CatalogGroupingService {
  const CatalogGroupingService();

  /// Extract seller details and their backend products from catalog items.
  /// Sellers present in the catalogue, derived from the products they carry
  /// (the backend has no seller-list endpoint). Every field is real: no invented
  /// rating, review count, delivery time or free-delivery threshold. A seller
  /// with no name on any of its products is skipped rather than shown as a
  /// `Seller #id` placeholder.
  List<Seller> sellersFrom(List<Product> products) {
    final grouped = <String, List<Product>>{};
    for (final p in products) {
      final sId = p.sellerId.trim();
      if (sId.isEmpty) continue;
      grouped.putIfAbsent(sId, () => []).add(p);
    }

    final sellers = <Seller>[];
    grouped.forEach((sId, items) {
      final name = items
          .map((p) => p.sellerName.trim())
          .firstWhere((n) => n.isNotEmpty, orElse: () => '');
      if (name.isEmpty) return; // no real name → do not surface a fake one

      final image = items
          .map((p) => p.sellerImageUrl.trim())
          .firstWhere((i) => i.isNotEmpty, orElse: () => items.first.imageUrl);

      // Average of the seller's actually-rated products; 0 when none are rated.
      final rated = items.where((p) => p.rating > 0).toList();
      final rating = rated.isEmpty
          ? 0.0
          : rated.map((p) => p.rating).reduce((a, b) => a + b) / rated.length;
      final ratingCount = items.fold<int>(0, (sum, p) => sum + p.ratingCount);

      // Real delivery estimate from the catalogue, or none.
      int? deliveryMinutes;
      for (final p in items) {
        if (p.deliveryMinutes != null) {
          deliveryMinutes = p.deliveryMinutes;
          break;
        }
      }

      sellers.add(Seller(
        id: sId,
        name: name,
        imageUrl: image,
        acceptingOrders: items.any((p) => p.sellerAcceptingOrders),
        deliveryMinutes: deliveryMinutes,
        productCount: items.length,
        rating: rating,
        ratingCount: ratingCount,
        products: items,
      ));
    });

    sellers.sort((a, b) => b.productCount.compareTo(a.productCount));
    return sellers;
  }

  /// Sub-categories for a category, derived from distinct brands within it.
  List<SubCategory> subCategoriesFrom(
    List<Product> products,
    String parentCategoryId,
  ) {
    final counts = <String, int>{};
    final images = <String, String>{};
    for (final p in products) {
      final key = p.brand.trim();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      images.putIfAbsent(key, () => p.imageUrl);
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      SubCategory(
        id: 'all',
        name: 'All',
        parentCategoryId: parentCategoryId,
        itemCount: products.length,
        imageUrl: products.isEmpty ? '' : products.first.imageUrl,
      ),
      ...entries.map(
        (e) => SubCategory(
          id: _slug(e.key),
          name: e.key,
          parentCategoryId: parentCategoryId,
          itemCount: e.value,
          imageUrl: images[e.key] ?? '',
        ),
      ),
    ];
  }

  List<Brand> brandsFrom(List<Product> products) {
    final counts = <String, int>{};
    final logos = <String, String>{};
    for (final p in products) {
      final key = p.brand.trim();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      logos.putIfAbsent(key, () => p.imageUrl);
    }

    final brands = counts.entries
        .map((e) => Brand(
              id: _slug(e.key),
              name: e.key,
              logoUrl: logos[e.key] ?? '',
              productCount: e.value,
            ))
        .toList()
      ..sort((a, b) => b.productCount.compareTo(a.productCount));
    return brands;
  }

  List<Product> inSubCategory(List<Product> products, SubCategory sub) {
    if (sub.id == 'all') return products;
    return products.where((p) => _slug(p.brand) == sub.id).toList();
  }

  /// Best sellers = highest rating volume, then rating. Used for rank badges.
  List<Product> bestSellers(List<Product> products, {int take = 10}) {
    final list = [...products]..sort((a, b) {
        final byCount = b.ratingCount.compareTo(a.ratingCount);
        return byCount != 0 ? byCount : b.rating.compareTo(a.rating);
      });
    return list.take(take).toList();
  }

  /// Flash sale = deepest discounts that are actually in stock.
  List<Product> flashSale(List<Product> products, {int take = 10}) {
    final list = products
        .where((p) => p.discountPercent >= 10 && p.isPurchasable)
        .toList()
      ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    return list.take(take).toList();
  }

  /// "Recommended for you" — a stable blend of well-rated and discounted items
  /// so the row does not reshuffle on every rebuild.
  List<Product> recommended(List<Product> products, {int take = 10}) {
    final list = [...products]..sort((a, b) {
        final aScore = a.rating * 10 + a.discountPercent;
        final bScore = b.rating * 10 + b.discountPercent;
        return bScore.compareTo(aScore);
      });
    return list.take(take).toList();
  }

  static String _slug(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}
