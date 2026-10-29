import '../model/product.dart';

/// Backed by the backend's food favourites endpoints.
abstract interface class WishlistRepository {
  Future<List<Product>> list();

  Future<Set<String>> ids();

  Future<bool> toggle(String productId, {required bool isWishlisted});
}
