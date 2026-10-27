import 'keywords.dart';
import 'message_processor.dart';
import 'models.dart';

/// Parser for transaction amount, currency, and direction (debit/credit).
class TransactionParser {
  const TransactionParser._();

  /// Extracts transaction amount from tokens following 'rs.'.
  static String? getTransactionAmount(List<String> words) {
    final index = words.indexOf('rs.');
    if (index == -1 || index + 1 >= words.length) return null;

    String money = words[index + 1].replaceAll(',', '');

    // Lookahead if the adjacent word is not numeric (e.g. 'rs. net 450')
    if (!MessageProcessor.isNumber(money)) {
      if (index + 2 >= words.length) return null;
      money = words[index + 2].replaceAll(',', '');
      if (!MessageProcessor.isNumber(money)) return null;
    }

    return MessageProcessor.padCurrencyValue(money);
  }

  /// Identifies whether the transaction is an expense (debit) or income (credit).
  static TransactionType? getTransactionType(List<String> words) {
    final messageStr = words.join(' ');

    final debitPattern = RegExp(
      r'(?:debited|debit|deducted|payment|spent|paid|used\s+at|charged|transaction\son|tran|booked|purchased|sent\s+to|purchase\s+of|transferred\sto)',
      caseSensitive: false,
    );
    final creditPattern = RegExp(
      r'(?:credited|credit|deposited|added|received|refund|repayment|cashback)',
      caseSensitive: false,
    );

    if (debitPattern.hasMatch(messageStr)) return TransactionType.debit;
    if (creditPattern.hasMatch(messageStr)) return TransactionType.credit;
    return null;
  }
}
