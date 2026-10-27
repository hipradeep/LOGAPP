import 'package:intl/intl.dart';

class AppFormat {
  AppFormat._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final NumberFormat _currencyDecimal = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final DateFormat _shortDate = DateFormat('d MMM');
  static final DateFormat _mediumDate = DateFormat('d MMM yyyy');
  static final DateFormat _dateTime = DateFormat('d MMM, h:mm a');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');

  static String currency(num amount) => _currency.format(amount);

  static String currencyDecimal(num amount) => _currencyDecimal.format(amount);

  static String signedCurrency(num amount, {required bool isExpense}) {
    final prefix = isExpense ? '-' : '+';
    return '$prefix${_currency.format(amount.abs())}';
  }

  static String shortDate(DateTime date) => _shortDate.format(date);

  static String mediumDate(DateTime date) => _mediumDate.format(date);

  static String dateTime(DateTime date) => _dateTime.format(date);

  static String monthYear(DateTime date) => _monthYear.format(date);

  static String relativeDate(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final target = DateTime(date.year, date.month, date.day);
    final today = DateTime(current.year, current.month, current.day);
    final difference = today.difference(target).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference > 1 && difference < 7) return '$difference days ago';
    return mediumDate(date);
  }
}
