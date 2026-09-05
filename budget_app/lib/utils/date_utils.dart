class AppDateUtils {
  AppDateUtils._();

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  static bool isDateInRange(DateTime date, DateTime? start, DateTime? end) {
    final d = startOfDay(date);
    if (start != null && d.isBefore(startOfDay(start))) return false;
    if (end != null && d.isAfter(startOfDay(end))) return false;
    return true;
  }

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime startOfWeek(DateTime date) {
    final d = startOfDay(date);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime startOfYear(DateTime date) => DateTime(date.year, 1, 1);
}
