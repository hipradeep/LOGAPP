import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/sms_record.dart';
import '../models/staged_sms_transaction.dart';

import 'sms_parser/bank_sms_engine.dart';
import 'sms_parser/models.dart' as parser_models;

class SmsParserService {
  const SmsParserService();

  static final RegExp _currencyAmount = RegExp(
    r'(?:inr|rs\.?|₹)\s*([\d][\d,]*(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final RegExp _actionAmount = RegExp(
    r'(?:debited|credited|spent|paid|received|withdrawn|deposited|purchase)'
    r'\s+(?:by|with|for|of)?\s*(?:inr|rs\.?|₹)?\s*'
    r'([\d][\d,]*(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final RegExp _debitWord = RegExp(
    r'\b(?:debit(?:ed)?|spent|paid|withdrawn|purchase|sent)\b',
    caseSensitive: false,
  );
  static final RegExp _creditWord = RegExp(
    r'\b(?:credit(?:ed)?|received|deposited|refund(?:ed)?)\b',
    caseSensitive: false,
  );
  static final RegExp _merchantAt = RegExp(
    r'\bat\s+([A-Za-z0-9][A-Za-z0-9&._ -]{1,40}?)'
    r'(?=\s+(?:on|via|using|ref|for|by|to|from)\b|[.,]|$)',
    caseSensitive: false,
  );
  static final RegExp _merchantToFrom = RegExp(
    r'\b(?:to|from)\s+'
    r'(?!your\b|a/c\b|account\b|card\b)'
    r'([A-Za-z0-9][A-Za-z0-9&._ -]{1,40}?)'
    r'(?=\s+(?:on|via|using|ref|for|by|at)\b|[.,]|$)',
    caseSensitive: false,
  );
  static final RegExp _accountRef = RegExp(
    r'(?:a/c|ac|account|card)\s*(?:no\.?|number)?\s*[*xX]*\s*(\d{4})\b',
    caseSensitive: false,
  );
  static final RegExp _maskedAccountRef = RegExp(
    r'\b(?:xx|XX|\*{2,})\s*(\d{4})\b',
  );
  static final RegExp _endingAccountRef = RegExp(
    r'ending\s+(?:in|with)\s+(\d{4})\b',
    caseSensitive: false,
  );

  static const List<String> _blockedPhrases = [
    'otp',
    'one time password',
    'one-time password',
    'verification code',
    'do not share',
    'failed',
    'declined',
    'unsuccessful',
    'could not',
    'will be debited',
    'will get debited',
    'not a transaction',
  ];

  static const List<String> _bankSenderHints = [
    'hdfc',
    'sbi',
    'icici',
    'axis',
    'kotak',
    'idfc',
    'pnb',
    'bob',
    'canara',
    'union',
    'yes',
    'indusind',
    'federal',
    'rbl',
    'paytm',
    'phonepe',
    'gpay',
    'googlepay',
    'amazonpay',
    'airtel',
    'jio',
    'vi',
    'bandhan',
    'citi',
    'hsbc',
    'scb',
    'dbs',
    'bank',
  ];

  static const List<String> _bankContextHints = [
    'a/c',
    'ac no',
    'account',
    'card',
    'upi',
    'txn',
    'transaction',
    'ref no',
  ];

  StagedSmsTransaction? parse(SmsInboxRecord record, {DateTime? createdAt}) {
    final body = record.body.trim();
    if (body.isEmpty) return null;

    final lowerBody = body.toLowerCase();
    if (_blockedPhrases.any(lowerBody.contains)) return null;

    final sender = record.sender.trim();
    if (!_hasBankContext(sender, lowerBody)) return null;

    // First attempt parsing via BankSmsEngine (from sms_parser)
    final parsedEngine = BankSmsEngine.parse(body);
    if (parsedEngine != null && parsedEngine.amount > 0) {
      final typeStr = parsedEngine.type == parser_models.TransactionType.debit ? 'debit' : 'credit';
      final merchant = parsedEngine.merchant ?? _extractMerchant(body);
      final account = parsedEngine.account.number ?? _extractAccountRef(body);

      return StagedSmsTransaction(
        id: sourceKeyFor(record),
        smsSender: sender,
        rawBody: body,
        extractedAmount: parsedEngine.amount,
        extractedMerchant: merchant,
        extractedType: typeStr,
        accountRef: account,
        smsTimestamp: record.timestamp,
        createdAt: createdAt ?? DateTime.now(),
      );
    }

    final amount = _extractAmount(body);
    if (amount == null || amount <= 0) return null;

    final type = _extractType(lowerBody);
    if (type == null) return null;

    return StagedSmsTransaction(
      id: sourceKeyFor(record),
      smsSender: sender,
      rawBody: body,
      extractedAmount: amount,
      extractedMerchant: _extractMerchant(body),
      extractedType: type,
      accountRef: _extractAccountRef(body),
      smsTimestamp: record.timestamp,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  static String sourceKeyFor(SmsInboxRecord record) {
    final sender = record.sender.trim().toLowerCase();
    final body = record.body.trim();
    final input = '$sender|${record.timestamp.millisecondsSinceEpoch}|$body';
    final digest = sha1.convert(utf8.encode(input));
    return 'sms_$digest';
  }

  bool _hasBankContext(String sender, String lowerBody) {
    final lowerSender = sender.toLowerCase();
    final hasBankSender = _bankSenderHints.any(lowerSender.contains);
    final hasBankBody = _bankContextHints.any(lowerBody.contains);
    return hasBankSender || hasBankBody;
  }

  double? _extractAmount(String body) {
    final match =
        _currencyAmount.firstMatch(body) ?? _actionAmount.firstMatch(body);
    if (match == null) return null;
    final raw = match.group(1)?.replaceAll(',', '');
    if (raw == null || raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String? _extractType(String lowerBody) {
    final debit = _debitWord.firstMatch(lowerBody);
    final credit = _creditWord.firstMatch(lowerBody);
    if (debit == null && credit == null) return null;
    if (debit != null && credit != null) {
      return debit.start <= credit.start ? 'debit' : 'credit';
    }
    return debit != null ? 'debit' : 'credit';
  }

  String? _extractMerchant(String body) {
    final match =
        _merchantAt.firstMatch(body) ?? _merchantToFrom.firstMatch(body);
    if (match == null) return null;
    final value = match.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower.contains('a/c') ||
        lower.contains('account') ||
        lower.contains('card') ||
        lower.startsWith('your ') ||
        RegExp(r'^\d+$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  String? _extractAccountRef(String body) {
    final match =
        _accountRef.firstMatch(body) ??
        _maskedAccountRef.firstMatch(body) ??
        _endingAccountRef.firstMatch(body);
    return match?.group(1);
  }
}
