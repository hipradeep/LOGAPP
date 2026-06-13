import 'package:flutter/foundation.dart';
import '../models/reminder_item.dart';

class RemindersController extends ChangeNotifier {
  List<ReminderItem> _reminders = [
    ReminderItem(title: 'Drink water', time: '08:00 AM', isActive: true),
    ReminderItem(title: 'Gym session', time: '06:00 PM', isActive: false),
    ReminderItem(title: 'Take vitamins', time: '09:00 PM', isActive: true),
  ];

  bool _isLoading = false;
  String? _errorMessage;

  List<ReminderItem> get reminders => _reminders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    // Simulate network fetch
    await Future.delayed(const Duration(milliseconds: 600));
    _isLoading = false;
    notifyListeners();
  }

  void addReminder(ReminderItem item) {
    _reminders.add(item);
    notifyListeners();
  }

  void removeReminder(int index) {
    if (index >= 0 && index < _reminders.length) {
      _reminders.removeAt(index);
      notifyListeners();
    }
  }

  void toggleReminderActive(int index, bool val) {
    if (index >= 0 && index < _reminders.length) {
      _reminders[index].isActive = val;
      notifyListeners();
    }
  }
}
