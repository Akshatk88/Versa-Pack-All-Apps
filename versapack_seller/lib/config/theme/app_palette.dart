import 'package:flutter/material.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';

/// Brightness-aware structural colours, so screens stop hardcoding light-only
/// values. Use these for the *structure* of a screen — page background, card
/// surfaces, body text, borders.
///
/// Deliberately does **not** cover accent chips (the amber/mint/rose/blue
/// badges) or the golden brand banner: those keep their light pastel treatment
/// in both themes and their own dark-on-colour text, so converting them would
/// make that text unreadable.
extension AppPalette on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  /// Scaffold background — the layer behind the cards.
  Color get pageBg =>
      _isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

  /// Card / sheet / app-bar background.
  Color get surface => _isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

  /// Slightly raised or inset fill (search fields, chips on a card).
  Color get surfaceVariant =>
      _isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight;

  /// Body and heading text on [surface] or [pageBg].
  Color get textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

  /// Supporting text, captions, metadata.
  Color get textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  /// Hairline dividers and card outlines.
  Color get borderColor => _isDark ? AppColors.borderDark : AppColors.border;
}
