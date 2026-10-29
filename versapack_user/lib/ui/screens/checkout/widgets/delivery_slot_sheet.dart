import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/delivery_slot.dart';
import '../../../common/widgets/feedback/app_bottom_sheet.dart';

/// "As soon as possible" versus a scheduled window.
class DeliverySlotSheet extends StatelessWidget {
  const DeliverySlotSheet({super.key, required this.selected});

  final DeliverySlot selected;

  static Future<DeliverySlot?> show(
    BuildContext context, {
    required DeliverySlot selected,
  }) =>
      AppBottomSheet.show<DeliverySlot>(
        context,
        title: 'When should we deliver?',
        subtitle: 'We are fastest right now, but you can pick a window',
        child: DeliverySlotSheet(selected: selected),
      );

  @override
  Widget build(BuildContext context) {
    final slots = [DeliverySlot.asap, ...DeliverySlot.upcoming(DateTime.now())];

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewPaddingOf(context).bottom,
      ),
      itemCount: slots.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = slot.id == selected.id;

        return GestureDetector(
          onTap: () => Navigator.of(context).pop(slot),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colors.primary.withValues(alpha: 0.07)
                  : context.colors.surface,
              borderRadius: AppRadii.rMd,
              border: Border.all(
                color:
                    isSelected ? context.colors.primary : context.semantic.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  slot.isImmediate ? Icons.bolt_rounded : Icons.schedule_rounded,
                  size: 18,
                  color: slot.isImmediate
                      ? context.semantic.accent
                      : context.semantic.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot.label, style: context.text.titleMedium),
                      if (slot.isImmediate)
                        Text('Fastest option', style: context.text.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isSelected
                      ? context.colors.primary
                      : context.semantic.border,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
