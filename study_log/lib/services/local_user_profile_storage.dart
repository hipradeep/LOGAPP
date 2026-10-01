import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';

/// Local disk storage for [UserProfile] ensuring offline availability of profile details, streaks & study hours.
class LocalUserProfileStorage {
  static const String _fileName = 'user_profile_cache.json';

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('LocalUserProfileStorage getFile error: $e');
      return null;
    }
  }

  static Future<UserProfile?> loadProfile() async {
    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) {
        return null;
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final map = jsonDecode(content) as Map<String, dynamic>;
      return UserProfile.fromMap(map);
    } catch (e) {
      debugPrint('LocalUserProfileStorage loadProfile error: $e');
      return null;
    }
  }

  static Future<void> saveProfile(UserProfile profile) async {
    try {
      final file = await _getFile();
      if (file == null) return;
      final jsonString = jsonEncode(profile.toMap(forLocalJson: true));
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      debugPrint('LocalUserProfileStorage saveProfile error: $e');
    }
  }

  static Future<void> clear() async {
    try {
      final file = await _getFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('LocalUserProfileStorage clear error: $e');
    }
  }
}
