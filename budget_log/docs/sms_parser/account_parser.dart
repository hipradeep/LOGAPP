import 'keywords.dart';
import 'message_processor.dart';
import 'models.dart';

/// Parsed account and payment mode metadata from SMS.
class AccountInfo {
  final AccountType? type;
  final String? number;
  final String? name;
  final CardType? cardType;
  final CardScheme? cardScheme;
  final String? bankName;

  const AccountInfo({
    this.type,
    this.number,
    this.name,
    this.cardType,
    this.cardScheme,
    this.bankName,
  });
}

/// Parser for account, card, wallet, and bank credentials.
class AccountParser {
  const AccountParser._();

  static AccountInfo parse(List<String> words, String rawMessage) {
    final lowerRaw = rawMessage.toLowerCase();

    // 1. Bank Name Detection
    String? bankName;
    for (final entry in SmsKeywords.bankNameMap.entries) {
      if (lowerRaw.contains(entry.key)) {
        bankName = entry.value;
        break;
      }
    }

    // 2. Card Detection
    final isCard = words.contains('card') || lowerRaw.contains('card');
    if (isCard) {
      CardType? cardType;
      for (final kw in SmsKeywords.creditCardKeywords) {
        if (lowerRaw.contains(kw)) {
          cardType = CardType.credit;
          break;
        }
      }
      if (cardType == null) {
        for (final kw in SmsKeywords.debitCardKeywords) {
          if (lowerRaw.contains(kw)) {
            cardType = CardType.debit;
            break;
          }
        }
      }

      CardScheme? cardScheme;
      for (final entry in SmsKeywords.cardSchemeKeywords.entries) {
        if (lowerRaw.contains(entry.key)) {
          cardScheme = entry.value;
          break;
        }
      }

      final cardIdx = words.indexOf('card');
      String? cardNumber;
      if (cardIdx != -1 && cardIdx + 1 < words.length) {
        final candidate = words[cardIdx + 1];
        if (MessageProcessor.isNumber(candidate)) {
          cardNumber = candidate;
        }
      }

      return AccountInfo(
        type: AccountType.card,
        number: cardNumber,
        cardType: cardType,
        cardScheme: cardScheme,
        bankName: bankName,
      );
    }

    // 3. Wallet Detection
    for (final wallet in SmsKeywords.wallets) {
      if (lowerRaw.contains(wallet)) {
        return AccountInfo(
          type: AccountType.wallet,
          name: wallet,
          bankName: bankName,
        );
      }
    }

    // 4. Bank Account Detection ('ac')
    final acIdx = words.indexOf('ac');
    String? acctNumber;
    if (acIdx != -1 && acIdx + 1 < words.length) {
      final candidate = words[acIdx + 1];
      if (MessageProcessor.isNumber(candidate)) {
        acctNumber = candidate;
      }
    }

    return AccountInfo(
      type: AccountType.account,
      number: acctNumber,
      bankName: bankName,
    );
  }
}
