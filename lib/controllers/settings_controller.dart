import 'package:flutter/foundation.dart';
import '../services/cache_service.dart';

class SettingsController extends ChangeNotifier {
  final CacheService _cacheService = CacheService();

  String _userName = 'Log User';
  String _userAvatar = '🦁';
  bool _dailyReminder = false;
  bool _isLoading = true;

  String get userName => _userName;
  String get userAvatar => _userAvatar;
  bool get dailyReminder => _dailyReminder;
  bool get isLoading => _isLoading;

  SettingsController() {
    _loadCacheSettings();
  }

  Future<void> _loadCacheSettings() async {
    _isLoading = true;
    notifyListeners();
    try {
      _userName = await _cacheService.getUserName();
      _userAvatar = await _cacheService.getUserAvatar();
      _dailyReminder = await _cacheService.getDailyReminder();
    } catch (e) {
      // Quietly catch errors to avoid UI crashes
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(String name, String avatar) async {
    await _cacheService.saveUserName(name);
    await _cacheService.saveUserAvatar(avatar);
    _userName = name;
    _userAvatar = avatar;
    notifyListeners();
  }

  Future<void> toggleReminder(bool enabled) async {
    await _cacheService.saveDailyReminder(enabled);
    _dailyReminder = enabled;
    notifyListeners();
  }

  Future<void> resetCache() async {
    _isLoading = true;
    notifyListeners();
    await _cacheService.clearAllCache();
    await _loadCacheSettings();
  }
}
