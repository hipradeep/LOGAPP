import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_settings.dart';
import '../services/local_notification_storage.dart';

/// Controller managing user notification preferences and schedules.
/// Adheres strictly to the ChangeNotifier pattern without external state dependencies.
class NotificationController extends ChangeNotifier {
  NotificationSettings _settings = const NotificationSettings();
  bool _isLoading = true;

  NotificationController() {
    _load();
  }

  NotificationSettings get settings => _settings;
  bool get isLoading => _isLoading;

  bool get enabled => _settings.enabled;
  bool get revisionDueEnabled => _settings.revisionDueEnabled;
  int get revisionIntervalHours => _settings.revisionIntervalHours;
  TimeOfDay get revisionDueTime => _settings.revisionDueTime;
  bool get courseDueEnabled => _settings.courseDueEnabled;
  TimeOfDay get courseDueTime => _settings.courseDueTime;
  bool get streakSaverEnabled => _settings.streakSaverEnabled;
  TimeOfDay get streakSaverTime => _settings.streakSaverTime;
  bool get deadlineEnabled => _settings.deadlineEnabled;
  int get deadlineDaysBefore => _settings.deadlineDaysBefore;

  Future<void> _load() async {
    _settings = await LocalNotificationStorage.loadSettings();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _update(NotificationSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    unawaited(LocalNotificationStorage.saveSettings(_settings));
  }

  Future<void> setMasterEnabled(bool value) async {
    if (_settings.enabled == value) return;
    await _update(_settings.copyWith(enabled: value));
  }

  Future<void> setRevisionDue(bool value) async {
    if (_settings.revisionDueEnabled == value) return;
    await _update(_settings.copyWith(revisionDueEnabled: value));
  }

  Future<void> setRevisionIntervalHours(int hours) async {
    if (_settings.revisionIntervalHours == hours) return;
    await _update(_settings.copyWith(revisionIntervalHours: hours));
  }

  Future<void> setRevisionDueTime(TimeOfDay time) async {
    if (_settings.revisionDueTime == time) return;
    await _update(_settings.copyWith(revisionDueTime: time));
  }

  Future<void> setCourseDue(bool value) async {
    if (_settings.courseDueEnabled == value) return;
    await _update(_settings.copyWith(courseDueEnabled: value));
  }

  Future<void> setCourseDueTime(TimeOfDay time) async {
    if (_settings.courseDueTime == time) return;
    await _update(_settings.copyWith(courseDueTime: time));
  }

  Future<void> setStreakSaver(bool value) async {
    if (_settings.streakSaverEnabled == value) return;
    await _update(_settings.copyWith(streakSaverEnabled: value));
  }

  Future<void> setStreakSaverTime(TimeOfDay time) async {
    if (_settings.streakSaverTime == time) return;
    await _update(_settings.copyWith(streakSaverTime: time));
  }

  Future<void> setDeadlineEnabled(bool value) async {
    if (_settings.deadlineEnabled == value) return;
    await _update(_settings.copyWith(deadlineEnabled: value));
  }

  Future<void> setDeadlineDaysBefore(int days) async {
    if (_settings.deadlineDaysBefore == days) return;
    await _update(_settings.copyWith(deadlineDaysBefore: days));
  }
}
