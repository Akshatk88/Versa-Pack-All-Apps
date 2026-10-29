import 'package:flutter/material.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';

/// All user feedback goes through here. Never call `ScaffoldMessenger`
/// directly — doing so produces a differently-shaped snackbar and the
/// inconsistency is immediately visible.
class AppToast {
  const AppToast._();

  static void showSuccess(BuildContext context, String message) => show(
    context,
    message,
    icon: Icons.check_circle,
    color: AppColors.success,
  );

  static void showError(BuildContext context, String message) =>
      show(context, message, icon: Icons.error_outline, color: AppColors.error);

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_outline,
    Color color = AppColors.primary,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          elevation: 2,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
