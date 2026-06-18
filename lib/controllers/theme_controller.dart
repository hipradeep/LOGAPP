import 'package:flutter/material.dart';
import '../services/cache_service.dart';
import '../theme/app_theme.dart';

/// Manages the app-wide theme mode (dark / light / orix / system).
/// Persists the user's choice via [CacheService] and notifies listeners
/// so [AppProvider<ThemeController>] can trigger a [MaterialApp] rebuild.
class ThemeController extends ChangeNotifier {
  final CacheService _cache = CacheService();
  AppThemeType _themeType = AppThemeType.dark; // default: dark

  AppThemeType get themeType => _themeType;

  /// Compatibility getter for MaterialApp's themeMode config.
  ThemeMode get themeMode {
    switch (_themeType) {
      case AppThemeType.light:
        return ThemeMode.light;
      case AppThemeType.dark:
      case AppThemeType.orix:
        return ThemeMode.dark;
      case AppThemeType.system:
        return ThemeMode.system;
    }
  }

  /// True when the current mode is dark (Classic Dark or Orix Dark).
  bool get isDark => _themeType == AppThemeType.dark || _themeType == AppThemeType.orix;

  ThemeController() {
    _load();
  }

  Future<void> _load() async {
    final saved = await _cache.getThemeMode();
    _themeType = _parse(saved);
    notifyListeners();
  }

  /// Persists and applies [type] app-wide.
  Future<void> setThemeType(AppThemeType type) async {
    if (_themeType == type) return;
    _themeType = type;
    await _cache.saveThemeMode(_toString(type));
    notifyListeners();
  }

  // Support old API for backward compatibility
  Future<void> setThemeMode(ThemeMode mode) async {
    final type = _fromThemeMode(mode);
    await setThemeType(type);
  }

  AppThemeType _fromThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return AppThemeType.light;
      case ThemeMode.system:
        return AppThemeType.system;
      case ThemeMode.dark:
        return AppThemeType.dark;
    }
  }

  AppThemeType _parse(String? value) {
    switch (value) {
      case 'light':
        return AppThemeType.light;
      case 'orix':
        return AppThemeType.orix;
      case 'system':
        return AppThemeType.system;
      default:
        return AppThemeType.dark;
    }
  }

  String _toString(AppThemeType type) {
    switch (type) {
      case AppThemeType.light:
        return 'light';
      case AppThemeType.orix:
        return 'orix';
      case AppThemeType.system:
        return 'system';
      case AppThemeType.dark:
        return 'dark';
    }
  }
}
