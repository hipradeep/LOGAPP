import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';

class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._internal();
  factory ThemeController() => instance;

  final PreferencesService _prefs = PreferencesService();
  AppThemeType _themeType = AppThemeType.dark;

  AppThemeType get themeType => _themeType;

  ThemeMode get themeMode {
    switch (_themeType) {
      case AppThemeType.light:
        return ThemeMode.light;
      case AppThemeType.dark:
      case AppThemeType.orix:
      case AppThemeType.logo:
      case AppThemeType.earth:
        return ThemeMode.dark;
      case AppThemeType.system:
        return ThemeMode.system;
    }
  }

  bool get isDark =>
      _themeType == AppThemeType.dark ||
      _themeType == AppThemeType.orix ||
      _themeType == AppThemeType.logo ||
      _themeType == AppThemeType.earth;

  ThemeController._internal() {
    _load();
  }

  Future<void> _load() async {
    final saved = await _prefs.getThemeMode();
    _themeType = _parse(saved);
    notifyListeners();
  }

  Future<void> setThemeType(AppThemeType type) async {
    if (_themeType == type) return;
    _themeType = type;
    await _prefs.saveThemeMode(_toString(type));
    notifyListeners();
  }

  AppThemeType _parse(String? value) {
    switch (value) {
      case 'light':
        return AppThemeType.light;
      case 'orix':
        return AppThemeType.orix;
      case 'logo':
        return AppThemeType.logo;
      case 'earth':
        return AppThemeType.earth;
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
      case AppThemeType.logo:
        return 'logo';
      case AppThemeType.earth:
        return 'earth';
      case AppThemeType.system:
        return 'system';
      case AppThemeType.dark:
        return 'dark';
    }
  }
}
