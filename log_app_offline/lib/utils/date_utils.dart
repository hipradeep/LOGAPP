/// Shared date comparison helpers.
///
/// Replaces the duplicated `_isSameDay`, `_isToday`, `_isDateInRange`
/// methods previously scattered across:
///   - calendar_scheduler_controller.dart
///   - activity_notification_sync.dart
///   - check_in_service.dart
///   - activity_service.dart
class AppDateUtils {
  AppDateUtils._();

  /// Returns true if [a] and [b] fall on the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Returns true if [date] is today.
  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  /// Returns true if [date] falls within [start]..[end] inclusive.
  /// Null start/end means open-ended on that side.
  static bool isDateInRange(DateTime date, DateTime? start, DateTime? end) {
    final d = startOfDay(date);
    if (start != null && d.isBefore(startOfDay(start))) return false;
    if (end != null && d.isAfter(startOfDay(end))) return false;
    return true;
  }

  /// Strips time from [date] — returns midnight of the same day.
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Returns midnight of the Monday in the same week as [date].
  static DateTime startOfWeek(DateTime date) {
    final d = startOfDay(date);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// Returns midnight of the first day of [date]'s month.
  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  /// Returns midnight of the first day of [date]'s year.
  static DateTime startOfYear(DateTime date) => DateTime(date.year, 1, 1);
}
