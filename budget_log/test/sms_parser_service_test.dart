import 'package:budget_log/models/sms_record.dart';
import 'package:budget_log/services/sms_parser_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = SmsParserService();
  final timestamp = DateTime(2026, 1, 15, 10, 30);

  SmsInboxRecord record(String sender, String body) => SmsInboxRecord(
    sourceKey: 'native_key',
    sender: sender,
    body: body,
    timestamp: timestamp,
  );

  test('parses a debit SMS with amount, merchant and account', () {
    final staged = parser.parse(
      record(
        'HDFCBK',
        'Rs.1,234.50 debited from A/c XX1234 at Amazon on 15-01-26. '
            'Ref 123.',
      ),
    );

    expect(staged, isNotNull);
    expect(staged!.extractedAmount, 1234.50);
    expect(staged.extractedType, 'debit');
    expect(staged.extractedMerchant, 'Amazon');
    expect(staged.accountRef, '1234');
    expect(staged.isPending, isTrue);
    expect(staged.id, startsWith('sms_'));
  });

  test('parses a credit SMS and prefers the earliest type keyword', () {
    final staged = parser.parse(
      record(
        'ICICIB',
        'INR 5,000.00 credited to your account from Acme Corp via UPI.',
      ),
    );

    expect(staged, isNotNull);
    expect(staged!.extractedAmount, 5000);
    expect(staged.extractedType, 'credit');
    expect(staged.extractedMerchant, 'Acme Corp');
  });

  test('ignores OTPs, failed messages and future debits', () {
    expect(
      parser.parse(
        record(
          'HDFCBK',
          '123456 is your OTP for a transaction of Rs 500. Do not share.',
        ),
      ),
      isNull,
    );
    expect(
      parser.parse(record('HDFCBK', 'Rs 500 debited failed. Try again.')),
      isNull,
    );
    expect(
      parser.parse(
        record('HDFCBK', 'Rs 500 will be debited from your account soon.'),
      ),
      isNull,
    );
  });

  test('ignores messages without a bank sender or bank context', () {
    expect(
      parser.parse(record('AMZN', 'Rs 500 debited for your order.')),
      isNull,
    );
  });

  test('builds the same source key for equivalent SMS records', () {
    final first = parser.parse(record(' HDFC Bank ', ' Rs 100 debited '))!;
    final second = parser.parse(
      SmsInboxRecord(
        sourceKey: 'other',
        sender: 'hdfc bank',
        body: 'Rs 100 debited',
        timestamp: timestamp,
      ),
    )!;

    expect(first.id, second.id);
  });

  test('source key changes when the timestamp changes', () {
    final first = SmsParserService.sourceKeyFor(record('HDFCBK', 'Rs 100 '));
    final second = SmsParserService.sourceKeyFor(
      SmsInboxRecord(
        sourceKey: 'native_key',
        sender: 'HDFCBK',
        body: 'Rs 100 ',
        timestamp: timestamp.add(const Duration(seconds: 1)),
      ),
    );

    expect(first, isNot(second));
  });
}
