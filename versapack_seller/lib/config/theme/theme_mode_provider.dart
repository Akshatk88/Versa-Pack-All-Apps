import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode, persisted across restarts.
///
/// Not session-scoped: the seller's theme choice survives logout, so this is
/// deliberately absent from `resetSessionScopedProviders`.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String _key = 'app_theme_mode';

  @override
  ThemeMode build() {
    // The stored value arrives a frame or two later; starting light avoids a
    // flash of the wrong theme for the common case.
    _restore();
    return ThemeMode.light;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return;
    state = ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.light,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
