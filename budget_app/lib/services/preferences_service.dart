import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  File? _cacheFile;

  Future<File> get _file async {
    if (_cacheFile != null) return _cacheFile!;
    final directory = await getApplicationDocumentsDirectory();
    _cacheFile = File('${directory.path}/budget_preferences.json');
    return _cacheFile!;
  }

  Future<Map<String, dynamic>> _readLocalCache() async {
    try {
      final file = await _file;
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeLocalCache(Map<String, dynamic> data) async {
    try {
      final file = await _file;
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  // === Theme Mode ===
  Future<void> saveThemeMode(String mode) async {
    final cache = await _readLocalCache();
    cache['theme_mode'] = mode;
    await _writeLocalCache(cache);
  }

  Future<String?> getThemeMode() async {
    final cache = await _readLocalCache();
    return cache['theme_mode'] as String?;
  }

  // === User Info ===
  Future<void> saveUserName(String name) async {
    final cache = await _readLocalCache();
    cache['user_name'] = name;
    await _writeLocalCache(cache);
  }

  Future<String> getUserName() async {
    final cache = await _readLocalCache();
    return cache['user_name'] as String? ?? 'Budget Master';
  }

  Future<void> saveUserAvatar(String avatar) async {
    final cache = await _readLocalCache();
    cache['user_avatar'] = avatar;
    await _writeLocalCache(cache);
  }

  Future<String> getUserAvatar() async {
    final cache = await _readLocalCache();
    return cache['user_avatar'] as String? ?? '💰';
  }

  // === Expense Categories ===
  static const List<Map<String, dynamic>> defaultExpenseCategories = [
    {'label': 'Grocery', 'icon': 'local_grocery_store_rounded', 'color': 0xFF4CAF50, 'count': 0},
    {'label': 'Fast Food', 'icon': 'fastfood_rounded', 'color': 0xFFFF9800, 'count': 0},
    {'label': 'Supplements', 'icon': 'medication_rounded', 'color': 0xFF009688, 'count': 0},
    {'label': 'Meals', 'icon': 'restaurant_rounded', 'color': 0xFFD84315, 'count': 0},
    {'label': 'Drinks', 'icon': 'local_bar_rounded', 'color': 0xFF00BCD4, 'count': 0},
    {'label': 'Travel', 'icon': 'flight_rounded', 'color': 0xFF3F51B5, 'count': 0},
    {'label': 'Care', 'icon': 'favorite_rounded', 'color': 0xFFFF4081, 'count': 0},
    {'label': 'Home', 'icon': 'home_rounded', 'color': 0xFF607D8B, 'count': 0},
    {'label': 'Bills', 'icon': 'receipt_long_rounded', 'color': 0xFFFF5252, 'count': 0},
    {'label': 'Timepass', 'icon': 'sports_esports_rounded', 'color': 0xFF9C27B0, 'count': 0},
  ];

  Future<List<Map<String, dynamic>>> getExpenseCategories() async {
    try {
      final doc = await _firestore.collection('metadata').doc('expense_categories').get();
      if (doc.exists && doc.data() != null) {
        final list = doc.data()!['categories'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          final res = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final cache = await _readLocalCache();
          cache['expense_categories'] = res;
          await _writeLocalCache(cache);
          return res;
        }
      }
    } catch (_) {}

    final cache = await _readLocalCache();
    final list = cache['expense_categories'] as List<dynamic>?;
    if (list != null && list.isNotEmpty) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return defaultExpenseCategories;
  }

  Future<void> saveExpenseCategories(List<Map<String, dynamic>> categories) async {
    final cache = await _readLocalCache();
    cache['expense_categories'] = categories;
    await _writeLocalCache(cache);
    try {
      await _firestore.collection('metadata').doc('expense_categories').set({
        'categories': categories,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // === Payment Modes ===
  static const List<Map<String, dynamic>> defaultPaymentModes = [
    {'label': 'Cash', 'icon': 'attach_money_rounded', 'color': 0xFF4CAF50, 'count': 0},
    {'label': 'UPI', 'icon': 'smartphone_rounded', 'color': 0xFF6200EA, 'count': 0},
    {'label': 'PNB', 'icon': 'account_balance_rounded', 'color': 0xFF880E4F, 'count': 0},
    {'label': 'SBI', 'icon': 'account_balance_rounded', 'color': 0xFF0288D1, 'count': 0},
    {'label': 'ICICI', 'icon': 'account_balance_rounded', 'color': 0xFFFF6D00, 'count': 0},
    {'label': 'HDFC CC', 'icon': 'credit_card_rounded', 'color': 0xFF0D47A1, 'count': 0},
    {'label': 'AXIS CC', 'icon': 'credit_card_rounded', 'color': 0xFF800020, 'count': 0},
    {'label': 'Wallet', 'icon': 'account_balance_wallet_rounded', 'color': 0xFF7C4DFF, 'count': 0},
    {'label': 'Net Banking', 'icon': 'language_rounded', 'color': 0xFF0097A7, 'count': 0},
  ];

  Future<List<Map<String, dynamic>>> getPaymentModes() async {
    try {
      final doc = await _firestore.collection('metadata').doc('payment_modes').get();
      if (doc.exists && doc.data() != null) {
        final list = doc.data()!['modes'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          final res = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final cache = await _readLocalCache();
          cache['payment_modes'] = res;
          await _writeLocalCache(cache);
          return res;
        }
      }
    } catch (_) {}

    final cache = await _readLocalCache();
    final list = cache['payment_modes'] as List<dynamic>?;
    if (list != null && list.isNotEmpty) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return defaultPaymentModes;
  }

  Future<void> savePaymentModes(List<Map<String, dynamic>> modes) async {
    final cache = await _readLocalCache();
    cache['payment_modes'] = modes;
    await _writeLocalCache(cache);
    try {
      await _firestore.collection('metadata').doc('payment_modes').set({
        'modes': modes,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // === Budget Categories ===
  static const List<String> defaultBudgetCategories = ['Expenses', 'Salary', 'Travel', 'Earning', 'Personal'];

  Future<List<String>> getBudgetCategories() async {
    try {
      final doc = await _firestore.collection('metadata').doc('budget_categories').get();
      if (doc.exists && doc.data() != null) {
        final list = doc.data()!['categories'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          return list.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}

    final cache = await _readLocalCache();
    final list = cache['budget_categories'] as List<dynamic>?;
    if (list != null && list.isNotEmpty) {
      return list.map((e) => e.toString()).toList();
    }
    return defaultBudgetCategories;
  }

  Future<void> saveBudgetCategories(List<String> categories) async {
    final cache = await _readLocalCache();
    cache['budget_categories'] = categories;
    await _writeLocalCache(cache);
    try {
      await _firestore.collection('metadata').doc('budget_categories').set({
        'categories': categories,
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
