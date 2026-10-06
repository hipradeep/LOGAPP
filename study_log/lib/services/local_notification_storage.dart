import 'dart:async';
import '../models/notification_settings.dart';
import 'database_service.dart';

/// Local storage for [NotificationSettings] backed by SQLite [DatabaseService].
class LocalNotificationStorage {
  static Future<NotificationSettings> loadSettings() async {
    final settings = await DatabaseService.instance.getNotificationSettings();
    return settings ?? const NotificationSettings();
  }

  static Future<void> saveSettings(NotificationSettings settings) {
    return DatabaseService.instance.saveNotificationSettings(settings);
  }
}
