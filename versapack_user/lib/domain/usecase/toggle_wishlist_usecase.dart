import '../repository/wishlist_repository.dart';

/// Toggles a product's wishlist state and returns the new set of ids so the
/// caller can update every card showing that product at once.
class ToggleWishlistUseCase {
  const ToggleWishlistUseCase(this._repository);

  final WishlistRepository _repository;

  Future<Set<String>> call(Set<String> current, String productId) async {
    final isWishlisted = current.contains(productId);
    await _repository.toggle(productId, isWishlisted: isWishlisted);

    final next = {...current};
    if (isWishlisted) {
      next.remove(productId);
    } else {
      next.add(productId);
    }
    return next;
  }
}
