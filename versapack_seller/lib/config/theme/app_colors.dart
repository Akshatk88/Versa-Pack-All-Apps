import 'package:flutter/material.dart';

/// The only source of colour in the app. Never hardcode a `Color` outside this
/// class or the `ThemeData` built from it.
class AppColors {
  const AppColors._();

  // Brand (Versapack Orange)
  static const Color primary = Color(0xFFFD9027);
  static const Color primaryLight = Color(0xFFFDB673);
  static const Color primaryDark = Color(0xFFD77A21);

  // Dark palette
  static const Color backgroundDark = Color(0xFF121223);
  static const Color surfaceDark = Color(0xFF1E1E2E);
  static const Color surfaceVariantDark = Color(0xFF2A2A3C);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFA0A0B2);

  // Light palette
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF3F4F6);
  static const Color textPrimaryLight = Color(0xFF181C2E);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // Status & Badges
  static const Color success = Color(0xFF2FB457);
  static const Color successBg = Color(0xFFE6F4EA);
  static const Color successText = Color(0xFF1E8E3E);

  static const Color warning = Color(0xFFF59E0B);
  static const Color pendingBg = Color(0xFFFFF8E7);
  static const Color pendingText = Color(0xFFD97706);

  static const Color error = Color(0xFFE04444);
  static const Color errorBg = Color(0xFFFCE8E6);
  static const Color errorText = Color(0xFFD93025);

  static const Color rating = Color(0xFFFFC529);

  static const Color border = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF32324A);
}
