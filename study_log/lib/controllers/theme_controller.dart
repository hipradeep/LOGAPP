import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';

/// Persists the selected [ThemeMode] as a tiny JSON file alongside the other
/// local caches, so theme persistence needs no extra dependency.
class ThemePreferenceStore {
  static const String _fileName = 'study_theme_pref.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  Future<ThemeMode?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final name = decoded['mode']?.toString();
      for (final mode in ThemeMode.values) {
        if (mode.name == name) return mode;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(ThemeMode mode) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode({'mode': mode.name}));
    } catch (_) {
      // A failed preference write must never break the theme switch.
    }
  }
}

/// Owns the app theme mode and keeps [AppTheme.isDark] aligned with the
/// brightness actually in effect.
///
/// Registered above [MaterialApp] through `AppProvider`, so widgets read it with
/// `AppProvider.watch<ThemeController>(context)` to rebuild when it changes.
/// It also observes platform brightness, so system mode follows the device
/// without a restart.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController({ThemePreferenceStore? store})
      : _store = store ?? ThemePreferenceStore() {
    _applyBrightness();
    WidgetsBinding.instance.addObserver(this);
  }

  final ThemePreferenceStore _store;

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Brightness actually in effect, which differs from [themeMode] when the
  /// app is following the system setting.
  Brightness get effectiveBrightness => switch (_themeMode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
      };

  /// Mirrors [effectiveBrightness] into [AppTheme.isDark], which backs the
  /// text style getters that have no [BuildContext] to resolve against.
  /// Returns whether the flag changed.
  bool _applyBrightness() {
    final next = effectiveBrightness == Brightness.dark;
    if (AppTheme.isDark == next) return false;
    AppTheme.isDark = next;
    return true;
  }

  /// Reads the persisted preference. Call once before the first frame.
  Future<void> load() async {
    final stored = await _store.read();
    if (stored == null || stored == _themeMode) return;
    _themeMode = stored;
    _applyBrightness();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _applyBrightness();
    notifyListeners();
    await _store.write(mode);
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode != ThemeMode.system) return;
    if (_applyBrightness()) notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
