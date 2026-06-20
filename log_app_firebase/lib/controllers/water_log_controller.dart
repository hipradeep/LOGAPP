import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/water_log_entry.dart';
import '../services/water_service.dart';
import '../services/notification_service.dart';
import '../services/service_locator.dart';

class WaterLogController extends ChangeNotifier {
  final WaterService _waterService = getIt<WaterService>();

  StreamSubscription<List<WaterLogEntry>>? _logsSub;
  StreamSubscription<WaterSettings>? _settingsSub;

  List<WaterLogEntry> _logs = [];
  WaterSettings _settings = WaterSettings();
  bool _isLoadingLogs = true;
  bool _isLoadingSettings = true;
  String? _errorMessage;

  // Getters
  List<WaterLogEntry> get logs => _logs;
  WaterSettings get settings => _settings;
  bool get isLoading => _isLoadingLogs || _isLoadingSettings;
  String? get errorMessage => _errorMessage;

  // Constructor
  WaterLogController() {
    _initStreams();
  }

  void _initStreams() {
    _isLoadingLogs = true;
    _isLoadingSettings = true;
    notifyListeners();

    // Subscribe to logs stream
    _logsSub = _waterService.getWaterLogsStream().listen(
      (logsData) {
        _logs = logsData;
        _isLoadingLogs = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoadingLogs = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );

    // Subscribe to settings stream
    _settingsSub = _waterService.getWaterSettingsStream().listen(
      (settingsData) {
        final oldSettings = _settings;
        _settings = settingsData;
        _isLoadingSettings = false;
        _errorMessage = null;
        
        // Sync system notifications if settings changed
        _syncNotifications(oldSettings, settingsData);
        notifyListeners();
      },
      onError: (error) {
        _isLoadingSettings = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _logsSub?.cancel();
    _settingsSub?.cancel();
    super.dispose();
  }

  // ==================== COMPUTED PROPERTIES ====================

  // Calculate today's total intake in ml
  double get todayTotal {
    final now = DateTime.now();
    double total = 0.0;
    for (final entry in _logs) {
      if (entry.timestamp.year == now.year &&
          entry.timestamp.month == now.month &&
          entry.timestamp.day == now.day) {
        total += entry.amount;
      }
    }
    return total;
  }

  // Calculate today's progress percentage (0.0 to 1.0)
  double get todayProgress {
    if (_settings.dailyGoal <= 0.0) return 0.0;
    final progress = todayTotal / _settings.dailyGoal;
    return progress.clamp(0.0, 1.0);
  }

  // Group logs by date for the History tab
  Map<String, List<WaterLogEntry>> get groupedLogs {
    final Map<String, List<WaterLogEntry>> grouped = {};
    for (final entry in _logs) {
      final label = _getFormattedDateLabel(entry.timestamp);
      if (!grouped.containsKey(label)) {
        grouped[label] = [];
      }
      grouped[label]!.add(entry);
    }
    return grouped;
  }

  // Daily totals map to check if goals were met on specific days
  Map<String, double> get dailyTotals {
    final Map<String, double> totals = {};
    for (final entry in _logs) {
      final key = DateFormat('yyyy-MM-dd').format(entry.timestamp);
      totals[key] = (totals[key] ?? 0.0) + entry.amount;
    }
    return totals;
  }

  String _getFormattedDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) return 'Today';
    if (entryDate == yesterday) return 'Yesterday';
    
    return DateFormat('MMMM d, yyyy').format(date);
  }

  // ==================== ACTIONS ====================

  Future<void> addIntake(double amount) async {
    try {
      await _waterService.addWaterLog(amount);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteIntake(String id) async {
    try {
      await _waterService.deleteWaterLog(id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteLastIntakeToday() async {
    try {
      final now = DateTime.now();
      final todayLogs = _logs.where((entry) =>
          entry.timestamp.year == now.year &&
          entry.timestamp.month == now.month &&
          entry.timestamp.day == now.day
      ).toList();

      if (todayLogs.isEmpty) return;

      todayLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      await deleteIntake(todayLogs.first.id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateGoal(double newGoal) async {
    try {
      final updated = _settings.copyWith(dailyGoal: newGoal);
      await _waterService.updateWaterSettings(updated);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleNotifications(bool enabled) async {
    try {
      final updated = _settings.copyWith(notificationsEnabled: enabled);
      await _waterService.updateWaterSettings(updated);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addReminderTime(String time) async {
    try {
      if (_settings.reminderTimes.contains(time)) return;
      final updatedTimes = List<String>.from(_settings.reminderTimes)..add(time);
      _sortTimes(updatedTimes);
      final updated = _settings.copyWith(
        reminderTimes: updatedTimes,
      );
      await _waterService.updateWaterSettings(updated);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeReminderTime(String time) async {
    try {
      final updatedTimes = List<String>.from(_settings.reminderTimes)..remove(time);
      final updated = _settings.copyWith(
        reminderTimes: updatedTimes,
      );
      await _waterService.updateWaterSettings(updated);
      // Cancel the specific notification immediately
      await NotificationService.cancelNotification(_getNotificationId(time));
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateHourlyInterval(int interval) async {
    try {
      final updated = _settings.copyWith(
        hourlyInterval: interval,
      );
      await _waterService.updateWaterSettings(updated);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void _sortTimes(List<String> timesList) {
    timesList.sort((a, b) {
      final timeA = NotificationService.parseTimeString(a);
      final timeB = NotificationService.parseTimeString(b);
      return timeA.hour == timeB.hour
          ? timeA.minute.compareTo(timeB.minute)
          : timeA.hour.compareTo(timeB.hour);
    });
  }

  // ==================== NOTIFICATION UTILITIES ====================

  int _getNotificationId(String timeString) {
    return 'water_reminder_$timeString'.hashCode.toSigned(31);
  }

  void _syncNotifications(WaterSettings oldSettings, WaterSettings newSettings) {
    // 1. Calculate old active times
    final List<String> oldTimes = List<String>.from(oldSettings.reminderTimes);
    if (oldSettings.hourlyInterval > 0) {
      final startHour = 8;
      final endHour = 20;
      for (int hour = startHour; hour <= endHour; hour += oldSettings.hourlyInterval) {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, hour, 0);
        final formatted = DateFormat.jm().format(dt);
        if (!oldTimes.contains(formatted)) {
          oldTimes.add(formatted);
        }
      }
    }

    // 2. Calculate new active times
    final List<String> newTimes = List<String>.from(newSettings.reminderTimes);
    if (newSettings.hourlyInterval > 0) {
      final startHour = 8;
      final endHour = 20;
      for (int hour = startHour; hour <= endHour; hour += newSettings.hourlyInterval) {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, hour, 0);
        final formatted = DateFormat.jm().format(dt);
        if (!newTimes.contains(formatted)) {
          newTimes.add(formatted);
        }
      }
    }

    // 3. Cancel notifications for any times that are no longer active
    for (final time in oldTimes) {
      if (!newTimes.contains(time)) {
        NotificationService.cancelNotification(_getNotificationId(time));
      }
    }

    // 4. If notifications are disabled globally, cancel all active times
    if (!newSettings.notificationsEnabled) {
      for (final time in newTimes) {
        NotificationService.cancelNotification(_getNotificationId(time));
      }
      return;
    }

    // 5. Schedule all active reminder times
    for (final time in newTimes) {
      NotificationService.scheduleDailyNotification(
        id: _getNotificationId(time),
        title: 'Drink Water Reminder 💧',
        body: 'Time to drink some water and stay hydrated!',
        timeString: time,
      );
    }
  }
}
