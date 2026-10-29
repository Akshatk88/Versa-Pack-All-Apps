import '../../core/network/api_client.dart';
import '../../domain/model/product.dart';
import '../../domain/repository/wishlist_repository.dart';
import '../dto/json_reader.dart';
import '../dto/product_dto.dart';
import '../mapper/product_mapper.dart';
import 'api_paths.dart';

class ApiWishlistRepository implements WishlistRepository {
  ApiWishlistRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Product>> list() async {
    final json = await _client.get(ApiPaths.favorites, requiresAuth: true);
    if (json is! Map<String, dynamic>) return const [];
    return ProductMapper.toDomainList(
      json.objects('foods').map(ProductDto.fromJson).toList(),
    );
  }

  @override
  Future<Set<String>> ids() async {
    final json = await _client.get(ApiPaths.favorites, requiresAuth: true);
    if (json is! Map<String, dynamic>) return const {};
    // `foodIds` is the complete list; `foods` omits unapproved items, so the
    // heart state must come from the ids array.
    return json.strings('foodIds').toSet();
  }

  @override
  Future<bool> toggle(String productId, {required bool isWishlisted}) async {
    final path = ApiPaths.favoriteFood(productId);
    final json = isWishlisted
        ? await _client.delete(path, requiresAuth: true)
        : await _client.post(path, requiresAuth: true);

    if (json is! Map<String, dynamic>) return !isWishlisted;
    return json.boolean('favorited', !isWishlisted);
  }
}
