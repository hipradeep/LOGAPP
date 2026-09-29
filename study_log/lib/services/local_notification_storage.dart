import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/notification_settings.dart';

/// Local disk storage for [NotificationSettings] to guarantee persistent offline preferences.
class LocalNotificationStorage {
  static const String _fileName = 'study_notification_settings.json';

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('LocalNotificationStorage getFile error: $e');
      return null;
    }
  }

  static Future<NotificationSettings> loadSettings() async {
    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) {
        return const NotificationSettings();
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) return const NotificationSettings();
      final map = jsonDecode(content) as Map<String, dynamic>;
      return NotificationSettings.fromMap(map);
    } catch (e) {
      debugPrint('LocalNotificationStorage loadSettings error: $e');
      return const NotificationSettings();
    }
  }

  static Future<void> saveSettings(NotificationSettings settings) async {
    try {
      final file = await _getFile();
      if (file == null) return;
      final jsonString = jsonEncode(settings.toMap());
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      debugPrint('LocalNotificationStorage saveSettings error: $e');
    }
  }
}
