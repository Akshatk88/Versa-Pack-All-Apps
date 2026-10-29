import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/core/widgets/app_refresh_indicator.dart';

/// Renders an [AsyncValue]'s three states so screens don't each invent their
/// own. Never write `asyncValue.value ?? fallback` in a screen: against a real
/// API that shows an empty list while loading and — worse — shows the same
/// empty list forever when the request fails, with nothing for the seller to
/// tap and no indication anything went wrong.
///
/// [onRetry] is what the error state's button calls and what pull-to-refresh
/// triggers; `() => ref.invalidate(theProvider)` is the usual argument since
/// every controller here is an AsyncNotifier.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
    this.isEmpty,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.enableRefresh = true,
  });

  final AsyncValue<T> value;

  /// Re-runs the request. Wired to both the retry button and pull-to-refresh.
  final VoidCallback onRetry;

  final Widget Function(T data) builder;

  /// Optional: when this returns true for the loaded data, the empty state is
  /// shown instead of [builder]. Leave null for screens that render fine with
  /// no rows.
  final bool Function(T data)? isEmpty;

  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;

  /// Set false where the child is not a scrollable — RefreshIndicator needs
  /// one to attach to.
  final bool enableRefresh;

  @override
  Widget build(BuildContext context) {
    if (value.isLoading && !value.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(onRetry: onRetry),
      data: (data) {
        if (isEmpty?.call(data) ?? false) {
          return _EmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            message: emptyMessage,
          );
        }
        final child = builder(data);
        if (!enableRefresh) return child;
        return AppRefreshIndicator(
          onRefresh: () async => onRetry(),
          child: child,
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 12),
            Text(
              "Couldn't load this",
              textAlign: TextAlign.center,
              style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: AppColors.textSecondaryLight),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
