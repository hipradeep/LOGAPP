import 'account_parser.dart';
import 'balance_parser.dart';
import 'merchant_parser.dart';
import 'message_processor.dart';
import 'models.dart';
import 'transaction_parser.dart';

/// Complete parsed result representing a financial bank transaction from SMS.
class ParsedBankSms {
  final double amount;
  final TransactionType type;
  final AccountInfo account;
  final String? merchant;
  final String? referenceNo;
  final double? availableBalance;
  final double? outstandingBalance;
  final String rawMessage;

  const ParsedBankSms({
    required this.amount,
    required this.type,
    required this.account,
    this.merchant,
    this.referenceNo,
    this.availableBalance,
    this.outstandingBalance,
    required this.rawMessage,
  });
}

/// Orchestration engine coordinating tokenization, validation, and multi-field extraction.
class BankSmsEngine {
  const BankSmsEngine._();

  /// Parses an incoming SMS text into a structured financial transaction.
  /// Returns `null` if the message is an OTP, promotional alert, or missing critical transaction details.
  static ParsedBankSms? parse(String rawMessage) {
    if (rawMessage.trim().isEmpty) return null;

    final words = MessageProcessor.processMessage(rawMessage);
    final amountStr = TransactionParser.getTransactionAmount(words);
    final type = TransactionParser.getTransactionType(words);

    // Critical checkpoint 1: Must contain an amount and debit/credit action
    if (amountStr == null || type == null) return null;

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;

    final account = AccountParser.parse(words, rawMessage);
    final availBalStr = BalanceParser.getBalance(
      words,
      BalanceKeywordType.available,
    );
    final outBalStr = account.type == AccountType.card
        ? BalanceParser.getBalance(words, BalanceKeywordType.outstanding)
        : null;

    // Critical checkpoint 2: Require at least 2 distinct transaction signals to filter out spam
    final signalsCount = [
      availBalStr ?? '',
      amountStr,
      account.number ?? '',
      account.bankName ?? '',
    ].where((s) => s.isNotEmpty).length;

    if (signalsCount < 2) return null;

    final merchantInfo = MerchantParser.extract(rawMessage, words);

    return ParsedBankSms(
      amount: amount,
      type: type,
      account: account,
      merchant: merchantInfo.merchant,
      referenceNo: merchantInfo.referenceNo,
      availableBalance: double.tryParse(availBalStr ?? ''),
      outstandingBalance: double.tryParse(outBalStr ?? ''),
      rawMessage: rawMessage,
    );
  }
}
