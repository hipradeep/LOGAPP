import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/reminder_item.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final StreamController<List<String>> _quickActionsController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get quickActionsStream => _quickActionsController.stream;

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
    _quickActionsController.add(actions);
  }

  Future<List<String>> getQuickActions() async {
    final cache = await _readCache();
    final list = cache['quick_actions'] as List<dynamic>?;
    if (list != null) {
      final actions = list.map((e) => e.toString()).toList();
      if (!actions.contains('Add transaction')) {
        actions.add('Add transaction');
        await saveQuickActions(actions);
      }
      return actions;
    }
    return ['Focus 25m', 'Water 250ml', 'New note', 'Add transaction'];
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

  Future<void> saveThemeMode(String mode) async {
    final cache = await _readCache();
    cache['theme_mode'] = mode;
    await _writeCache(cache);
  }

  Future<String?> getThemeMode() async {
    final cache = await _readCache();
    return cache['theme_mode'] as String?;
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

  Future<void> saveExpenseCategories(List<Map<String, dynamic>> categories) async {
    final cache = await _readCache();
    cache['expense_categories'] = categories;
    await _writeCache(cache);
  }

  Future<void> savePaymentModes(List<Map<String, dynamic>> modes) async {
    final cache = await _readCache();
    cache['payment_modes'] = modes;
    await _writeCache(cache);
  }

  Future<List<Map<String, dynamic>>> getPaymentModes() async {
    final cache = await _readCache();
    final list = cache['payment_modes'] as List<dynamic>?;
    if (list != null) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    final defaults = [
      {'label': 'Cash', 'icon': 'attach_money_rounded', 'color': 0xFF4CAF50, 'count': 0},
      {'label': 'PNB', 'icon': 'account_balance_rounded', 'color': 0xFF880E4F, 'count': 0},
      {'label': 'ICICI', 'icon': 'account_balance_rounded', 'color': 0xFFFF6D00, 'count': 0},
      {'label': 'SBI', 'icon': 'account_balance_rounded', 'color': 0xFF0288D1, 'count': 0},
      {'label': 'CBI', 'icon': 'account_balance_rounded', 'color': 0xFF00C853, 'count': 0},
      {'label': 'HDFC CC', 'icon': 'credit_card_rounded', 'color': 0xFF0D47A1, 'count': 0},
      {'label': 'AXIS CC', 'icon': 'credit_card_rounded', 'color': 0xFF800020, 'count': 0},
      {'label': 'IDFC CC', 'icon': 'credit_card_rounded', 'color': 0xFFD50000, 'count': 0},
      {'label': 'Wallet', 'icon': 'account_balance_wallet_rounded', 'color': 0xFF7C4DFF, 'count': 0},
      {'label': 'Net Banking', 'icon': 'language_rounded', 'color': 0xFF0097A7, 'count': 0},
    ];
    await savePaymentModes(defaults);
    return defaults;
  }

  Future<void> incrementPaymentModeCount(String label) async {
    final modes = await getPaymentModes();
    bool found = false;
    for (var m in modes) {
      if (m['label'].toString().toLowerCase() == label.toLowerCase()) {
        m['count'] = (m['count'] as int? ?? 0) + 1;
        found = true;
        break;
      }
    }
    if (!found) {
      modes.add({
        'label': label,
        'icon': 'payment_rounded',
        'color': 0xFF9E9E9E,
        'count': 1,
      });
    }
    await savePaymentModes(modes);
  }

  Future<List<Map<String, dynamic>>> getExpenseCategories() async {
    final cache = await _readCache();
    final list = cache['expense_categories'] as List<dynamic>?;
    if (list != null) {
      final categories = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final hasReceive = categories.any((cat) => cat['label'].toString().toLowerCase() == 'receive');
      if (hasReceive) {
        categories.removeWhere((cat) => cat['label'].toString().toLowerCase() == 'receive');
        await saveExpenseCategories(categories);
      }
      return categories;
    }
    final defaults = [
      {'label': 'Grocery', 'icon': 'local_grocery_store_rounded', 'color': 0xFF4CAF50, 'count': 0},
      {'label': 'Fast Food', 'icon': 'fastfood_rounded', 'color': 0xFFFF9800, 'count': 0},
      {'label': 'Supplements', 'icon': 'medication_rounded', 'color': 0xFF009688, 'count': 0},
      {'label': 'Travel', 'icon': 'flight_rounded', 'color': 0xFF3F51B5, 'count': 0},
      {'label': 'Care', 'icon': 'favorite_rounded', 'color': 0xFFFF4081, 'count': 0},
      {'label': 'Home', 'icon': 'home_rounded', 'color': 0xFF607D8B, 'count': 0},
      {'label': 'Bills', 'icon': 'receipt_long_rounded', 'color': 0xFFFF5252, 'count': 0},
      {'label': 'Timepass', 'icon': 'sports_esports_rounded', 'color': 0xFF9C27B0, 'count': 0},
      {'label': 'Transfer', 'icon': 'compare_arrows_rounded', 'color': 0xFF2196F3, 'count': 0},
      {'label': 'QuickMart', 'icon': 'storefront_rounded', 'color': 0xFF7C4DFF, 'count': 0},
      {'label': 'Shopping', 'icon': 'shopping_bag_rounded', 'color': 0xFFE91E63, 'count': 0},
      {'label': 'Other', 'icon': 'more_horiz_rounded', 'color': 0xFF9E9E9E, 'count': 0},
    ];
    await saveExpenseCategories(defaults);
    return defaults;
  }

  Future<void> incrementCategoryCount(String label) async {
    final categories = await getExpenseCategories();
    bool found = false;
    for (var cat in categories) {
      if (cat['label'].toString().toLowerCase() == label.toLowerCase()) {
        cat['count'] = (cat['count'] as int? ?? 0) + 1;
        found = true;
        break;
      }
    }
    // If it's a custom category not in default cache but passed anyway
    if (!found) {
      categories.add({
        'label': label,
        'icon': 'more_horiz_rounded',
        'color': 0xFF9E9E9E,
        'count': 1,
      });
    }
    await saveExpenseCategories(categories);
  }

  Future<void> saveReminders(List<ReminderItem> reminders) async {
    final cache = await _readCache();
    cache['reminders'] = reminders.map((r) => {
      'title': r.title,
      'time': r.time,
      'isActive': r.isActive,
    }).toList();
    await _writeCache(cache);
  }

  Future<List<ReminderItem>> getReminders() async {
    final cache = await _readCache();
    final list = cache['reminders'] as List<dynamic>?;
    if (list != null) {
      return list.map((e) {
        final map = e as Map<String, dynamic>;
        return ReminderItem(
          title: map['title'] as String? ?? '',
          time: map['time'] as String? ?? '',
          isActive: map['isActive'] as bool? ?? true,
        );
      }).toList();
    }
    return [
      ReminderItem(title: 'Drink water', time: '08:00 AM', isActive: true),
      ReminderItem(title: 'Gym session', time: '06:00 PM', isActive: false),
      ReminderItem(title: 'Take vitamins', time: '09:00 PM', isActive: true),
    ];
  }

  Future<void> saveScheduledActivityIds(List<String> ids) async {
    final cache = await _readCache();
    cache['scheduled_activity_ids'] = ids;
    await _writeCache(cache);
  }

  Future<List<String>> getScheduledActivityIds() async {
    final cache = await _readCache();
    final list = cache['scheduled_activity_ids'] as List<dynamic>?;
    if (list != null) {
      return list.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<void> saveSnoozedReminders(Map<String, String> snoozes) async {
    final cache = await _readCache();
    cache['snoozed_reminders'] = snoozes;
    await _writeCache(cache);
  }

  Future<Map<String, String>> getSnoozedReminders() async {
    final cache = await _readCache();
    final map = cache['snoozed_reminders'] as Map<dynamic, dynamic>?;
    if (map != null) {
      return map.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    return {};
  }

  /// Check if a notification action was already triggered within the last 3 seconds
  Future<bool> isDuplicateAction(int? notificationId, String actionId) async {
    if (notificationId == null) return false;
    final cache = await _readCache();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Purge action records older than 10 seconds to avoid cache bloat
    final Map<String, dynamic> cleanCache = {};
    cache.forEach((key, value) {
      if (key.startsWith('last_action_')) {
        if (value is int && now - value < 10000) {
          cleanCache[key] = value;
        }
      } else {
        cleanCache[key] = value;
      }
    });

    final uniqueKey = 'last_action_${notificationId}_$actionId';
    final lastProcessed = cleanCache[uniqueKey] as int? ?? 0;
    if (now - lastProcessed < 3000) {
      return true;
    }

    cleanCache[uniqueKey] = now;
    await _writeCache(cleanCache);
    return false;
  }

  Future<void> saveNotificationScannerEnabled(bool enabled) async {
    final cache = await _readCache();
    cache['notification_scanner_enabled'] = enabled;
    await _writeCache(cache);
  }

  Future<bool> getNotificationScannerEnabled() async {
    final cache = await _readCache();
    return cache['notification_scanner_enabled'] as bool? ?? true;
  }
}
