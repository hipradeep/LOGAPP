import 'keywords.dart';
import 'message_processor.dart';
import 'models.dart';

/// Parser for available and outstanding account balances.
class BalanceParser {
  const BalanceParser._();

  /// Extracts account balance associated with trigger keywords without confusing with transaction amount.
  static String? getBalance(
    List<String> words, [
    BalanceKeywordType type = BalanceKeywordType.available,
  ]) {
    final msg = words.join(' ');
    final keywords = type == BalanceKeywordType.available
        ? SmsKeywords.availableBalanceKeywords
        : SmsKeywords.outstandingBalanceKeywords;

    for (final kw in keywords) {
      final idx = msg.indexOf(kw);
      if (idx != -1) {
        final sub = msg.substring(idx + kw.length).trim();
        final match = RegExp(
          r'(?:rs\.?|inr)?\s*([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?)',
        ).firstMatch(sub);

        if (match != null) {
          final raw = match.group(1)?.replaceAll(',', '');
          if (raw != null && MessageProcessor.isNumber(raw)) {
            return MessageProcessor.padCurrencyValue(raw);
          }
        }
      }
    }
    return null;
  }
}
