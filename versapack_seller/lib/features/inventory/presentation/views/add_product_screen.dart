import 'dart:io';
import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:quick_commerce_seller/config/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/core/network/api_exception.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/inventory/domain/product_model.dart';
import 'package:quick_commerce_seller/core/providers/repository_providers.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/controllers/inventory_controller.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/widgets/category_form_dialog.dart';
import 'package:quick_commerce_seller/features/notifications/presentation/controllers/notifications_controller.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key, this.productId});

  /// When set, the form edits that product instead of creating a new one.
  final String? productId;

  bool get isEditing => productId != null;

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  // The "Pricing & Stock" step the progress bar advertises never existed, so
  // products could only ever be created at price 0 with no stock.
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _mrpController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _packSizeController = TextEditingController();

  /// Local files chosen but not yet uploaded. Upload happens on save so a
  /// seller who abandons the form does not leave orphans on the server.
  final List<XFile> _pickedImages = [];
  String? _selectedCategory;

  /// The store's own categories. Previously a fixed list that had nothing to
  /// do with this seller, so a product could be filed under a category the
  /// backend would reject.
  /// The store's own categories, de-duplicated by name.
  ///
  /// Two categories can legitimately share a name (the platform seeds
  /// near-duplicates across zones, and a seller can create one that collides).
  /// A `DropdownButton` asserts when two items share a value, so the list is
  /// collapsed here rather than crashing the form.
  List<String> get _categories {
    final seen = <String>{};
    final names = <String>[];
    for (final c in ref.watch(categoriesControllerProvider).value ?? const []) {
      final name = c.name.trim();
      if (name.isEmpty) continue;
      if (seen.add(name.toLowerCase())) names.add(name);
    }
    return names;
  }

  /// True once the edit form has been populated, so a rebuild does not wipe
  /// what the seller has since typed.
  bool _prefilled = false;
  bool _isCreatingCategory = false;

  String _foodType = 'Veg';
  bool _isRecommended = false;
  bool _isAvailable = true;

  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _lowStockController = TextEditingController();
  final TextEditingController _maxQtyController = TextEditingController();
  final TextEditingController _prepTimeController = TextEditingController();

  /// Existing photos, by URL. Kept apart from [_pickedImages] because these are
  /// already on the server and must survive a save that adds no new files.
  final List<String> _existingImages = [];

  /// Sizes with their own prices. When non-empty the backend derives the
  /// headline price from these and rejects a base-price edit, so the base
  /// price field is hidden.
  final List<({TextEditingController name, TextEditingController price})>
  _variants = [];

  /// The product being edited, kept so its id and image survive a save.
  ProductModel? _editing;


  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    _packSizeController.dispose();
    _gstController.dispose();
    _lowStockController.dispose();
    _maxQtyController.dispose();
    _prepTimeController.dispose();
    for (final v in _variants) {
      v.name.dispose();
      v.price.dispose();
    }
    super.dispose();
  }

  /// Sentinel for the dropdown's "Add new category" row. Not a category name,
  /// so it can never collide with one.
  static const String _addCategorySentinel = '__add_category__';

  /// Creates a category from inside the product form and selects it.
  ///
  /// The seller's own categories come back from the list route straight away,
  /// even before an admin approves them, so the new one is selectable at once.
  Future<void> _createCategory() async {
    final draft = await showCategoryFormDialog(context);
    if (draft == null || !mounted) return;

    setState(() => _isCreatingCategory = true);
    try {
      final created = await ref
          .read(categoriesControllerProvider.notifier)
          .addCategory(draft.name, foodTypeScope: draft.foodTypeScope);
      if (!mounted) return;

      setState(() {
        _isCreatingCategory = false;
        // Select it only once it is really in the dropdown's own list —
        // holding a value with no matching item makes DropdownButton assert.
        final name = created?.name.trim();
        if (name != null && _categories.contains(name)) {
          _selectedCategory = name;
        }
      });

      AppToast.showSuccess(
        context,
        created == null
            ? '"${draft.name}" created'
            : '"${created.name}" created and selected',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreatingCategory = false);
      AppToast.showError(context, _messageFor(e));
    }
  }

  /// Whether this edit changes a field the backend re-reviews on.
  ///
  /// Mirrors `CRITICAL_APPROVAL_FIELDS` in `restaurantFood.service.js`, so the
  /// seller is only warned about re-approval when it will actually happen.
  bool _touchesApproval(ProductModel before, ProductModel after) {
    if (before.name != after.name) return true;
    if (before.description != after.description) return true;
    if (before.price != after.price) return true;
    if (before.foodType != after.foodType) return true;
    if (before.categoryName != after.categoryName) return true;
    if (before.preparationTime != after.preparationTime) return true;
    if (before.imageUrl != after.imageUrl) return true;
    if (before.images.length != after.images.length) return true;
    for (var i = 0; i < before.images.length; i++) {
      if (before.images[i] != after.images[i]) return true;
    }
    if (before.variants.length != after.variants.length) return true;
    for (var i = 0; i < before.variants.length; i++) {
      if (before.variants[i].name != after.variants[i].name) return true;
      if (before.variants[i].price != after.variants[i].price) return true;
    }
    return false;
  }

  /// Copies an existing product into the form's controllers.
  void _prefillFrom(ProductModel p) {
    _editing = p;
    _nameController.text = p.name;
    _descController.text = p.description;
    _priceController.text = p.price == 0 ? '' : p.price.toStringAsFixed(2);
    _mrpController.text = p.originalPrice == null
        ? ''
        : p.originalPrice!.toStringAsFixed(2);
    _stockController.text = '${p.stockQuantity}';
    _packSizeController.text = p.unit;
    _brandController.text = p.brand;
    _selectedCategory = p.categoryName.isEmpty ? null : p.categoryName;
    _foodType = p.foodType.toLowerCase() == 'non-veg' ? 'Non-Veg' : 'Veg';
    _isRecommended = p.isRecommended;
    _isAvailable = p.isAvailable;
    _gstController.text = p.gstRate == null
        ? ''
        : p.gstRate!.toStringAsFixed(p.gstRate! % 1 == 0 ? 0 : 2);
    _lowStockController.text = p.lowStockThreshold?.toString() ?? '';
    _maxQtyController.text = p.maxQtyPerOrder?.toString() ?? '';
    _prepTimeController.text = p.preparationTime;
    _existingImages
      ..clear()
      ..addAll(p.images);
    for (final v in p.variants) {
      _variants.add((
        name: TextEditingController(text: v.name),
        price: TextEditingController(text: v.price.toStringAsFixed(2)),
      ));
    }
  }

  /// A photo already stored on the server, with a control to drop it.
  Widget _buildExistingThumbnail(int index) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: AppConstants.resolveMediaUrl(_existingImages[index]),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: Color(0xFFFEF3C7)),
              errorWidget: (_, _, _) => const ColoredBox(
                color: Color(0xFFFEF3C7),
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 18,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: () =>
                  setState(() => _existingImages.removeAt(index)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Camera or gallery, then held locally until save.
  /// One picked image, with a remove control that actually removes it.
  Widget _buildPickedThumbnail(int index) {
    final file = _pickedImages[index];
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(file.path),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              // A picked file can vanish from the OS cache before it is read.
              errorBuilder: (_, _, _) => Container(
                width: 80,
                height: 80,
                color: const Color(0xFFFEF3C7),
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () => setState(() => _pickedImages.removeAt(index)),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFD9027),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Color(0xFF181C2E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProductImages() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picker = ImagePicker();
      // Downscaled on the way in: the upload endpoint rejects anything over
      // 5 MB, and a modern phone camera clears that on a single shot.
      if (source == ImageSource.gallery) {
        final files = await picker.pickMultiImage(
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
        if (files.isNotEmpty) setState(() => _pickedImages.addAll(files));
      } else {
        final file = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
        if (file != null) setState(() => _pickedImages.add(file));
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Could not open the picker: $e');
    }
  }

  /// Creates the product against `POST /food/restaurant/foods`.
  ///
  /// Picked images are uploaded first and the returned URLs go in the JSON
  /// body — the create endpoint takes URLs, not files.
  Future<void> _saveProduct() async {
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppToast.showError(context, 'Enter a product name');
      return;
    }
    if (name.length > 200) {
      AppToast.showError(context, 'Product name is too long');
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
      AppToast.showError(context, 'Pick a category');
      return;
    }

    // Variants own the price when there are any, so they are validated instead
    // of the base price — the backend rejects a base-price edit on such an item.
    final variants = <ProductVariant>[];
    for (final v in _variants) {
      final vName = v.name.text.trim();
      final vPrice = double.tryParse(v.price.text.trim());
      if (vName.isEmpty) {
        AppToast.showError(context, 'Give every variant a name');
        return;
      }
      if (vPrice == null || vPrice < 0) {
        AppToast.showError(context, 'Enter a valid price for "\$vName"');
        return;
      }
      variants.add(ProductVariant(name: vName, price: vPrice));
    }

    final mrpText = _mrpController.text.trim();
    final mrp = mrpText.isEmpty ? null : double.tryParse(mrpText);
    if (mrpText.isNotEmpty && mrp == null) {
      AppToast.showError(context, 'Enter a valid MRP');
      return;
    }

    final double price;
    if (variants.isEmpty) {
      final parsed = double.tryParse(_priceController.text.trim());
      if (parsed == null) {
        AppToast.showError(context, 'Enter a selling price');
        return;
      }
      if (parsed < 0) {
        AppToast.showError(context, 'Price cannot be negative');
        return;
      }
      price = parsed;
    } else {
      // Mirrors the backend: the headline price is the cheapest variant.
      price = variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
    }

    // The server refuses a selling price above MRP outright; catching it here
    // saves a round trip and names the field.
    if (mrp != null && mrp > 0 && price > mrp) {
      AppToast.showError(context, 'Selling price cannot be above the MRP');
      return;
    }

    final gstText = _gstController.text.trim();
    final gstRate = gstText.isEmpty ? null : double.tryParse(gstText);
    if (gstText.isNotEmpty &&
        (gstRate == null || gstRate < 0 || gstRate > 100)) {
      AppToast.showError(context, 'GST rate must be between 0 and 100');
      return;
    }

    final maxQtyText = _maxQtyController.text.trim();
    final maxQty = maxQtyText.isEmpty ? null : int.tryParse(maxQtyText);
    if (maxQtyText.isNotEmpty && (maxQty == null || maxQty < 1)) {
      AppToast.showError(context, 'Max per order must be at least 1');
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final repository = ref.read(inventoryRepositoryProvider);

      // Images upload first: the create endpoint takes JSON with URLs, not the
      // files themselves.
      final urls = <String>[];
      for (final file in _pickedImages) {
        urls.add(await repository.uploadImage(file.path));
      }

      final stockText = _stockController.text.trim();
      final edited = _editing;
      // Photos the seller kept, then anything newly picked.
      final images = [..._existingImages, ...urls];
      final lowStockText = _lowStockController.text.trim();
      final product = ProductModel(
        id: edited?.id ?? '',
        name: name,
        categoryId: edited?.categoryId ?? '',
        categoryName: _selectedCategory ?? '',
        price: price,
        originalPrice: mrp,
        unit: _packSizeController.text.trim(),
        isAvailable: widget.isEditing ? _isAvailable : true,
        stockQuantity: stockText.isEmpty ? 0 : int.tryParse(stockText) ?? 0,
        imageUrl: images.isEmpty ? null : images.first,
        images: images,
        description: _descController.text.trim(),
        brand: _brandController.text.trim(),
        foodType: _foodType,
        gstRate: gstRate,
        lowStockThreshold: lowStockText.isEmpty
            ? null
            : int.tryParse(lowStockText),
        maxQtyPerOrder: maxQty,
        preparationTime: _prepTimeController.text.trim(),
        isRecommended: _isRecommended,
        variants: variants,
      );

      final isEdit = edited != null;
      developer.log(
        '${isEdit ? 'PATCH' : 'POST'} /food/restaurant/foods '
        'name="$name" price=$price mrp=$mrp stock=$stockText '
        'images=${urls.length}',
        name: 'products',
      );

      final controller = ref.read(inventoryControllerProvider.notifier);
      if (isEdit) {
        await controller.updateProduct(product, original: edited);
      } else {
        await controller.addProduct(product);
      }
      developer.log('save OK — list refreshed', name: 'products');
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.showSuccess(
        context,
        isEdit
            ? (_touchesApproval(edited, product)
                  ? 'Product updated — it returns for admin approval'
                  : 'Product updated')
            // New items are created with approvalStatus 'pending', and the menu
            // endpoint only returns approved ones — so it will not show in the
            // list yet. Saying so beats the seller thinking the save failed.
            : 'Product submitted — it appears once an admin approves it',
      );
      context.pop();
    } catch (e) {
      developer.log('save FAILED: $e', name: 'products');
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.showError(context, _messageFor(e));
    }
  }

  String _messageFor(Object error) {
    if (error is DioException && error.error is ApiException) {
      return (error.error as ApiException).message;
    }
    if (error is ApiException) return error.message;
    return 'Could not save the product. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    // Edit mode fills the form from the catalogue the moment it arrives. Doing
    // it here rather than in initState is what makes it work on a cold open,
    // where the product list is still in flight when the screen mounts.
    if (widget.isEditing && !_prefilled) {
      final catalogue = ref.watch(inventoryControllerProvider).value;
      final existing = catalogue
          ?.where((p) => p.id == widget.productId)
          .firstOrNull;
      if (existing != null) {
        _prefillFrom(existing);
        _prefilled = true;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: Color(0xFF181C2E),
              size: 26,
            ),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Column(
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Inter',
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(
                    text: 'Versa',
                    style: TextStyle(color: Color(0xFF181C2E)),
                  ),
                  TextSpan(
                    text: 'pack',
                    style: TextStyle(color: Color(0xFF0F9D58)),
                  ),
                ],
              ),
            ),
            const Text(
              'Quick Seller',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF181C2E),
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
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF181C2E),
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Header with Back Arrow
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF181C2E),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isEditing
                                    ? 'Edit Product'
                                    : 'Add New Product',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF181C2E),
                                ),
                              ),
                              Text(
                                widget.isEditing
                                    ? 'Update this product'
                                    : 'Add a new product to your store',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 4 Step Progress Indicator
                    const SizedBox(height: 24),

                    // Basic Information Card Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 3.5,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFD9027),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Basic Information',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF181C2E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Product Name & Category
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Product Name'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _nameController,
                                      decoration: _buildInputDecoration(
                                        hintText: 'Enter product name',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _buildLabel('Category'),
                                        if (_isCreatingCategory) ...[
                                          const SizedBox(width: 8),
                                          const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFFD97706),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      initialValue: _selectedCategory,
                                      hint: const Text(
                                        'Select category',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Color(0xFF181C2E),
                                      ),
                                      decoration: _buildInputDecoration(),
                                      items: [
                                        ..._categories.map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(
                                              c,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Creating a category without leaving
                                        // the product being added.
                                        const DropdownMenuItem(
                                          value: _addCategorySentinel,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.add_rounded,
                                                size: 16,
                                                color: Color(0xFFD97706),
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Add new category',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFD97706),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val == _addCategorySentinel) {
                                          _createCategory();
                                          return;
                                        }
                                        setState(() => _selectedCategory = val);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Brand
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel(
                                      'Brand (Optional)',
                                      isRequired: false,
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _brandController,
                                      decoration: _buildInputDecoration(
                                        hintText: 'Enter brand name',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Product Description Textarea
                          _buildLabel('Product Description'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _descController,
                            maxLines: 4,
                            maxLength: 300,
                            decoration: _buildInputDecoration(
                              hintText: 'Describe your product...',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Product Type Section Card
Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Classification',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF181C2E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'How this item is listed to customers',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Food type'),
                          const SizedBox(height: 6),
                          // Veg / Non-Veg is a real backend enum and drives the
                          // marker customers filter on. The three "product
                          // type" cards that used to sit here mapped to nothing.
                          Row(
                            children: [
                              for (final type in const ['Veg', 'Non-Veg'])
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: type == 'Veg' ? 10 : 0,
                                    ),
                                    child: InkWell(
                                      onTap: () =>
                                          setState(() => _foodType = type),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _foodType == type
                                              ? const Color(0xFFFFFBEB)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: _foodType == type
                                                ? const Color(0xFFFD9027)
                                                : const Color(0xFFE5E7EB),
                                            width: _foodType == type ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: type == 'Veg'
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFFEF4444),
                                                  width: 1.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: type == 'Veg'
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFFEF4444),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                type,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF181C2E),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _isRecommended,
                            onChanged: (v) =>
                                setState(() => _isRecommended = v),
                            title: const Text(
                              'Recommended',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF181C2E),
                              ),
                            ),
                            subtitle: const Text(
                              'Highlight this item to customers',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          if (widget.isEditing)
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _isAvailable,
                              onChanged: (v) =>
                                  setState(() => _isAvailable = v),
                              title: const Text(
                                'Available',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF181C2E),
                                ),
                              ),
                              subtitle: const Text(
                                'Visible and orderable by customers',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Product Media Section Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Expanded(
                                child: Text(
                                  'Product Media',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF181C2E),
                                  ),
                                ),
                              ),
                              Text(
                                'Max 20 files',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Add images, videos or GIFs to showcase your product',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Media Thumbnails Horizontal Row
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                // The images the seller actually picked.
                                // These four slots used to be fixed decorative
                                // tiles, so a picked photo never appeared and
                                // the upload looked broken.
                                for (
                                  var k = 0;
                                  k < _pickedImages.length;
                                  k++
                                ) ...[
                                  _buildPickedThumbnail(k),
                                  const SizedBox(width: 10),
                                ],

                                // Add More Container (Dashed border button)
                                GestureDetector(
                                  onTap: _pickProductImages,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAFAFA),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFD1D5DB),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFFD9027),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.add_rounded,
                                                color: Color(0xFF181C2E),
                                                size: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            const Text(
                                              'Add More',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF181C2E),
                                              ),
                                            ),
                                            const Text(
                                              'Images / Videos / GIFs',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 7,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_pickedImages.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              '${_pickedImages.length} image'
                              '${_pickedImages.length == 1 ? '' : 's'} ready to upload',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),

                          // File Formats Hint
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                              children: [
                                TextSpan(text: 'You can add: '),
                                TextSpan(
                                  text:
                                      'JPG, PNG, WEBP (Images)  •  MP4, MOV (Videos)  •  GIF',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Existing photos, so an edit can drop one rather
                          // than only ever adding more.
                          if (_existingImages.isNotEmpty) ...[
                            _buildLabel('Current photos', isRequired: false),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 80,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _existingImages.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) =>
                                    _buildExistingThumbnail(i),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Pricing & Stock
                          if (_variants.isEmpty) ...[
                            _buildLabel('Selling Price (Rs)'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _buildInputDecoration(
                                hintText: '0.00',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            _buildLabel('Variant pricing', isRequired: false),
                            const SizedBox(height: 4),
                            const Text(
                              'This product is priced per variant. The '
                              'headline price comes from the cheapest one.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          for (var i = 0; i < _variants.length; i++) ...[
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _variants[i].name,
                                    decoration: _buildInputDecoration(
                                      hintText: 'Size, e.g. 1 kg',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _variants[i].price,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: _buildInputDecoration(
                                      hintText: 'Price',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove variant',
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Color(0xFFDC2626),
                                  ),
                                  onPressed: () => setState(() {
                                    final v = _variants.removeAt(i);
                                    v.name.dispose();
                                    v.price.dispose();
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(
                                () => _variants.add((
                                  name: TextEditingController(),
                                  price: TextEditingController(),
                                )),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add variant'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildLabel('MRP (Rs)', isRequired: false),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _mrpController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _buildInputDecoration(hintText: '0.00'),
                          ),
                          const SizedBox(height: 12),
                          _buildLabel('Stock Quantity', isRequired: false),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _buildInputDecoration(
                              hintText: 'Leave blank to keep untracked',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildLabel('Pack Size', isRequired: false),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _packSizeController,
                            decoration: _buildInputDecoration(
                              hintText: 'e.g. 500 g, pack of 6',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildLabel('Low stock alert at', isRequired: false),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _lowStockController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _buildInputDecoration(
                              hintText: 'Warn me below this count',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildLabel('Max per order', isRequired: false),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _maxQtyController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _buildInputDecoration(
                              hintText: 'Leave blank for no limit',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildLabel('GST rate (%)', isRequired: false),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _gstController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _buildInputDecoration(
                              hintText: '0 - 100',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildLabel('Preparation time', isRequired: false),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _prepTimeController,
                            decoration: _buildInputDecoration(
                              hintText: 'e.g. 10 mins',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Lightbulb Alert Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFEF08A),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFD9027),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: Color(0xFF181C2E),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Good images and videos help customers understand your product better',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF181C2E),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Use clear, well-lit photos from multiple angles.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF4B5563),
                                        ),
                                      ),
                                    ],
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

            // Bottom Sticky Action Buttons Row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        // Was "Save as Draft", which saved nothing — there is
                        // no draft state in the backend.
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF181C2E),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFD9027),
                          foregroundColor: const Color(0xFF181C2E),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Color(0xFF181C2E),
                                ),
                              )
                            : FittedBox(
                                child: Text(
                                  widget.isEditing
                                      ? 'Update Product'
                                      : 'Save Product',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF181C2E),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String labelText, {bool isRequired = true}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF181C2E),
        ),
        children: [
          TextSpan(text: labelText),
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFFD9027), width: 1.5),
      ),
    );
  }
}
