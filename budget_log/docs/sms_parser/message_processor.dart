/// Utility class for cleaning and normalizing SMS strings into standard tokens.
class MessageProcessor {
  const MessageProcessor._();

  /// Determines if a string is a valid numeric value.
  static bool isNumber(dynamic val) {
    if (val == null) return false;
    return double.tryParse(val.toString()) != null;
  }

  /// Trims non-numeric prefix and suffix characters.
  static String trimLeadingAndTrailingChars(String str) {
    if (str.isEmpty) return str;
    final first = str[0];
    final last = str[str.length - 1];

    String finalStr = !isNumber(last) ? str.substring(0, str.length - 1) : str;
    finalStr = !isNumber(first) ? finalStr.substring(1) : finalStr;
    return finalStr;
  }

  /// Cleans and splits an SMS text into normalized lowercase tokens.
  static List<String> processMessage(String message) {
    String msg = message.toLowerCase();

    // Remove noise symbols
    msg = msg
        .replaceAll('!', '')
        .replaceAll(':', ' ')
        .replaceAll('/', '')
        .replaceAll('=', ' ')
        .replaceAll(RegExp(r'[{}]'), ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('ending ', '')
        .replaceAll(RegExp(r'x|[*]'), '')
        .replaceAll('is ', '')
        .replaceAll('with ', '')
        .replaceAll('no. ', '');

    // Standardize account triggers to 'ac'
    msg = msg.replaceAll(RegExp(r'\bac\b|\bacct\b|\baccount\b'), 'ac');

    // Standardize currency variants to 'rs.'
    msg = msg
        .replaceAll(RegExp(r'rs(?=\w)'), 'rs. ')
        .replaceAll('rs ', 'rs. ')
        .replaceAll(RegExp(r'inr(?=\w)'), 'rs. ')
        .replaceAll('inr ', 'rs. ')
        .replaceAll('rs. ', 'rs.')
        .replaceAll(RegExp(r'rs\.(?=\w)'), 'rs. ');

    // Separate transaction keywords
    msg = msg
        .replaceAll('debited', ' debited ')
        .replaceAll('credited', ' credited ');

    return msg.split(' ').where((str) => str.isNotEmpty).toList();
  }

  /// Formats currency to standard 2 decimal places.
  static String padCurrencyValue(String val) {
    final parts = val.split('.');
    final lhs = parts[0];
    final rhs = parts.length > 1 ? parts[1] : '';
    return '$lhs.${rhs.padRight(2, '0')}';
  }
}
