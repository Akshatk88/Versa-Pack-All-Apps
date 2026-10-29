import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/core/widgets/async_state_view.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/explore/domain/store_settings_model.dart';
import 'package:quick_commerce_seller/features/explore/presentation/controllers/explore_controller.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';

class OutletTimingsScreen extends ConsumerStatefulWidget {
  const OutletTimingsScreen({super.key});

  @override
  ConsumerState<OutletTimingsScreen> createState() =>
      _OutletTimingsScreenState();
}

class _OutletTimingsScreenState extends ConsumerState<OutletTimingsScreen> {
  List<DayTimingModel>? _localTimings;
  bool _saving = false;

  /// "HH:mm" → picker value. Anything unparseable falls back rather than
  /// throwing: the backend stores an empty string for a closed day.
  static TimeOfDay _parse(String value, TimeOfDay fallback) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (m == null) return fallback;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return fallback;
    return TimeOfDay(hour: h, minute: min);
  }

  /// Always zero-padded — the backend's parser only accepts `H:mm`/`HH:mm`
  /// and silently substitutes its own default for anything else.
  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// For display only. The stored value stays 24-hour.
  String _display(BuildContext context, String value) {
    final parsed = _parse(value, const TimeOfDay(hour: 0, minute: 0));
    return parsed.format(context);
  }

  static int _minutes(String value) {
    final t = _parse(value, const TimeOfDay(hour: 0, minute: 0));
    return t.hour * 60 + t.minute;
  }

  Future<void> _pickTime(int index, {required bool isOpening}) async {
    final day = _localTimings![index];
    final current = _parse(
      isOpening ? day.openTime : day.closeTime,
      isOpening
          ? const TimeOfDay(hour: 9, minute: 0)
          : const TimeOfDay(hour: 22, minute: 0),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: isOpening
          ? 'Opening time — ${day.dayName}'
          : 'Closing time — ${day.dayName}',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _localTimings![index] = isOpening
          ? day.copyWith(openTime: _format(picked))
          : day.copyWith(closeTime: _format(picked));
    });
  }

  /// The first day whose hours the backend would reject, or null.
  ///
  /// Mirrors `restaurant.service.js` exactly — it refuses a closing time equal
  /// to or earlier than the opening time, so overnight hours are not
  /// supported. Checking here means the seller is told which day is wrong
  /// instead of getting one opaque failure for the whole week.
  String? _firstInvalidDay(List<DayTimingModel> timings) {
    for (final day in timings) {
      if (!day.isOpen) continue;
      final open = _minutes(day.openTime);
      final close = _minutes(day.closeTime);
      if (close == open) {
        return '${day.dayName}: opening and closing time cannot be the same.';
      }
      if (close < open) {
        return '${day.dayName}: closing time must be after the opening time.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final timings = _localTimings;
    if (timings == null || _saving) return;

    final problem = _firstInvalidDay(timings);
    if (problem != null) {
      AppToast.showError(context, problem);
      return;
    }

    setState(() => _saving = true);
    // The previous version popped and claimed success without waiting, so a
    // rejected save looked identical to a stored one.
    final saved = await ref
        .read(outletTimingsProvider.notifier)
        .updateTimings(timings);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!saved) {
      AppToast.showError(context, 'Could not save your timings. Please retry.');
      return;
    }
    AppToast.show(context, 'Outlet timings saved.');
    context.pop();
  }

  /// A tappable time. Styled as a field rather than a bare label so it reads
  /// as editable — the previous screen showed the same numbers as plain text
  /// and nothing indicated they could be changed.
  Widget _timeField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.pageBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 16,
              color: context.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: context.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    _display(context, value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    final timingsAsync = ref.watch(outletTimingsProvider);

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.textPrimary,
            size: 18,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Operating Schedule',
          style: AppTextStyles.h3.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        // body is a Column, not a scrollable
        child: AsyncStateView<List<DayTimingModel>>(
          value: timingsAsync,
          onRetry: () => ref.invalidate(outletTimingsProvider),
          enableRefresh: false,
          builder: (serverTimings) {
            _localTimings ??= List.from(serverTimings);
            final timings = _localTimings!;
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: timings.length,
                    itemBuilder: (context, index) {
                      final day = timings[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: context.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    day.dayName,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  day.isOpen ? 'Open' : 'Closed',
                                  style: AppTextStyles.caption.copyWith(
                                    color: day.isOpen
                                        ? AppColors.textSecondaryLight
                                        : const Color(0xFFEF4444),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Switch(
                                  value: day.isOpen,
                                  activeTrackColor: const Color(0xFF22C55E),
                                  activeThumbColor: Colors.white,
                                  onChanged: (val) {
                                    setState(() {
                                      _localTimings![index] = day.copyWith(
                                        isOpen: val,
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                            // Hidden on a closed day: there are no hours to
                            // edit, and the backend clears them anyway.
                            if (day.isOpen) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _timeField(
                                      label: 'Opens',
                                      value: day.openTime,
                                      onTap: () =>
                                          _pickTime(index, isOpening: true),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _timeField(
                                      label: 'Closes',
                                      value: day.closeTime,
                                      onTap: () =>
                                          _pickTime(index, isOpening: false),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF181C2E),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _saving ? 'Saving…' : 'Save Timings Schedule',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
