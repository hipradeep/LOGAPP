import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ThemePreferenceStore {
  static const String _fileName = 'budget_theme_pref.json';

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
    } catch (_) {}
  }
}

class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController({ThemePreferenceStore? store})
    : _store = store ?? ThemePreferenceStore() {
    WidgetsBinding.instance.addObserver(this);
  }

  final ThemePreferenceStore _store;

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Brightness get effectiveBrightness => switch (_themeMode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
  };

  Future<void> load() async {
    final stored = await _store.read();
    if (stored == null || stored == _themeMode) return;
    _themeMode = stored;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _store.write(mode);
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
