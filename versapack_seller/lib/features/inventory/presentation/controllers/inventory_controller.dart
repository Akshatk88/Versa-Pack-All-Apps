import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/providers/repository_providers.dart';
import 'package:quick_commerce_seller/features/inventory/domain/inventory_repository.dart';
import 'package:quick_commerce_seller/features/inventory/domain/product_model.dart';

final inventoryControllerProvider =
    AsyncNotifierProvider<InventoryController, List<ProductModel>>(
      InventoryController.new,
    );

class InventoryController extends AsyncNotifier<List<ProductModel>> {
  late final InventoryRepository _repository;

  @override
  Future<List<ProductModel>> build() async {
    _repository = ref.watch(inventoryRepositoryProvider);
    return _repository.getProducts();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getProducts());
  }

  Future<void> toggleStock(String productId, bool isAvailable) async {
    final currentList = state.value ?? [];
    state = AsyncValue.data(
      currentList
          .map(
            (p) => p.id == productId ? p.copyWith(isAvailable: isAvailable) : p,
          )
          .toList(),
    );
    await _repository.toggleProductAvailability(productId, isAvailable);
  }

  Future<void> addProduct(ProductModel product) async {
    await _repository.addProduct(product);
    await refresh();
  }

  Future<void> updateProduct(
    ProductModel product, {
    ProductModel? original,
  }) async {
    await _repository.updateProduct(product, original: original);
    await refresh();
  }

  Future<void> deleteProduct(String productId) async {
    await _repository.deleteProduct(productId);
    await refresh();
  }
}

/// A single product, read from the live catalogue.
///
/// Deriving it from [inventoryControllerProvider] rather than fetching it
/// separately is what makes an edit show up everywhere at once: the detail
/// screen, the list and the dashboard all rebuild off the same refreshed data.
/// (The backend has no `GET /foods/:id`; the seller menu route is the source.)
final productByIdProvider = Provider.family<ProductModel?, String>((ref, id) {
  final products = ref.watch(inventoryControllerProvider).value;
  if (products == null) return null;
  for (final p in products) {
    if (p.id == id) return p;
  }
  return null;
});

final categoriesControllerProvider =
    AsyncNotifierProvider<CategoriesController, List<CategoryModel>>(
      CategoriesController.new,
    );

class CategoriesController extends AsyncNotifier<List<CategoryModel>> {
  late final InventoryRepository _repository;

  @override
  Future<List<CategoryModel>> build() async {
    _repository = ref.watch(inventoryRepositoryProvider);
    return _repository.getCategories();
  }

  /// Creates a category and returns it once the refreshed list contains it,
  /// so a caller can select it straight away.
  Future<CategoryModel?> addCategory(
    String name, {
    String foodTypeScope = 'Both',
  }) async {
    await _repository.addCategory(
      // The id is assigned by the server; this instance only carries the
      // fields the create endpoint reads.
      CategoryModel(
        id: '',
        name: name,
        itemCount: 0,
        foodTypeScope: foodTypeScope,
      ),
    );

    final refreshed = await _repository.getCategories();
    state = AsyncValue.data(refreshed);

    final wanted = name.trim().toLowerCase();
    for (final c in refreshed) {
      if (c.name.trim().toLowerCase() == wanted) return c;
    }
    return null;
  }

  Future<void> toggleActive(String categoryId, bool isActive) async {
    await _repository.toggleCategoryActive(categoryId, isActive);
    state = await AsyncValue.guard(() => _repository.getCategories());
  }

  Future<void> rename(String categoryId, String name) async {
    await _repository.renameCategory(categoryId, name);
    state = await AsyncValue.guard(() => _repository.getCategories());
  }

  Future<void> remove(String categoryId) async {
    await _repository.deleteCategory(categoryId);
    state = await AsyncValue.guard(() => _repository.getCategories());
  }
}
