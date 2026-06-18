import 'package:flutter/foundation.dart';
import '../services/cache_service.dart';
import '../services/notification_service.dart';
import '../services/notification_transaction_service.dart';

class SettingsController extends ChangeNotifier {
  final CacheService _cacheService = CacheService();

  String _userName = 'Log User';
  String _userAvatar = '🦁';
  bool _dailyReminder = false;
  bool _notificationScannerEnabled = true;

  bool _isLoading = true;

  String get userName => _userName;
  String get userAvatar => _userAvatar;
  bool get dailyReminder => _dailyReminder;
  bool get notificationScannerEnabled => _notificationScannerEnabled;

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
      _notificationScannerEnabled = await _cacheService.getNotificationScannerEnabled();

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
    if (enabled) {
      await NotificationService.scheduleDailyNotification(
        id: 999,
        title: 'Daily Journal Reminder 📝',
        body: 'Time to record your daily thoughts and update your log!',
        timeString: '09:00 PM',
      );
    } else {
      await NotificationService.cancelNotification(999);
    }
    _dailyReminder = enabled;
    notifyListeners();
  }

  Future<void> toggleNotificationScanner(bool enabled) async {
    await _cacheService.saveNotificationScannerEnabled(enabled);
    _notificationScannerEnabled = enabled;
    if (enabled) {
      await NotificationTransactionService.startService();
    } else {
      await NotificationTransactionService.stopService();
    }
    notifyListeners();
  }



  Future<void> resetCache() async {
    _isLoading = true;
    notifyListeners();
    await _cacheService.clearAllCache();
    await _loadCacheSettings();
  }
}
