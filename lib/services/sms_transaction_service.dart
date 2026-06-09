import 'dart:developer' as developer;
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import '../models/sms_transaction.dart';
import '../models/budget_item.dart';
import 'budget_service.dart';

class SmsTransactionService {
  final BudgetService _budgetService = BudgetService();

  static const _tagKeywords = {
    'Bill': ['bill', 'recharge', 'electricity', 'water', 'internet', 'dth', 'mobile recharge', 'broadband'],
    'Dinner': ['restaurant', 'cafe', 'dinner', 'lunch', 'food', 'zomato', 'swiggy', 'eat', 'pizza', 'burger'],
    'Drink': ['drink', 'bar', 'beer', 'wine', 'coffee', 'tea', 'chai', 'starbucks'],
    'Fuel': ['fuel', 'petrol', 'diesel', 'gas', 'indian oil', 'hpcl', 'bpcl', 'shell'],
    'Grocery': ['grocery', 'supermarket', 'dmart', 'bigbasket', 'reliance fresh', 'zepto', 'blinkit', 'instamart'],
    'Shopping': ['amazon', 'flipkart', 'myntra', 'shopping', 'meesho', 'ajio', 'nykaa', 'purchase'],
    'Health': ['medical', 'hospital', 'pharmacy', 'doctor', 'medicine', 'apollo', 'health', 'clinic'],
    'Snack': ['snack', 'fast food', 'mcdonald', 'kfc', 'domino', 'subway', 'chaat'],
    'Travel': ['flight', 'travel', 'train', 'uber', 'ola', 'rapido', 'bus', 'metro', 'cab', 'irctc', 'make my trip'],
  };

  static const _bankSenders = [
    'HDFC', 'ICICI', 'SBI', 'AXIS', 'KOTAK', 'YES', 'INDUS',
    'PNB', 'BOB', 'CANARA', 'IDBI', 'FEDERAL', 'HSBC',
    'UPI', 'PAYTM', 'PHONEPE', 'GOOGLE', 'AMAZONPAY',
    'RBL', 'AU SMALL', 'BANDHAN', 'CSB', 'J&K', 'KARNATAKA',
    'SARASWAT', 'SOUTH INDIAN', 'TJSB', 'TMB',
    'VIJAYA', 'DBS', 'DCB',
  ];

  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<List<SmsMessage>> fetchSmsLast7Days() async {
    final telephony = Telephony.instance;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    developer.log('Fetching SMS from ${sevenDaysAgo.toLocal()} to ${now.toLocal()}',
        name: 'SmsTransactionService');

    final allMessages = await telephony.getInboxSms(
      filter: SmsFilter
          .where(SmsColumn.DATE)
          .greaterThanOrEqualTo(sevenDaysAgo.millisecondsSinceEpoch.toString()),
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    developer.log('Total SMS fetched: ${allMessages.length}', name: 'SmsTransactionService');

    for (final msg in allMessages) {
      final date = DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0).toLocal();
      developer.log(
        'RAW SMS | From: ${msg.address} | Date: $date | Body: ${msg.body}',
        name: 'SmsTransactionService',
      );
    }

    return allMessages;
  }

  List<SmsMessage> filterFinancialSms(List<SmsMessage> messages) {
    return messages.where((msg) {
      final body = (msg.body ?? '').toLowerCase();
      final address = (msg.address ?? '').toUpperCase();
      final isPromo = _isPromotional(body);
      if (isPromo) {
        developer.log('FILTER | PROMO BLOCKED | From: ${msg.address} | Body: ${msg.body}',
            name: 'SmsTransactionService');
        return false;
      }
      final senderMatch = _bankSenders.any((bank) => address.contains(bank));
      final txMatch = _isTransactionSms(body);
      if (!senderMatch && !txMatch) {
        developer.log('FILTER | NO MATCH | From: ${msg.address} | senderMatch: $senderMatch | txMatch: $txMatch | Body: ${msg.body}',
            name: 'SmsTransactionService');
        return false;
      }
      developer.log('FILTER | PASSED | From: ${msg.address} | senderMatch: $senderMatch | txMatch: $txMatch | Body: ${msg.body}',
          name: 'SmsTransactionService');
      return true;
    }).toList();
  }

  Future<String> saveSmsLog({
    required List<SmsMessage> rawMessages,
    required List<SmsMessage> filteredMessages,
    required List<SmsTransaction> parsedTransactions,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/sms_log_${DateTime.now().millisecondsSinceEpoch}.csv');
    final buf = StringBuffer();

    buf.writeln('=== SMS IMPORT LOG ===');
    buf.writeln('Generated: ${DateTime.now().toLocal()}');
    buf.writeln();

    buf.writeln('--- RAW SMS (${rawMessages.length}) ---');
    buf.writeln('Sender,Date,Body');
    for (final msg in rawMessages) {
      final date = DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0).toLocal();
      final body = (msg.body ?? '').replaceAll('"', '""');
      buf.writeln('"${msg.address}","$date","$body"');
    }

    buf.writeln();
    buf.writeln('--- FILTERED SMS (${filteredMessages.length}) ---');
    buf.writeln('Sender,Date,Body');
    for (final msg in filteredMessages) {
      final date = DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0).toLocal();
      final body = (msg.body ?? '').replaceAll('"', '""');
      buf.writeln('"${msg.address}","$date","$body"');
    }

