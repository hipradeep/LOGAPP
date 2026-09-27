import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Controller managing the application theme.
/// Locked to the minimalist monochrome palette by default (as per the design image),
/// with built-in architecture to seamlessly support future theme upgrades without refactoring.
class ThemeController extends ChangeNotifier {
  AppThemeType _themeType = AppThemeType.studyMinimalist;

  AppThemeType get themeType => _themeType;

  bool get isDark => _themeType != AppThemeType.studyMinimalist;

  /// Hook for future upgrades if additional themes are unlocked.
  void upgradeTheme(AppThemeType newTheme) {
    if (_themeType == newTheme) return;
    _themeType = newTheme;
    notifyListeners();
  }
}
