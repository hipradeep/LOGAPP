import 'dart:math' as math;

import 'format_utils.dart';

class SubscriptionSchedule {
  SubscriptionSchedule._();

  static const List<String> frequencies = [
    'daily',
    'weekly',
    'monthly',
    'quarterly',
    'yearly',
  ];

  static String label(String frequency) {
    return switch (frequency) {
      'daily' => 'Daily',
      'weekly' => 'Weekly',
      'monthly' => 'Monthly',
      'quarterly' => 'Quarterly',
      'yearly' => 'Yearly',
      _ => 'Monthly',
    };
  }

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime nextDueDate(DateTime current, String frequency) {
    final date = startOfDay(current);
    return switch (frequency) {
      'daily' => DateTime(date.year, date.month, date.day + 1),
      'weekly' => DateTime(date.year, date.month, date.day + 7),
      'monthly' => _addMonthsClamped(date, 1),
      'quarterly' => _addMonthsClamped(date, 3),
      'yearly' => _addMonthsClamped(date, 12),
      _ => _addMonthsClamped(date, 1),
    };
  }

  static DateTime _addMonthsClamped(DateTime date, int months) {
    final currentLastDay = DateTime(date.year, date.month + 1, 0).day;
    final preserveEndOfMonth = date.day == currentLastDay;
    final targetMonth = DateTime(date.year, date.month + months, 1);
    final targetLastDay = DateTime(
      targetMonth.year,
      targetMonth.month + 1,
      0,
    ).day;
    final targetDay = preserveEndOfMonth
        ? targetLastDay
        : math.min(date.day, targetLastDay);
    return DateTime(targetMonth.year, targetMonth.month, targetDay);
  }

  static int daysUntil(DateTime dueDate, {DateTime? from}) {
    final due = startOfDay(dueDate);
    final current = startOfDay(from ?? DateTime.now());
    return DateTime.utc(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime.utc(current.year, current.month, current.day)).inDays;
  }

  static bool isOverdue(DateTime dueDate, {DateTime? now}) =>
      daysUntil(dueDate, from: now) < 0;

  static String dueLabel(DateTime dueDate, {DateTime? now}) {
    final days = daysUntil(dueDate, from: now);
    if (days < 0) {
      final count = days.abs();
      return 'Overdue by $count day${count == 1 ? '' : 's'}';
    }
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    if (days <= 7) return 'Due in $days days';
    return 'Due ${AppFormat.shortDate(dueDate)}';
  }
}