    buf.writeln();
    buf.writeln('--- PARSED TRANSACTIONS (${parsedTransactions.length}) ---');
    buf.writeln('Amount,Description,Date,Sender,Type');
    for (final tx in parsedTransactions) {
      final date = DateFormat('yyyy-MM-dd HH:mm').format(tx.date);
      buf.writeln('"${tx.amount}","${tx.description}","$date","${tx.sender}","${tx.isCredit ? "CREDIT" : "DEBIT"}",');
    }

    await file.writeAsString(buf.toString());
    developer.log('SMS log saved to ${file.path}', name: 'SmsTransactionService');
    return file.path;
  }

  bool _isPromotional(String body) {
    return body.contains('personal loan') ||
        body.contains('home loan') ||
        body.contains('car loan') ||
        body.contains('loan amount') ||
        (body.contains('up to') && body.contains('loan')) ||
        body.contains('pre-approved') ||
        body.contains('preapproved') ||
        body.contains('apply now') ||
        body.contains('apply today') ||
        body.contains('quick approval') ||
        body.contains('limited period') ||
        body.contains('hurry') ||
        body.contains('exclusive offer') ||
        body.contains('get up to') ||
        body.contains('avail ') ||
        body.contains('check eligibility') ||
        body.contains('upgrade your') ||
        (body.contains('interest') && body.contains('rate')) ||
        (body.contains('reward') && body.contains('point')) ||
        body.contains('demat') ||
        body.contains('mutual fund') ||
        body.contains('fixed deposit') ||
        body.contains('recurring deposit') ||
        body.contains('forex');
  }

  bool _isTransactionSms(String body) {
    return body.contains('rs.') ||
        body.contains('inr') ||
        body.contains('debited') ||
        body.contains('credited') ||
        body.contains('spent') ||
        body.contains('paid') ||
        body.contains('purchase') ||
        body.contains('withdrawal') ||
        body.contains('withdrawn') ||
        body.contains('transfer') ||
        body.contains('transaction') ||
        body.contains('trf') ||
        body.contains('ref no') ||
        body.contains('ref:') ||
        body.contains('utr') ||
        body.contains('emi') ||
        (body.contains('a/c') && (body.contains('debited') || body.contains('credited')));
  }

  List<SmsTransaction> parseTransactions(List<SmsMessage> messages) {
    final result = <SmsTransaction>[];
    for (final msg in messages) {
      final parsed = _parseSingleSms(msg);
      if (parsed != null) {
        developer.log(
          'PARSE | SUCCESS | ${parsed.amount} | ${parsed.description} | ${parsed.isCredit ? "CREDIT" : "DEBIT"}',
          name: 'SmsTransactionService',
        );
        result.add(parsed);
      } else {
        developer.log(
          'PARSE | FAILED | From: ${msg.address} | Body: ${msg.body}',
          name: 'SmsTransactionService',
        );
      }
    }
    developer.log('Parsed ${result.length} / ${messages.length} transactions',
        name: 'SmsTransactionService');
    return result;
  }

  SmsTransaction? _parseSingleSms(SmsMessage msg) {
    final body = msg.body ?? '';
    final address = msg.address ?? '';
    final amount = _extractAmount(body);
    if (amount == null || amount <= 0) return null;

    final isCredit = _isCreditSms(body);
    final description = _extractDescription(body, address);

    return SmsTransaction(
      id: 'sms-${msg.id ?? DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      description: description,
      date: DateTime.fromMillisecondsSinceEpoch(msg.date ?? DateTime.now().millisecondsSinceEpoch),
      sender: address,
      rawBody: body,
      isCredit: isCredit,
    );
  }

  double? _extractAmount(String body) {
    final patterns = [
      RegExp(r'rs\.?\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'inr\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'₹\s*([\d,]+\.?\d*)'),
      RegExp(r'amount\s+[a-z]+\s+([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'([\d,]+\.?\d*)\s*(?:rs|inr)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final parsed = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    developer.log('EXTRACT | No amount found in: $body', name: 'SmsTransactionService');
    return null;
  }

  bool _isCreditSms(String body) {
    final lower = body.toLowerCase();
    if (lower.contains('debited')) return false;
    return lower.contains('credited') ||
        lower.contains('received') ||
        lower.contains('deposited') ||
        lower.contains('refund') ||
        lower.contains('cashback');
  }

  String _extractDescription(String body, String sender) {
    final lower = body.toLowerCase();
    for (final entry in _tagKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return '${entry.key} - $sender';
        }
      }
    }
    return sender;
  }

  static String getTagForDescription(String description) {
    final lower = description.toLowerCase();
    for (final entry in _tagKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) return entry.key;
      }
    }
    return 'Other';
  }

  List<SmsTransaction> findDuplicates(
    List<SmsTransaction> incoming,
    List<BudgetExpense> existing,
  ) {
    final duplicates = <SmsTransaction>[];
    for (final tx in incoming) {
      final isDuplicate = existing.any((e) =>
          (e.amount - tx.amount).abs() < 0.01 &&
          e.timestamp.difference(tx.date).inDays.abs() <= 1);
      if (isDuplicate) duplicates.add(tx);
    }
    return duplicates;
  }

  Future<int> logTransactions(
    String budgetId,
    List<SmsTransaction> transactions,
  ) async {
    int count = 0;
    for (final tx in transactions) {
      if (tx.isCredit) continue;
      final tag = getTagForDescription(tx.description);
      final desc = tx.description;
      await _budgetService.addExpenseToBudget(
        budgetId,
        tag,
        desc,
        tx.amount,
        timestamp: tx.date,
      );
      count++;
    }
    return count;
  }
}
