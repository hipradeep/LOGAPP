import 'dart:async';
import '../models/user_profile.dart';
import 'database_service.dart';

/// Local storage for [UserProfile] backed by SQLite [DatabaseService].
class LocalUserProfileStorage {
  static Future<UserProfile?> loadProfile() {
    return DatabaseService.instance.getUserProfile();
  }

  static Future<void> saveProfile(UserProfile profile) {
    return DatabaseService.instance.saveUserProfile(profile);
  }

  static Future<void> clear() {
    return DatabaseService.instance.clearUserProfile();
  }
}
