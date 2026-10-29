import 'package:quick_commerce_seller/features/inventory/domain/product_model.dart';

abstract class InventoryRepository {
  Future<List<ProductModel>> getProducts();

  /// Uploads a product image and returns the stored URL. Products are created
  /// as JSON carrying URLs, so this runs before create/update.
  Future<String> uploadImage(String filePath);
  Future<List<CategoryModel>> getCategories();
  Future<void> toggleProductAvailability(String productId, bool isAvailable);
  /// Saves [product]. When [original] is supplied only the fields that
  /// actually changed are sent — the backend sends an item back for admin
  /// approval if a critical field is *present* in the body, so replaying
  /// unchanged values would re-review the item on every trivial edit.
  Future<void> updateProduct(ProductModel product, {ProductModel? original});
  Future<void> addProduct(ProductModel product);
  Future<void> deleteProduct(String productId);
  Future<void> addCategory(CategoryModel category);
  Future<void> toggleCategoryActive(String categoryId, bool isActive);
  Future<void> renameCategory(String categoryId, String name);
  Future<void> deleteCategory(String categoryId);
}
