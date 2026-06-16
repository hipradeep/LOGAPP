import 'package:flutter/material.dart';
import '../services/cache_service.dart';

/// Manages the app-wide theme mode (dark / light).
/// Persists the user's choice via [CacheService] and notifies listeners
/// so [AppProvider<ThemeController>] can trigger a [MaterialApp] rebuild.
class ThemeController extends ChangeNotifier {
  final CacheService _cache = CacheService();
  ThemeMode _themeMode = ThemeMode.dark; // default: dark

  ThemeMode get themeMode => _themeMode;

  /// True when the current mode is [ThemeMode.dark].
  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeController() {
    _load();
  }

  Future<void> _load() async {
    final saved = await _cache.getThemeMode();
    _themeMode = _parse(saved);
    notifyListeners();
  }

  /// Persists and applies [mode] app-wide.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _cache.saveThemeMode(_toString(mode));
    notifyListeners();
  }

  ThemeMode _parse(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      default:
        return 'dark';
    }
  }
}
