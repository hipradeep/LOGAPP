import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  File? _cacheFile;

  Future<File> get _file async {
    if (_cacheFile != null) return _cacheFile!;
    final directory = await getApplicationDocumentsDirectory();
    _cacheFile = File('${directory.path}/app_cache.json');
    return _cacheFile!;
  }

  Future<Map<String, dynamic>> _readCache() async {
    try {
      final file = await _file;
      if (!await file.exists()) {
        return {};
      }
      final contents = await file.readAsString();
      return jsonDecode(contents) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  Future<void> _writeCache(Map<String, dynamic> data) async {
    try {
      final file = await _file;
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      // Ignore write errors
    }
  }

  Future<void> saveSelectedTab(int index) async {
    final cache = await _readCache();
    cache['selected_management_tab'] = index;
    await _writeCache(cache);
  }

  Future<int> getSelectedTab() async {
    final cache = await _readCache();
    return cache['selected_management_tab'] as int? ?? 0;
  }

  Future<void> saveUserName(String name) async {
    final cache = await _readCache();
    cache['user_name'] = name;
    await _writeCache(cache);
  }

  Future<String> getUserName() async {
    final cache = await _readCache();
    return cache['user_name'] as String? ?? 'Log User';
  }

  Future<void> saveUserAvatar(String avatar) async {
    final cache = await _readCache();
    cache['user_avatar'] = avatar;
    await _writeCache(cache);
  }

  Future<String> getUserAvatar() async {
    final cache = await _readCache();
    return cache['user_avatar'] as String? ?? '🦁';
  }

  Future<void> saveDailyReminder(bool enabled) async {
    final cache = await _readCache();
    cache['daily_reminder'] = enabled;
    await _writeCache(cache);
  }

  Future<bool> getDailyReminder() async {
    final cache = await _readCache();
    return cache['daily_reminder'] as bool? ?? false;
  }

  Future<void> saveQuickActions(List<String> actions) async {
    final cache = await _readCache();
    cache['quick_actions'] = actions;
    await _writeCache(cache);
  }

  Future<List<String>> getQuickActions() async {
    final cache = await _readCache();
    final list = cache['quick_actions'] as List<dynamic>?;
    if (list != null) {
      return list.map((e) => e.toString()).toList();
    }
    return ['Focus 25m', 'Log Food', 'Water 250ml', 'New note'];
  }

  Future<void> clearAllCache() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> saveNotesGridView(bool isGrid) async {
    final cache = await _readCache();
    cache['notes_grid_view'] = isGrid;
    await _writeCache(cache);
  }

  Future<bool> getNotesGridView() async {
    final cache = await _readCache();
    return cache['notes_grid_view'] as bool? ?? true;
  }
}
