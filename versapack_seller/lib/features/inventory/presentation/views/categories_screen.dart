import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:dio/dio.dart';
import 'package:quick_commerce_seller/core/network/api_exception.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/controllers/inventory_controller.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/widgets/category_form_dialog.dart';
import 'package:quick_commerce_seller/features/notifications/presentation/controllers/notifications_controller.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Shared by the add and rename dialogs. Owned by the State so it outlives
  /// the dialog's exit animation — disposing it in `showDialog().then()` runs
  /// while the dialog's TextField is still mounted and throws.
  final TextEditingController _nameDialogController = TextEditingController();

  String _query = '';
  bool? _inactiveFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => setState(() => _query = _searchController.text.trim()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameDialogController.dispose();
    super.dispose();
  }

  /// The store's real categories, mapped into the shape this screen's cards
  /// were written against. Previously a hardcoded list whose add/rename/delete
  /// only ever mutated memory, so every change vanished on reload.
  List<Map<String, dynamic>> get _categoryList => [
    for (final c in ref.watch(categoriesControllerProvider).value ?? const [])
      {
        'id': c.id,
        'name': c.name,
        'count': '${c.itemCount} Product${c.itemCount == 1 ? '' : 's'}',
        'status': c.isActive ? 'Active' : 'Inactive',
        'isInactive': !c.isActive,
        'icon': Icons.category_rounded,
      },
  ];

  List<Map<String, dynamic>> get _visibleCategories {
    final query = _query.toLowerCase();
    return _categoryList.where((cat) {
      if (query.isNotEmpty &&
          !cat['name'].toString().toLowerCase().contains(query)) {
        return false;
      }
      if (_inactiveFilter != null && cat['isInactive'] != _inactiveFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _setActive(Map<String, dynamic> cat, bool active) async {
    try {
      await ref
          .read(categoriesControllerProvider.notifier)
          .toggleActive(cat['id'].toString(), active);
      if (!mounted) return;
      AppToast.show(
        context,
        '"${cat['name']}" is now ${active ? 'active' : 'inactive'}',
      );
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(context, 'Could not update "${cat['name']}".');
    }
  }

  void _showRenameDialog(Map<String, dynamic> cat) {
    _nameDialogController.text = cat['name'].toString();
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Rename category'),
        content: TextField(
          controller: _nameDialogController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Category name'),
          onSubmitted: (_) => Navigator.pop(dialogCtx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((confirmed) async {
      final name = _nameDialogController.text.trim();
      if (confirmed != true || name.isEmpty || !mounted) return;
      try {
        await ref
            .read(categoriesControllerProvider.notifier)
            .rename(cat['id'].toString(), name);
        if (!mounted) return;
        // Renaming an approved category sends it back for re-approval.
        AppToast.showSuccess(
          context,
          'Renamed to "$name" — it returns for admin approval',
        );
      } catch (_) {
        if (!mounted) return;
        AppToast.showError(context, 'Could not rename the category.');
      }
    });
  }

  void _confirmDelete(Map<String, dynamic> cat) {
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          '"${cat['name']}" holds ${cat['count']}. Deleting a category with '
          'products in it may need those products reassigned first.',
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
      if (confirmed != true || !mounted) return;
      final name = cat['name'].toString();
      try {
        await ref
            .read(categoriesControllerProvider.notifier)
            .remove(cat['id'].toString());
        if (!mounted) return;
        AppToast.show(context, '"$name" deleted');
      } catch (e) {
        if (!mounted) return;
        // The backend refuses to delete a category that still holds products;
        // its message says so far better than a generic failure would.
        AppToast.showError(context, _messageFor(e));
      }
    });
  }

  void _showCategoryActions(Map<String, dynamic> cat) {
    final isActive = cat['isInactive'] != true;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
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
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showRenameDialog(cat);
              },
            ),
            ListTile(
              leading: Icon(
                isActive
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              title: Text(isActive ? 'Mark inactive' : 'Mark active'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _setActive(cat, !isActive);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFDC2626)),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(cat);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openFilterSheet() {
    const options = <(String, bool?)>[
      ('All categories', null),
      ('Active only', false),
      ('Inactive only', true),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
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
            for (final (label, value) in options)
              ListTile(
                leading: Icon(
                  _inactiveFilter == value
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: _inactiveFilter == value
                      ? const Color(0xFFD97706)
                      : context.textSecondary,
                ),
                title: Text(label),
                onTap: () {
                  setState(() => _inactiveFilter = value);
                  Navigator.of(sheetContext).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
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
              // Screen Header Title & Add Category Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Categories',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Organize your products with categories',
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
                      onPressed: _showAddCategoryDialog,
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
                        'Add Category',
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

              // Top Sales Boost Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFEF08A)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFD9027),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.layers_rounded,
                        color: context.textPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Well organized categories boost your sales!',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage your categories to help customers find products easily.',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shopping_basket_rounded,
                        color: Color(0xFFD97706),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4 Metric Cards Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMetricCard(
                      icon: Icons.grid_view_rounded,
                      iconBg: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFFFBEB),
                      label: 'Total Categories',
                      count: '${_categoryList.length}',
                      subtitle: 'All Categories',
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      icon: Icons.check_rounded,
                      iconBg: const Color(0xFFA7F3D0),
                      iconColor: const Color(0xFF059669),
                      bgColor: const Color(0xFFECFDF5),
                      label: 'Active Categories',
                      count: '${_categoryList.where((c) => c['isInactive'] != true).length}',
                      subtitle: 'Visible to customers',
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      icon: Icons.visibility_off_outlined,
                      iconBg: const Color(0xFFFCA5A5),
                      iconColor: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEF2F2),
                      label: 'Inactive Categories',
                      count: '${_categoryList.where((c) => c['isInactive'] == true).length}',
                      subtitle: 'Hidden from store',
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      icon: Icons.inventory_2_outlined,
                      iconBg: const Color(0xFFDDD6FE),
                      iconColor: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFF5F3FF),
                      label: 'Total Products',
                      count: '128',
                      subtitle: 'Across categories',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search & Filter Row
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
                          hintText: 'Search categories...',
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
                    onTap: _openFilterSheet,
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
              const SizedBox(height: 16),

              // Categories List Card
              Container(
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: _visibleCategories.isEmpty
                    ? _buildEmptyState()
                    : Column(
                        children: List.generate(_visibleCategories.length, (
                          index,
                        ) {
                          final cat = _visibleCategories[index];
                          final isLast = index == _visibleCategories.length - 1;

                          return Column(
                            children: [
                              InkWell(
                                onTap: () => _showCategoryActions(cat),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          cat['icon'] as IconData,
                                          color: const Color(0xFFD97706),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cat['name'].toString(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: context.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              cat['count'].toString(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: context.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: (cat['isInactive'] as bool)
                                                ? const Color(0xFFFEF2F2)
                                                : const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            cat['status'].toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: (cat['isInactive'] as bool)
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFF059669),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Semantics(
                                        button: true,
                                        label: 'Rename ${cat['name']}',
                                        child: Tooltip(
                                          message: 'Rename',
                                          child: InkWell(
                                            onTap: () => _showRenameDialog(cat),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: context.pageBg,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: context.borderColor,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.edit_outlined,
                                                size: 16,
                                                color: context.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Semantics(
                                        button: true,
                                        label:
                                            'More actions for ${cat['name']}',
                                        child: InkWell(
                                          onTap: () =>
                                              _showCategoryActions(cat),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Container(
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.more_vert_rounded,
                                              color: context.textSecondary,
                                              size: 20,
                                            ),
                                          ),
                                        ),
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
                            'Create smart categories and increase product discovery.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Well categorized products sell more!',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.textSecondary,
                      size: 20,
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Icon(Icons.category_outlined, size: 40, color: context.textSecondary),
          const SizedBox(height: 12),
          Text(
            'No categories match',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _query.isNotEmpty
                ? 'Nothing matches "$_query".'
                : 'No categories in this filter yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _inactiveFilter = null);
            },
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final draft = await showCategoryFormDialog(context);
    if (draft == null || !mounted) return;

    try {
      await ref
          .read(categoriesControllerProvider.notifier)
          .addCategory(draft.name, foodTypeScope: draft.foodTypeScope);
      if (!mounted) return;
      // Own categories come back from the list route immediately, pending or
      // not — so it is visible here right away and only customers wait on the
      // admin.
      AppToast.showSuccess(
        context,
        '"${draft.name}" created — awaiting admin approval before customers '
        'see it',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, _messageFor(e));
    }
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

  /// The server's own wording when it has one — "category has products" is a
  /// far more actionable message than "something went wrong".
  String _messageFor(Object error) {
    if (error is DioException && error.error is ApiException) {
      return (error.error as ApiException).message;
    }
    return 'Something went wrong. Please try again.';
  }
}
