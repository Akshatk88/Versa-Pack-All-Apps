import 'package:flutter/material.dart';

/// What the seller typed into [showCategoryFormDialog].
typedef CategoryDraft = ({String name, String foodTypeScope});

/// Collects the fields the backend needs to create a category.
///
/// Diet type is not optional decoration: `POST /food/restaurant/categories`
/// rejects a body without `foodTypeScope` ("Category diet type is required"),
/// so asking for it here is what makes the create succeed at all.
///
/// Shared by the categories screen and the product form so there is one
/// dialog to keep correct rather than two that drift.
Future<CategoryDraft?> showCategoryFormDialog(
  BuildContext context, {
  String title = 'Add Category',
  String confirmLabel = 'Add',
  String initialName = '',
  String initialScope = 'Both',
}) {
  return showDialog<CategoryDraft>(
    context: context,
    builder: (_) => _CategoryFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
      initialScope: initialScope,
    ),
  );
}

/// A StatefulWidget rather than a closure over a controller: the controller has
/// to outlive the dialog's exit animation. Disposing it from the caller (in a
/// `.then()` or `whenComplete`) runs while the TextField is still mounted and
/// trips `'_dependents.isEmpty': is not true`.
class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
    required this.initialScope,
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final String initialScope;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  late String _scope = widget.initialScope;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a category name');
      return;
    }
    Navigator.pop(context, (name: name, foodTypeScope: _scope));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Category name',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 18),
          const Text(
            'Diet type',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final option in const ['Veg', 'Non-Veg', 'Both'])
                ChoiceChip(
                  label: Text(option),
                  selected: _scope == option,
                  onSelected: (_) => setState(() => _scope = option),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
